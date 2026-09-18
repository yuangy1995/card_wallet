// @vitest-environment happy-dom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { createApp, h, nextTick, ref } from 'vue'
import WebDAVConfigDialog from './WebDAVConfigDialog.vue'

const calls = vi.hoisted(() => ({ probes: [], shared: { initialize: vi.fn(), loadConfig: vi.fn(), saveConfig: vi.fn() } }))
vi.mock('../../utils/webdav', () => ({
  webdavClient: calls.shared,
  WebDAVClient: class {
    constructor() {
      this.initialize = vi.fn().mockResolvedValue(true)
      this.testConnection = vi.fn().mockResolvedValue({ success: true })
      this.disconnect = vi.fn()
      calls.probes.push(this)
    }
  }
}))
let app
const open = async () => {
  calls.shared.loadConfig.mockReturnValue({ url: 'https://dav.example.com', username: 'test', password: 'test', syncPassword: 'test-sync-password' })
  const host = document.createElement('div'); document.body.append(host)
  const component = ref(null)
  app = createApp({ render: () => h(WebDAVConfigDialog, { ref: component }) })
  app.provide('autoLock', { isLocked: ref(false) })
  app.mount(host); component.value.showDialog(); await nextTick(); await nextTick()
  return component.value
}
afterEach(() => { app?.unmount(); app = null; document.body.innerHTML = ''; calls.probes.length = 0; vi.clearAllMocks() })
describe('isolated WebDAV connection probe', () => {
  it('tests the form without replacing the live synchronization client', async () => {
    await open()
    const button = [...document.querySelectorAll('button')].find(button => button.textContent.trim() === '测试连接')
    button.click()
    await vi.waitFor(() => expect(calls.probes[0].testConnection).toHaveBeenCalledOnce())
    expect(calls.probes[0].initialize).toHaveBeenCalledWith(expect.objectContaining({ url: 'https://dav.example.com/' }))
    expect(calls.shared.initialize).not.toHaveBeenCalled()
    expect(calls.shared.saveConfig).not.toHaveBeenCalled()
  })
  it('cancels its own requests on unmount without disconnecting the shared client', async () => {
    await open()
    const probe = calls.probes[0]
    app.unmount(); app = null
    expect(probe.disconnect).toHaveBeenCalled()
    expect(calls.shared.initialize).not.toHaveBeenCalled()
  })
})
