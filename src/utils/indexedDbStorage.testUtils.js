import { vi } from 'vitest'

const requestSuccess = (result) => {
  const request = { result, error: null, onsuccess: null, onerror: null }
  queueMicrotask(() => request.onsuccess?.())
  return request
}

export const createIndexedDbMock = () => {
  const stores = new Map()
  const db = {
    objectStoreNames: {
      contains: (name) => stores.has(name)
    },
    createObjectStore: (name) => {
      if (!stores.has(name)) stores.set(name, new Map())
    },
    transaction: (storeName) => {
      const store = stores.get(storeName)
      const transaction = {
        error: null,
        oncomplete: null,
        onabort: null,
        onerror: null,
        objectStore: () => ({
          getAll: () => {
            const request = requestSuccess([...store.entries()].map(([key, value]) => ({ key, value })))
            queueMicrotask(() => transaction.oncomplete?.())
            return request
          },
          put: (entry) => {
            store.set(entry.key, entry.value)
            queueMicrotask(() => transaction.oncomplete?.())
          },
          delete: (key) => {
            store.delete(key)
            queueMicrotask(() => transaction.oncomplete?.())
          }
        })
      }
      return transaction
    },
    close: vi.fn()
  }

  return {
    open: vi.fn(() => {
      const request = { result: db, error: null, onupgradeneeded: null, onsuccess: null, onerror: null, onblocked: null }
      queueMicrotask(() => {
        request.onupgradeneeded?.()
        request.onsuccess?.()
      })
      return request
    })
  }
}
