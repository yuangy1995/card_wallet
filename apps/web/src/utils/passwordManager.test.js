import { beforeEach, describe, expect, it, vi } from 'vitest'
import { PasswordManager } from './passwordManager'
import { STORAGE_KEYS } from '@/config/constants'

const storage = vi.hoisted(() => ({ get: vi.fn(), set: vi.fn(), has: vi.fn(), remove: vi.fn() }))
const database = vi.hoisted(() => ({ initialized: true, initialize: vi.fn(), remove: vi.fn() }))
vi.mock('./storage', () => ({ StorageManager: storage }))
vi.mock('./indexedDbStorage', () => ({ localDataStore: database }))

describe('password persistence and reset', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    storage.has.mockReturnValue(true)
    storage.set.mockReturnValue(true)
    storage.remove.mockReturnValue(true)
    database.remove.mockResolvedValue(true)
  })

  it('does not report password setup success when persistence fails', () => {
    storage.set.mockReturnValue(false)
    expect(() => PasswordManager.setAppPassword('test-password')).toThrow('密码未能保存')
    expect(storage.remove).not.toHaveBeenCalled()
  })

  it('locks exactly at the inactivity deadline', () => {
    // 固定“现在”及已保存的活动时间，不能让 mock 在读取时生成新的活动时间。
    const now = 1_789_689_600_000
    const clock = vi.spyOn(Date, 'now').mockReturnValue(now)
    const lastActivity = now - PasswordManager.AUTO_LOCK_TIMEOUT
    storage.get.mockImplementation((key, fallback) => key === PasswordManager.LAST_ACTIVITY_KEY ? lastActivity : fallback)
    try {
      expect(PasswordManager.shouldAutoLock()).toBe(true)
      expect(PasswordManager.getRemainingLockTime()).toBe(0)
      clock.mockReturnValue(now - 1)
      expect(PasswordManager.shouldAutoLock()).toBe(false)
      expect(PasswordManager.getRemainingLockTime()).toBe(1)
      clock.mockReturnValue(now + 1)
      expect(PasswordManager.shouldAutoLock()).toBe(true)
      expect(PasswordManager.getRemainingLockTime()).toBe(0)
    } finally {
      clock.mockRestore()
    }
  })

  it('removes snapshots and history as well as cards before clearing the password', async () => {
    expect(await PasswordManager.clearAllAppData()).toBe(true)
    const keys = [STORAGE_KEYS.CARD_DATA, STORAGE_KEYS.SYNC_RECORDS, STORAGE_KEYS.SYNC_PENDING,
      STORAGE_KEYS.SYNC_REVISION, STORAGE_KEYS.SYNC_LAST_SNAPSHOT, STORAGE_KEYS.SYNC_HISTORY]
    expect(database.remove.mock.calls.map(([key]) => key).sort()).toEqual([...keys].sort())
    for (const key of keys) expect(storage.remove).toHaveBeenCalledWith(key)
    expect(storage.remove).toHaveBeenCalledWith(PasswordManager.PASSWORD_KEY)
  })

  it('keeps the password if removing legacy data fails', async () => {
    storage.remove.mockReturnValueOnce(false)
    const log = vi.spyOn(console, 'error').mockImplementation(() => {})
    try {
      expect(await PasswordManager.clearAllAppData()).toBe(false)
      expect(database.remove).not.toHaveBeenCalled()
      expect(storage.remove).not.toHaveBeenCalledWith(PasswordManager.PASSWORD_KEY)
    } finally { log.mockRestore() }
  })

  it('keeps the password if removing a database snapshot fails', async () => {
    database.remove.mockRejectedValueOnce(new Error('database unavailable'))
    const log = vi.spyOn(console, 'error').mockImplementation(() => {})
    try {
      expect(await PasswordManager.clearAllAppData()).toBe(false)
      expect(storage.remove).not.toHaveBeenCalledWith(PasswordManager.PASSWORD_KEY)
    } finally { log.mockRestore() }
  })
})
