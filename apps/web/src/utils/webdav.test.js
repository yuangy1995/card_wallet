import { afterEach, describe, expect, it, vi } from 'vitest'
const mocks = vi.hoisted(() => ({ encrypt: vi.fn() }))
vi.mock('./syncCryptoV4', () => ({ encryptSyncEnvelopeV4: mocks.encrypt }))
import { WebDAVClient } from './webdav'
afterEach(() => vi.useRealTimers())
describe('WebDAV cancellation and request boundaries', () => {
  it('passes a real abort signal to the library and aborts pending requests', async () => {
    const client = new WebDAVClient(); client.client = {}
    let signal
    const request = client.request((_, received) => new Promise((resolve, reject) => {
      signal = received; signal.addEventListener('abort', () => reject(new DOMException('cancelled', 'AbortError')))
    }))
    const rejected = expect(request).rejects.toMatchObject({ name: 'AbortError' })
    client.disconnect()
    await rejected
    expect(signal.aborted).toBe(true)
    expect(client.controllers.size).toBe(0)
    expect(client.config).toBeNull()
  })
  it('times out library operations after a bounded wait', async () => {
    vi.useFakeTimers()
    const client = new WebDAVClient(); client.client = {}
    const rejected = expect(client.request((_, signal) => new Promise((resolve, reject) => signal.addEventListener('abort', () => reject(new Error('timed out')))))).rejects.toThrow('timed out')
    await vi.advanceTimersByTimeAsync(60000)
    await rejected
    expect(client.controllers.size).toBe(0)
  })
  it('does not initiate an upload when cancelled during snapshot encryption', async () => {
    const client = new WebDAVClient(); client.client = { putFileContents: vi.fn() }
    const put = client.client.putFileContents
    let finish
    mocks.encrypt.mockReturnValue(new Promise(resolve => { finish = resolve }))
    const rejected = expect(client.uploadSyncSnapshot({ records: [] }, 'password')).rejects.toMatchObject({ name: 'AbortError' })
    client.disconnect(); finish('encrypted')
    await rejected
    expect(put).not.toHaveBeenCalled()
  })
  it.each(['../secret', '/absolute', 'a/b', 'a\\b', '..'])('rejects path traversal %s', name => expect(() => new WebDAVClient().filePath(name)).toThrow('文件名'))
  it('encodes non-ASCII Basic-auth credentials as UTF-8', () => {
    const client = new WebDAVClient(); client.config = { username: '用户', password: '密码' }
    expect(client.buildAuthHeader()).toBe('Basic ' + Buffer.from('用户:密码').toString('base64'))
  })
})
