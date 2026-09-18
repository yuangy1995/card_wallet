import { afterEach, beforeEach, describe, it } from 'vitest'
import assert from 'node:assert/strict'
import { localDataStore } from './indexedDbStorage'
import { STORAGE_KEYS } from '@/config/constants'

// 不提前修改持久数据的事务替身，用于注入提交失败并验证回滚边界。
const createDatabase = () => {
  const values = new Map()
  const controls = { failNextWrite: false, throwNextPut: false, beforeCommit: null }
  const db = {
    close() {},
    objectStoreNames: { contains: () => true },
    transaction(name, mode) {
      const operations = []
      let aborted = false
      const fail = mode === 'readwrite' && controls.failNextWrite
      if (mode === 'readwrite') controls.failNextWrite = false
      const transaction = {
        error: null,
        abort() {
          if (aborted) return
          aborted = true
          queueMicrotask(() => transaction.onabort?.())
        },
        objectStore: () => ({
          getAll() {
            const request = {}
            queueMicrotask(() => {
              request.result = [...values].map(([key, value]) => ({ key, value: structuredClone(value) }))
              request.onsuccess?.()
            })
            return request
          },
          put(entry) {
            if (controls.throwNextPut) {
              controls.throwNextPut = false
              throw new Error('clone failed')
            }
            operations.push(() => values.set(entry.key, structuredClone(entry.value)))
          },
          delete(key) { operations.push(() => values.delete(key)) }
        })
      }
      // 请求回调（含回调中新加的请求）结束后才提交。
      queueMicrotask(() => queueMicrotask(() => {
        if (aborted) return
        if (fail) {
          transaction.error = new Error('quota exceeded')
          transaction.abort()
          return
        }
        controls.beforeCommit?.(mode)
        operations.forEach((operation) => operation())
        transaction.oncomplete?.()
      }))
      return transaction
    }
  }
  const indexedDB = {
    open() {
      const request = { result: db }
      queueMicrotask(() => request.onsuccess?.())
      return request
    }
  }
  return { db, values, controls, indexedDB }
}

describe('IndexedDB persistence regressions', () => {
  let database, legacy, estimates, now, descriptors, realNow
  beforeEach(async () => {
    descriptors = Object.fromEntries(['indexedDB', 'localStorage', 'navigator'].map(key => [key, Object.getOwnPropertyDescriptor(globalThis, key)]))
    realNow = Date.now
    now = 100_000
    Date.now = () => now
    database = createDatabase()
    legacy = new Map()
    estimates = 0
    Object.defineProperties(globalThis, {
      indexedDB: { configurable: true, value: database.indexedDB },
      localStorage: { configurable: true, value: {
        getItem: key => legacy.get(key) ?? null,
        removeItem: key => legacy.delete(key)
      } },
      navigator: { configurable: true, value: { storage: {
        persist: async () => false,
        estimate: async () => { estimates++; return { usage: estimates, quota: 1000 } }
      } } }
    })
    await localDataStore.resetForTests()
  })
  afterEach(async () => {
    await localDataStore.resetForTests()
    Date.now = realNow
    for (const [key, descriptor] of Object.entries(descriptors)) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor)
      else delete globalThis[key]
    }
  })

  it('migrates legacy cards, tombstones and metadata before removing source keys', async () => {
    const records = [{ cardId: 'deleted', state: 'deleted' }]
    legacy.set(STORAGE_KEYS.CARD_DATA, JSON.stringify([{ id: 'old' }]))
    legacy.set(STORAGE_KEYS.SYNC_RECORDS, JSON.stringify(records))
    legacy.set(STORAGE_KEYS.SYNC_PENDING, 'true')
    legacy.set(STORAGE_KEYS.SYNC_REVISION, '7')
    legacy.set(STORAGE_KEYS.SYNC_LAST_SNAPSHOT, JSON.stringify([{ id: 'snapshot' }]))
    legacy.set(STORAGE_KEYS.SYNC_HISTORY, '[{"id":"history"}]')
    let checked = false
    database.controls.beforeCommit = mode => {
      if (mode === 'readwrite') { checked = true; assert.equal(legacy.size, 6) }
    }
    await localDataStore.initialize()
    assert.equal(checked, true)
    assert.equal(legacy.size, 0)
    assert.deepEqual(localDataStore.get(STORAGE_KEYS.SYNC_RECORDS), records)
    assert.equal(database.values.size, 6)
    assert.equal(localDataStore.get(STORAGE_KEYS.SYNC_REVISION), 7)
  })

  it('preserves every legacy key when a migration transaction aborts and allows retry', async () => {
    legacy.set(STORAGE_KEYS.CARD_DATA, '[{"id":"old"}]')
    legacy.set(STORAGE_KEYS.SYNC_PENDING, 'true')
    database.controls.failNextWrite = true
    await assert.rejects(localDataStore.initialize(), /quota exceeded/)
    assert.equal(legacy.size, 2)
    assert.equal(database.values.size, 0)
    assert.equal(localDataStore.initialized, false)
    assert.match(localDataStore.info().lastOpenError, /quota exceeded/)
    await localDataStore.initialize()
    assert.equal(legacy.size, 0)
    assert.deepEqual(localDataStore.get(STORAGE_KEYS.CARD_DATA), [{ id: 'old' }])
  })

  it('does not delete malformed legacy JSON or partially migrate it', async () => {
    legacy.set(STORAGE_KEYS.CARD_DATA, '[{"id":"old"}]')
    legacy.set(STORAGE_KEYS.SYNC_HISTORY, '{invalid')
    await assert.rejects(localDataStore.initialize(), /原数据已保留/)
    assert.equal(legacy.size, 2)
    assert.equal(database.values.size, 0)
  })

  it('keeps an existing empty ledger authoritative instead of resurrecting legacy cards', async () => {
    database.values.set(STORAGE_KEYS.SYNC_RECORDS, [])
    legacy.set(STORAGE_KEYS.CARD_DATA, '[{"id":"obsolete"}]')
    await localDataStore.initialize()
    assert.deepEqual(localDataStore.get(STORAGE_KEYS.SYNC_RECORDS), [])
    assert.equal(localDataStore.get(STORAGE_KEYS.CARD_DATA), null)
    assert.equal(legacy.size, 1)
  })

  it('honors opting out of legacy migration', async () => {
    legacy.set(STORAGE_KEYS.CARD_DATA, '[]')
    await localDataStore.initialize({ clearLegacyLocalStorage: false })
    assert.equal(legacy.size, 1)
    assert.equal(database.values.size, 0)
  })

  it('retains a legacy value changed by another page during migration', async () => {
    legacy.set(STORAGE_KEYS.CARD_DATA, '[{"id":"first"}]')
    database.controls.beforeCommit = mode => {
      if (mode === 'readwrite') legacy.set(STORAGE_KEYS.CARD_DATA, '[{"id":"newer"}]')
    }
    await localDataStore.initialize()
    assert.equal(legacy.get(STORAGE_KEYS.CARD_DATA), '[{"id":"newer"}]')
    assert.deepEqual(localDataStore.get(STORAGE_KEYS.CARD_DATA), [{ id: 'first' }])
  })

  it('does not expose a value before its transaction commits', async () => {
    await localDataStore.initialize()
    await localDataStore.set('key', { value: 'old' })
    const write = localDataStore.set('key', { value: 'new' })
    assert.deepEqual(localDataStore.get('key'), { value: 'old' })
    await write
    assert.deepEqual(localDataStore.get('key'), { value: 'new' })
  })

  it('preserves cache and database on failed writes and deletions', async () => {
    await localDataStore.initialize()
    await localDataStore.set('key', { value: 'old' })
    database.controls.failNextWrite = true
    await assert.rejects(localDataStore.set('key', { value: 'new' }), /quota/)
    database.controls.failNextWrite = true
    await assert.rejects(localDataStore.remove('key'), /quota/)
    assert.deepEqual(localDataStore.get('key'), { value: 'old' })
    assert.deepEqual(database.values.get('key'), { value: 'old' })
  })

  it('does not mutate the cache when the database is unavailable', async () => {
    await localDataStore.initialize()
    await localDataStore.set('key', 'old')
    localDataStore.available = false
    await assert.rejects(localDataStore.set('key', 'new'), /不可用/)
    await assert.rejects(localDataStore.remove('key'), /不可用/)
    assert.equal(localDataStore.get('key'), 'old')
  })

  it('does not roll back a later successful write when an earlier write fails', async () => {
    await localDataStore.initialize()
    await localDataStore.set('key', 'old')
    database.controls.failNextWrite = true
    const first = assert.rejects(localDataStore.set('key', 'failed'), /quota/)
    const second = localDataStore.set('key', 'committed')
    await Promise.all([first, second])
    assert.equal(localDataStore.get('key'), 'committed')
    assert.equal(database.values.get('key'), 'committed')
  })

  it('handles synchronous request errors without publishing the new value', async () => {
    await localDataStore.initialize()
    await localDataStore.set('key', 'old')
    database.controls.throwNextPut = true
    await assert.rejects(localDataStore.set('key', 'new'), /clone failed/)
    assert.equal(localDataStore.get('key'), 'old')
  })

  it('keeps caller mutations isolated from persisted cache values', async () => {
    await localDataStore.initialize()
    const input = { nested: { value: 1 } }
    await localDataStore.set('key', input)
    input.nested.value = 2
    const output = localDataStore.get('key')
    output.nested.value = 3
    assert.equal(localDataStore.get('key').nested.value, 1)
  })

  it('reuses one quota estimate for a write burst and refreshes after 30 seconds', async () => {
    await localDataStore.initialize()
    await Promise.all(Array.from({ length: 100 }, (_, i) => localDataStore.set(`key-${i}`, i)))
    assert.equal(estimates, 1)
    now += 30_000
    await Promise.all([localDataStore.estimate(), localDataStore.estimate()])
    assert.equal(estimates, 2)
  })

  it('closes an open request that succeeds after being blocked, then permits retry', async () => {
    let closed = 0
    const oldClose = database.db.close
    database.db.close = () => { closed++ }
    const normalOpen = database.indexedDB.open
    database.indexedDB.open = () => {
      const request = { result: database.db }
      queueMicrotask(() => { request.onblocked?.(); request.onsuccess?.() })
      return request
    }
    await assert.rejects(localDataStore.initialize(), /其他页面/)
    assert.equal(closed, 1)
    database.indexedDB.open = normalOpen
    database.db.close = oldClose
    await localDataStore.initialize()
    assert.equal(localDataStore.available, true)
  })
})
