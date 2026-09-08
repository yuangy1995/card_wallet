import { STORAGE_KEYS } from '@/config/constants'

const DB_NAME = 'card-wallet-web-local-db'
const DB_VERSION = 1
const STORE_NAME = 'kv'

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
    this.lastOpenError = null
    this.initPromise = null
  }

  async initialize(options = {}) {
    if (this.initPromise) return this.initPromise
    this.initPromise = this.open(options)
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
    this.initialized = true
    this.available = true
    this.lastOpenError = null

    if (clearLegacyLocalStorage) this.clearLegacyLocalStorage()
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
    try {
      if (typeof navigator === 'undefined' || !navigator.storage?.estimate) return null
      return await navigator.storage.estimate()
    } catch {
      return null
    }
  }

  openDatabase() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION)
      request.onupgradeneeded = () => {
        const db = request.result
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME, { keyPath: 'key' })
        }
      }
      request.onsuccess = () => resolve(request.result)
      request.onerror = () => reject(request.error || new Error('打开 IndexedDB 失败'))
      request.onblocked = () => reject(new Error('IndexedDB 被其他页面占用，请关闭重复打开的页面后重试'))
    })
  }

  async loadCacheFromDatabase() {
    if (!this.db) return
    const transaction = this.db.transaction(STORE_NAME, 'readonly')
    const done = transactionDone(transaction)
    const store = transaction.objectStore(STORE_NAME)
    const entries = await requestToPromise(store.getAll())
    entries.forEach((entry) => {
      this.cache.set(entry.key, cloneValue(entry.value))
    })
    await done
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
    const nextValue = cloneValue(value)
    const hadPrevious = this.cache.has(key)
    const previousValue = hadPrevious ? cloneValue(this.cache.get(key)) : undefined

    this.cache.set(key, nextValue)
    if (!this.available || !this.db) {
      throw new Error('IndexedDB 本地数据库不可用')
    }

    try {
      const transaction = this.db.transaction(STORE_NAME, 'readwrite')
      const done = transactionDone(transaction)
      const store = transaction.objectStore(STORE_NAME)
      store.put({ key, value: nextValue, updatedAt: Date.now() })
      await done
      this.lastEstimate = await this.estimate()
      return true
    } catch (error) {
      if (hadPrevious) {
        this.cache.set(key, previousValue)
      } else {
        this.cache.delete(key)
      }
      throw error
    }
  }

  async remove(key) {
    this.ensureInitialized()
    const hadPrevious = this.cache.has(key)
    const previousValue = hadPrevious ? cloneValue(this.cache.get(key)) : undefined

    this.cache.delete(key)
    if (!this.available || !this.db) {
      throw new Error('IndexedDB 本地数据库不可用')
    }

    try {
      const transaction = this.db.transaction(STORE_NAME, 'readwrite')
      const done = transactionDone(transaction)
      transaction.objectStore(STORE_NAME).delete(key)
      await done
      this.lastEstimate = await this.estimate()
      return true
    } catch (error) {
      if (hadPrevious) {
        this.cache.set(key, previousValue)
      }
      throw error
    }
  }

  clearLegacyLocalStorage() {
    if (typeof localStorage === 'undefined') return
    LEGACY_LOCAL_STORAGE_KEYS.forEach((key) => {
      try {
        localStorage.removeItem(key)
      } catch {
        // 清理旧 localStorage 大字段失败不影响 IndexedDB 主流程。
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
    this.lastOpenError = null
    this.initPromise = null
  }
}

export const localDataStore = new IndexedDbStorage()
