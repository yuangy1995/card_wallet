// @vitest-environment happy-dom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { createApp, nextTick } from 'vue'
import VaultApp from './VaultApp.vue'
const database = vi.hoisted(() => ({ initialize: vi.fn().mockResolvedValue({}), isUnlocked: false }))
const manager = vi.hoisted(() => ({ LOCK_STATE_KEY: 'app_lock_state', hasPassword: () => true, lockApp: vi.fn(), unlockApp: vi.fn() }))
vi.mock('./utils/indexedDbStorage', () => ({ localDataStore: database }))
vi.mock('./utils/passwordManager', () => ({ PasswordManager: manager }))
vi.mock('./composables/useTheme', () => ({ useTheme: () => ({}) }))
vi.mock('./composables/useCalendarDay', () => ({ useCalendarDay: () => ({}) }))
vi.mock('./components/security/PasswordVerify.vue', () => ({ default: { template: '<div>locked</div>' } }))
let app
const mount = async () => {
  const root = document.createElement('div'); document.body.append(root)
  app = createApp(VaultApp); app.mount(root)
  await nextTick(); await nextTick()
}
afterEach(() => { app?.unmount(); app = null; document.body.innerHTML = ''; vi.clearAllMocks() })
describe('vault entry remote lock lifecycle', () => {
  it('invalidates a pending unlock even before the wallet is mounted', async () => {
    await mount()
    window.dispatchEvent(new StorageEvent('storage', { key: manager.LOCK_STATE_KEY, newValue: JSON.stringify({ isLocked: true }) }))
    expect(manager.lockApp).toHaveBeenCalledWith(false)
    expect(manager.unlockApp).not.toHaveBeenCalled()
  })
  it('ignores shared unlock flags and removes its listener on unmount', async () => {
    await mount()
    window.dispatchEvent(new StorageEvent('storage', { key: manager.LOCK_STATE_KEY, newValue: JSON.stringify({ isLocked: false }) }))
    expect(manager.unlockApp).not.toHaveBeenCalled()
    app.unmount(); app = null
    window.dispatchEvent(new StorageEvent('storage', { key: manager.LOCK_STATE_KEY, newValue: JSON.stringify({ isLocked: true }) }))
    expect(manager.lockApp).not.toHaveBeenCalled()
  })
})
