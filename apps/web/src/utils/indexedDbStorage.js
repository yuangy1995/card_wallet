import { STORAGE_KEYS } from '@/config/constants'

const DB_NAME = 'card-wallet-web-local-db'
const DB_VERSION = 1
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
        resolve(request.result)
      }
      request.onerror = () => reject(request.error || new Error('打开 IndexedDB 失败'))
      request.onblocked = () => {
        blocked = true
        reject(new Error('IndexedDB 被其他页面占用，请关闭重复打开的页面后重试'))
      }
    })
  }

  async loadCacheFromDatabase() {
    if (!this.db) return
    const transaction = this.db.transaction(STORE_NAME, 'readonly')
    const done = transactionDone(transaction)
    const store = transaction.objectStore(STORE_NAME)
    const [entries] = await Promise.all([requestToPromise(store.getAll()), done])
    // IndexedDB 已经返回独立副本，不再序列化整份图片数据。
    entries.forEach((entry) => this.cache.set(entry.key, entry.value))
  }

  async migrateLegacyLocalStorage() {
    if (typeof localStorage === 'undefined') return
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
    return this.cache.has(key) ? cloneValue(this.cache.get(key)) : defaultValue
  }

  async set(key, value) {
    this.ensureInitialized()
    if (!this.available || !this.db) {
      throw new Error('IndexedDB 本地数据库不可用')
    }
    const nextValue = cloneValue(value)
    const transaction = this.db.transaction(STORE_NAME, 'readwrite')
    const done = transactionDone(transaction)
    try {
      transaction.objectStore(STORE_NAME).put({ key, value: nextValue, updatedAt: Date.now() })
    } catch (error) {
      transaction.abort()
      await done.catch(() => {})
      throw error
    }
    await done
    // 仅发布已提交值；失败事务不能回滚/覆盖后续成功事务的缓存。
    this.cache.set(key, nextValue)
    await this.estimate()
    return true
  }

  async remove(key) {
    this.ensureInitialized()
    if (!this.available || !this.db) {
      throw new Error('IndexedDB 本地数据库不可用')
    }
    const transaction = this.db.transaction(STORE_NAME, 'readwrite')
    const done = transactionDone(transaction)
    try {
      transaction.objectStore(STORE_NAME).delete(key)
    } catch (error) {
      transaction.abort()
      await done.catch(() => {})
      throw error
    }
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
      keys: [...this.cache.keys()]
    }
  }

  async resetForTests() {
    this.db?.close?.()
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
