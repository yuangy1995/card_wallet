import { STORAGE_KEYS } from '@/config/constants'
import { VAULT_META_KEY, createVault, unwrapMaster, wrapMaster, verifyMaster, sealValue, openValue } from './localVaultCrypto'

const DB_NAME = 'card-wallet-web-local-db'
const DB_VERSION = 2
const STORE_NAME = 'kv'
const ESTIMATE_INTERVAL_MS = 30 * 1000

const LEGACY_LOCAL_STORAGE_KEYS = [
  STORAGE_KEYS.CARD_DATA,
  STORAGE_KEYS.SYNC_RECORDS,
  STORAGE_KEYS.SYNC_PENDING,
  STORAGE_KEYS.SYNC_REVISION,
  STORAGE_KEYS.SYNC_LAST_SNAPSHOT,
  STORAGE_KEYS.SYNC_HISTORY
]

const cloneValue = (value) => {
  if (value === undefined || value === null) return value
  if (typeof value !== 'object') return value
  return JSON.parse(JSON.stringify(value))
}

const requestToPromise = (request) => new Promise((resolve, reject) => {
  request.onsuccess = () => resolve(request.result)
  request.onerror = () => reject(request.error || new Error('IndexedDB 操作失败'))
})

const transactionDone = (transaction) => new Promise((resolve, reject) => {
  transaction.oncomplete = () => resolve()
  transaction.onabort = () => reject(transaction.error || new Error('IndexedDB 事务已中止'))
  transaction.onerror = () => reject(transaction.error || new Error('IndexedDB 事务失败'))
})

class IndexedDbStorage {
  constructor() {
    this.cache = new Map()
    this.vaultMetadata = null
    this.vaultKey = null
    this.session = 0
    this.writeQueue = Promise.resolve()
    this.db = null
    this.initialized = false
    this.available = false
    this.persisted = false
    this.lastEstimate = null
    this.lastEstimateAt = null
    this.estimatePromise = null
    this.lastOpenError = null
    this.initPromise = null
  }

  async initialize(options = {}) {
    if (this.initPromise) return this.initPromise
    this.initPromise = this.open(options).catch((error) => {
      this.db?.close?.()
      this.db = null
      this.cache.clear()
      this.initialized = false
      this.available = false
      this.lastOpenError = error.message
      // 打开或迁移失败后允许重试，不缓存已拒绝的 Promise。
      this.initPromise = null
      throw error
    })
    return this.initPromise
  }

  async open({ clearLegacyLocalStorage = true } = {}) {
    this.cache.clear()
    this.persisted = await this.requestPersistentStorage()
    this.lastEstimate = await this.estimate()

    if (typeof indexedDB === 'undefined') {
      throw new Error('当前浏览器不支持 IndexedDB 本地数据库，请升级浏览器或改用最新版 Chrome、Edge、Safari。')
    }

    this.db = await this.openDatabase()
    await this.loadCacheFromDatabase()
    if (clearLegacyLocalStorage) await this.migrateLegacyLocalStorage()
    this.initialized = true
    this.available = true
    this.lastOpenError = null
    return this.info()
  }

  async requestPersistentStorage() {
    try {
      if (typeof navigator === 'undefined' || !navigator.storage?.persist) return false
      return Boolean(await navigator.storage.persist())
    } catch {
      return false
    }
  }

  async estimate() {
    if (this.estimatePromise) return this.estimatePromise
    if (this.lastEstimateAt !== null && Date.now() - this.lastEstimateAt < ESTIMATE_INTERVAL_MS) {
      return this.lastEstimate
    }
    this.estimatePromise = (async () => {
      try {
        if (typeof navigator === 'undefined' || !navigator.storage?.estimate) return null
        return await navigator.storage.estimate()
      } catch {
        return null
      }
    })()
    try {
      this.lastEstimate = await this.estimatePromise
      this.lastEstimateAt = Date.now()
      return this.lastEstimate
    } finally {
      this.estimatePromise = null
    }
  }

  openDatabase() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION)
      let blocked = false
      request.onupgradeneeded = () => {
        const db = request.result
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME, { keyPath: 'key' })
        }
      }
      request.onsuccess = () => {
        // blocked 后请求仍可能成功，关闭已无人接收的连接。
        if (blocked) {
          request.result.close()
          return
        }
        request.result.onversionchange = () => {
          const connection = request.result
          connection.close()
          if (this.db !== connection) return
          this.db = null
          this.initialized = false
          this.available = false
          this.initPromise = null
          this.lock()
        }
        resolve(request.result)
      }
      request.onerror = () => reject(request.error || new Error('打开 IndexedDB 失败'))
      request.onblocked = () => {
        blocked = true
        reject(new Error('IndexedDB 被其他页面占用，请关闭重复打开的页面后重试'))
      }
    })
  }

  async readEntries() {
    const transaction = this.db.transaction(STORE_NAME, 'readonly')
    const done = transactionDone(transaction)
    const [entries] = await Promise.all([requestToPromise(transaction.objectStore(STORE_NAME).getAll()), done])
    return entries
  }

  async loadCacheFromDatabase() {
    if (!this.db) return
    this.cache.clear()
    // 锁屏只读取包装密钥等小型元数据，不重复载入整份密文及图片。
    const transaction = this.db.transaction(STORE_NAME, 'readonly')
    const done = transactionDone(transaction)
    const [metadata] = await Promise.all([
      requestToPromise(transaction.objectStore(STORE_NAME).get(VAULT_META_KEY)), done
    ])
    this.vaultMetadata = metadata?.value || null
    if (this.vaultMetadata) return
    // 旧库仍完整检查：元数据被删除时不能把残留密文误当作旧明文。
    const entries = await this.readEntries()
    this.vaultMetadata = entries.find(entry => entry.key === VAULT_META_KEY)?.value || null
    if (!this.vaultMetadata && entries.some(entry => entry.value?.format === 'card-wallet-sealed-v1')) throw new Error('本地加密信息缺失，请从备份恢复；未修改原数据。')
    if (!this.vaultMetadata) entries.forEach(entry => this.cache.set(entry.key, entry.value))
  }

  get isUnlocked() { return Boolean(this.vaultKey) }

  lock() {
    this.session++
    this.vaultKey = null
    this.cache.clear()
    if (typeof window !== 'undefined') window.dispatchEvent(new Event('wallet-vault-locked'))
  }

  enqueueWrite(operation) {
    const session = this.session
    const next = this.writeQueue.then(() => {
      if (session !== this.session) throw new Error('应用已锁定，请解锁后重试。')
      return operation(session)
    })
    this.writeQueue = next.catch(() => {})
    return next
  }

  async unlockVault(password) {
    const session = this.session
    const entries = await this.readEntries()
    const metadata = entries.find(entry => entry.key === VAULT_META_KEY)?.value
    if (!metadata) throw new Error('本地保险库已改变，请刷新页面。')
    const bytes = await unwrapMaster(password, metadata)
    try {
      const key = await verifyMaster(bytes, metadata)
      await this.openVaultEntries(entries, metadata, key, session)
    } finally { bytes.fill(0) }
  }

  async openVaultEntries(entries, metadata, key, session) {
    const cache = new Map()
    for (const entry of entries) {
      if (entry.key !== VAULT_META_KEY) cache.set(entry.key, await openValue(entry.value, key, metadata.id, entry.key))
    }
    if (session !== this.session) throw new Error('解锁已取消，请重试。')
    this.vaultMetadata = metadata
    this.vaultKey = key
    this.cache = cache
  }

  async enableVault(password, extraEntries = []) {
    return this.enqueueWrite(async session => {
      const before = await this.readEntries()
      if (before.some(entry => entry.key === VAULT_META_KEY)) throw new Error('另一页面已创建保险库，请刷新后解锁。')
      const { metadata, key } = await createVault(password)
      const values = new Map(before.map(entry => [entry.key, entry.value]))
      extraEntries.forEach(([entryKey, value]) => { if (!values.has(entryKey)) values.set(entryKey, value) })
      const encrypted = []
      for (const [entryKey, value] of values) encrypted.push({ key: entryKey, value: await sealValue(value, key, metadata.id, entryKey), updatedAt: Date.now() })
      if (session !== this.session) throw new Error('加密已取消，原数据已保留。')
      const transaction = this.db.transaction(STORE_NAME, 'readwrite')
      const done = transactionDone(transaction)
      const store = transaction.objectStore(STORE_NAME)
      const request = store.getAll()
      request.onsuccess = () => {
        // 加密期间其他页面的写入不能被旧快照覆盖。
        if (JSON.stringify(request.result) !== JSON.stringify(before) || session !== this.session) { transaction.abort(); return }
        try {
          encrypted.forEach(entry => store.put(entry))
          store.put({ key: VAULT_META_KEY, value: metadata })
        } catch { transaction.abort() }
      }
      await done
      this.vaultMetadata = metadata
      if (session !== this.session) throw new Error('应用已锁定，请使用刚设置的密码解锁。')
      this.vaultKey = key
      this.cache = values
      return true
    })
  }

  async changeVaultPassword(oldPassword, newPassword) {
    return this.enqueueWrite(async session => {
      if (!this.vaultKey) throw new Error('请先解锁。')
      const metadata = this.vaultMetadata
      const bytes = await unwrapMaster(oldPassword, metadata)
      try {
        const wrapped = await wrapMaster(newPassword, bytes, metadata.id)
        await this.writeEncryptedEntries([], { ...metadata, ...wrapped }, session)
        return true
      } finally { bytes.fill(0) }
    })
  }

  async writeEncryptedEntries(entries, metadata = this.vaultMetadata, session = this.session) {
    if (!this.vaultKey || session !== this.session) throw new Error('应用已锁定，请解锁后重试。')
    const expected = this.vaultMetadata
    const updated = { ...metadata, revision: (expected.revision || 0) + 1 }
    const transaction = this.db.transaction(STORE_NAME, 'readwrite')
    const done = transactionDone(transaction)
    const store = transaction.objectStore(STORE_NAME)
    const request = store.get(VAULT_META_KEY)
    let conflict = false
    request.onsuccess = () => {
      const current = request.result?.value
      if (!current || current.id !== expected.id || current.revision !== expected.revision) {
        conflict = true
        transaction.abort()
        return
      }
      if (session !== this.session) { transaction.abort(); return }
      try {
        entries.forEach(entry => entry.remove ? store.delete(entry.key) : store.put(entry))
        store.put({ key: VAULT_META_KEY, value: updated })
      } catch { transaction.abort() }
    }
    try { await done }
    catch (error) {
      if (conflict) { this.lock(); throw new Error('数据已在其他页面修改，请重新解锁以加载最新内容。') }
      throw error
    }
    this.vaultMetadata = updated
    return session === this.session
  }

  async clearVault() {
    return this.enqueueWrite(async () => {
      const transaction = this.db.transaction(STORE_NAME, 'readwrite')
      const done = transactionDone(transaction)
      transaction.objectStore(STORE_NAME).clear()
      await done
      this.vaultMetadata = null
      this.lock()
    })
  }

  async migrateLegacyLocalStorage() {
    if (typeof localStorage === 'undefined' || this.vaultMetadata) return
    // 已有数据库（包括空账本）优先，不能混入过时记录复活已删除的卡片。
    if (LEGACY_LOCAL_STORAGE_KEYS.some((key) => this.cache.has(key))) return

    const entries = LEGACY_LOCAL_STORAGE_KEYS.map((key) => ({ key, raw: localStorage.getItem(key) }))
      .filter((entry) => entry.raw !== null)
      .map((entry) => {
        try {
          return { ...entry, value: JSON.parse(entry.raw) }
        } catch {
          throw new Error('旧版本地数据无法读取，原数据已保留，请先备份后重试。')
        }
      })
    if (entries.length === 0) return

    const transaction = this.db.transaction(STORE_NAME, 'readwrite')
    const done = transactionDone(transaction)
    const store = transaction.objectStore(STORE_NAME)
    // 在同一事务内重新检查，避免另一标签页抢先写入后被旧数据覆盖。
    let migrated = false
    const request = store.getAll()
    request.onsuccess = () => {
      if (request.result.some((entry) => LEGACY_LOCAL_STORAGE_KEYS.includes(entry.key))) return
      try {
        entries.forEach(({ key, value }) => store.put({ key, value, updatedAt: Date.now() }))
        migrated = true
      } catch {
        transaction.abort()
      }
    }
    await done
    if (!migrated) {
      await this.loadCacheFromDatabase()
      return
    }
    entries.forEach(({ key, value }) => this.cache.set(key, value))
    this.clearLegacyLocalStorage(entries)
  }

  ensureInitialized() {
    if (!this.initialized) {
      throw new Error('本地数据库尚未初始化')
    }
  }

  get(key, defaultValue = null) {
    this.ensureInitialized()
    if (this.vaultMetadata && !this.vaultKey) throw new Error('应用已锁定，请先解锁。')
    return this.cache.has(key) ? cloneValue(this.cache.get(key)) : defaultValue
  }

  async setMany(values, removeKeys = []) {
    this.ensureInitialized()
    if (!this.available || !this.db) throw new Error('IndexedDB 本地数据库不可用')
    const copied = values.map(([key, value]) => [key, cloneValue(value)])
    return this.enqueueWrite(async session => {
      const entries = []
      if (this.vaultMetadata) {
        if (!this.vaultKey) throw new Error('应用已锁定，请先解锁。')
        for (const [key, value] of copied) entries.push({ key, value: await sealValue(value, this.vaultKey, this.vaultMetadata.id, key), updatedAt: Date.now() })
        entries.push(...removeKeys.map(key => ({ key, remove: true })))
        if (!await this.writeEncryptedEntries(entries, this.vaultMetadata, session)) throw new Error('应用已锁定，请重新解锁。')
      } else {
        const transaction = this.db.transaction(STORE_NAME, 'readwrite')
        const done = transactionDone(transaction)
        try {
          const store = transaction.objectStore(STORE_NAME)
          copied.forEach(([key, value]) => store.put({ key, value, updatedAt: Date.now() }))
          removeKeys.forEach(key => store.delete(key))
        } catch (error) { transaction.abort(); await done.catch(() => {}); throw error }
        await done
        if (session !== this.session) throw new Error('应用已锁定，请重新解锁。')
      }
      copied.forEach(([key, value]) => this.cache.set(key, value))
      removeKeys.forEach(key => this.cache.delete(key))
      await this.estimate()
      return true
    })
  }

  async set(key, value) {
    this.ensureInitialized()
    if (!this.available || !this.db) throw new Error('IndexedDB 本地数据库不可用')
    if (this.vaultMetadata) {
      const nextValue = cloneValue(value)
      return this.enqueueWrite(async session => {
        if (!this.vaultKey) throw new Error('应用已锁定，请先解锁。')
        const encrypted = await sealValue(nextValue, this.vaultKey, this.vaultMetadata.id, key)
        const active = await this.writeEncryptedEntries([{ key, value: encrypted, updatedAt: Date.now() }], this.vaultMetadata, session)
        if (!active) throw new Error('应用已锁定，请重新解锁。')
        this.cache.set(key, nextValue)
        await this.estimate()
        return true
      })
    }
    const nextValue = cloneValue(value)
    const transaction = this.db.transaction(STORE_NAME, 'readwrite')
    const done = transactionDone(transaction)
    try { transaction.objectStore(STORE_NAME).put({ key, value: nextValue, updatedAt: Date.now() }) }
    catch (error) { transaction.abort(); await done.catch(() => {}); throw error }
    await done
    this.cache.set(key, nextValue)
    await this.estimate()
    return true
  }

  async remove(key) {
    this.ensureInitialized()
    if (!this.available || !this.db) throw new Error('IndexedDB 本地数据库不可用')
    if (this.vaultMetadata) return this.enqueueWrite(async session => {
      const active = await this.writeEncryptedEntries([{ key, remove: true }], this.vaultMetadata, session)
      if (active) this.cache.delete(key)
      return true
    })
    const transaction = this.db.transaction(STORE_NAME, 'readwrite')
    const done = transactionDone(transaction)
    try { transaction.objectStore(STORE_NAME).delete(key) }
    catch (error) { transaction.abort(); await done.catch(() => {}); throw error }
    await done
    this.cache.delete(key)
    await this.estimate()
    return true
  }

  clearLegacyLocalStorage(entries) {
    if (typeof localStorage === 'undefined') return
    entries.forEach(({ key, raw }) => {
      try {
        // 只删除刚刚成功迁移的版本，保留迁移期间其他页面的新写入。
        if (localStorage.getItem(key) === raw) localStorage.removeItem(key)
      } catch {
        // 清理失败仍保留数据库中的完整副本。
      }
    })
  }

  info() {
    return {
      available: this.available,
      persisted: this.persisted,
      estimate: this.lastEstimate,
      lastOpenError: this.lastOpenError,
      encrypted: Boolean(this.vaultMetadata),
      locked: Boolean(this.vaultMetadata && !this.vaultKey),
      keys: [...this.cache.keys()]
    }
  }

  async resetForTests() {
    this.db?.close?.()
    this.vaultMetadata = null
    this.vaultKey = null
    this.session++
    this.writeQueue = Promise.resolve()
    this.cache.clear()
    this.db = null
    this.initialized = false
    this.available = false
    this.persisted = false
    this.lastEstimate = null
    this.lastEstimateAt = null
    this.estimatePromise = null
    this.lastOpenError = null
    this.initPromise = null
  }
}

export const localDataStore = new IndexedDbStorage()
