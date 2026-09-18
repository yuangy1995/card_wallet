// @vitest-environment happy-dom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createApp, h } from 'vue'
import { useAutoLock } from './useAutoLock'

const state = vi.hoisted(() => ({ password: true, locked: false, activity: 0 }))
const manager = vi.hoisted(() => ({
  PASSWORD_KEY: 'password', LOCK_STATE_KEY: 'locked', LAST_ACTIVITY_KEY: 'activity',
  AUTO_LOCK_TIMEOUT: 300_000,
  hasPassword: vi.fn(() => state.password),
  isAppLocked: vi.fn(() => state.locked),
  shouldAutoLock: vi.fn(() => Date.now() - state.activity >= 300_000),
  getRemainingLockTime: vi.fn(() => Math.max(0, 300_000 - (Date.now() - state.activity))),
  updateLastActivity: vi.fn(() => { state.activity = Date.now() }),
  lockApp: vi.fn(() => { state.locked = true }),
  unlockApp: vi.fn(() => { state.locked = false; state.activity = Date.now() })
}))
vi.mock('@/utils/passwordManager', () => ({ PasswordManager: manager }))

describe('automatic lock timing', () => {
  let app, root, lock
  const mount = () => {
    root = document.createElement('div')
    document.body.append(root)
    app = createApp({ setup() { lock = useAutoLock(); return () => h('div') } })
    app.mount(root)
  }
  beforeEach(() => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-09-18T00:00:00Z'))
    state.password = true
    state.locked = false
    state.activity = Date.now()
    vi.clearAllMocks()
  })
  afterEach(() => {
    app?.unmount()
    app = null
    root?.remove()
    vi.useRealTimers()
  })

  it('throttles high frequency input before reading storage', () => {
    mount()
    vi.clearAllMocks()
    for (let i = 0; i < 100; i++) document.dispatchEvent(new Event('mousemove'))
    expect(manager.updateLastActivity).toHaveBeenCalledTimes(1)
    expect(manager.hasPassword.mock.calls.length).toBeLessThanOrEqual(2)
  })

  it('does not extend an expired session on its first resumed input event', () => {
    mount()
    const previousActivity = state.activity
    vi.setSystemTime(Date.now() + 300_001)
    document.dispatchEvent(new Event('mousedown'))
    expect(lock.isLocked.value).toBe(true)
    expect(state.activity).toBe(previousActivity)
  })

  it('checks shared activity before an idle tab locks an active tab', () => {
    mount()
    vi.advanceTimersByTime(240_000)
    state.activity = Date.now() // 另一标签页的活动，故意不派发 storage 事件。
    vi.advanceTimersByTime(60_000)
    expect(lock.isLocked.value).toBe(false)
    expect(lock.remainingTime.value).toBe(240)
    vi.advanceTimersByTime(240_000)
    expect(lock.isLocked.value).toBe(true)
  })

  it('counts elapsed wall time rather than delayed interval ticks', () => {
    mount()
    vi.setSystemTime(Date.now() + 180_000)
    vi.advanceTimersByTime(1000)
    expect(lock.remainingTime.value).toBe(119)
  })

  it('does not give a reloaded page a new full inactivity timeout', () => {
    state.activity -= 240_000
    mount()
    expect(lock.remainingTime.value).toBe(60)
    vi.advanceTimersByTime(60_000)
    expect(lock.isLocked.value).toBe(true)
  })

  it('updates timers when another page changes its activity time', () => {
    mount()
    vi.advanceTimersByTime(240_000)
    state.activity = Date.now()
    window.dispatchEvent(new StorageEvent('storage', { key: manager.LAST_ACTIVITY_KEY }))
    expect(lock.remainingTime.value).toBe(300)
    vi.advanceTimersByTime(60_000)
    expect(lock.isLocked.value).toBe(false)
  })

  it('cleans up listeners and timers when the password is removed or the view unmounts', () => {
    mount()
    state.password = false
    window.dispatchEvent(new StorageEvent('storage', { key: manager.PASSWORD_KEY }))
    expect(lock.hasPassword.value).toBe(false)
    expect(lock.remainingTime.value).toBe(0)
    expect(vi.getTimerCount()).toBe(0)
    vi.clearAllMocks()
    document.dispatchEvent(new Event('mousemove'))
    expect(manager.hasPassword).not.toHaveBeenCalled()
    app.unmount()
    app = null
    window.dispatchEvent(new StorageEvent('storage', { key: manager.LOCK_STATE_KEY }))
    expect(manager.hasPassword).not.toHaveBeenCalled()
  })
  it('honors a received lock even when shared storage has since been unlocked', () => {
    mount()
    state.locked = false // 另一页已再次写入解锁值，但排队的锁定事件仍须清除本页密钥。
    window.dispatchEvent(new StorageEvent('storage', {
      key: manager.LOCK_STATE_KEY, newValue: JSON.stringify({ isLocked: true })
    }))
    expect(lock.isLocked.value).toBe(true)
    expect(manager.lockApp).toHaveBeenLastCalledWith(false)
    expect(vi.getTimerCount()).toBe(0)
  })

})
