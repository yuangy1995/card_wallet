export const createDatabase = () => {
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
          get(key) {
            const request = {}
            queueMicrotask(() => { request.result = values.has(key) ? { key, value: structuredClone(values.get(key)) } : undefined; request.onsuccess?.() })
            return request
          },
          clear() { operations.push(() => values.clear()) },
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
