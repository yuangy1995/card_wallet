import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { webcrypto } from 'node:crypto'
import CryptoJS from 'crypto-js'
import { localDataStore } from './indexedDbStorage'
import { PasswordManager } from './passwordManager'
import { STORAGE_KEYS } from '@/config/constants'
import { createDatabase } from './vaultDatabase.testUtils'
import { createVault, unwrapMaster, verifyMaster, sealValue, openValue, VAULT_META_KEY } from './localVaultCrypto'
import { encryptData } from './encryption'
const password = 'correct-local-password'
let database, legacy
beforeEach(async () => {
  database = createDatabase()
  legacy = new Map()
  vi.stubGlobal('crypto', webcrypto)
  vi.stubGlobal('indexedDB', database.indexedDB)
  vi.stubGlobal('localStorage', {
    getItem: key => legacy.get(key) ?? null, setItem: (key, value) => legacy.set(key, String(value)), removeItem: key => legacy.delete(key)
  })
  await localDataStore.resetForTests()
  await localDataStore.initialize()
})
afterEach(async () => { await localDataStore.resetForTests(); vi.unstubAllGlobals() })
const seed = async () => {
  await localDataStore.set(STORAGE_KEYS.SYNC_RECORDS, [{ cardId: 'test', card: { bank: 'SECRET_BANK', cardNumber: '4111222233334444', cvv: '123' } }])
  await localDataStore.enableVault(password, [[STORAGE_KEYS.WEBDAV_CONFIG, { password: 'WEBDAV_SECRET', syncPassword: 'SYNC_SECRET' }]])
}
describe('real Web Crypto local vault', () => {
  it('uses random salts, IVs and non-extractable runtime keys', async () => {
    const a = await createVault(password), b = await createVault(password)
    expect(a.metadata.salt).not.toBe(b.metadata.salt)
    expect(a.key.extractable).toBe(false)
    const x = await sealValue('secret', a.key, a.metadata.id, 'row'), y = await sealValue('secret', a.key, a.metadata.id, 'row')
    expect(x.iv).not.toBe(y.iv)
    expect(await openValue(x, a.key, a.metadata.id, 'row')).toBe('secret')
    await expect(openValue(x, a.key, a.metadata.id, 'different-row')).rejects.toThrow()
    await expect(openValue(x, a.key, b.metadata.id, 'row')).rejects.toThrow()
  })
  it('encrypts cards, snapshots and WebDAV secrets; locking drops the cache and key', async () => {
    await seed()
    const persisted = JSON.stringify([...database.values])
    for (const secret of ['SECRET_BANK', '4111222233334444', 'WEBDAV_SECRET', 'SYNC_SECRET']) expect(persisted).not.toContain(secret)
    expect(localDataStore.get(STORAGE_KEYS.WEBDAV_CONFIG).password).toBe('WEBDAV_SECRET')
    localDataStore.lock()
    expect(localDataStore.cache.size).toBe(0)
    expect(localDataStore.vaultKey).toBeNull()
    expect(() => localDataStore.get(STORAGE_KEYS.SYNC_RECORDS)).toThrow('锁定')
    await expect(localDataStore.set('x', 'secret')).rejects.toThrow('锁定')
    await localDataStore.unlockVault(password)
    expect(localDataStore.get(STORAGE_KEYS.SYNC_RECORDS)[0].card.bank).toBe('SECRET_BANK')
  })
  it('requires the password after a process restart despite an unlocked localStorage flag', async () => {
    await seed()
    legacy.set(PasswordManager.LOCK_STATE_KEY, JSON.stringify({ isLocked: false }))
    await localDataStore.resetForTests(); await localDataStore.initialize()
    expect(PasswordManager.isAppLocked()).toBe(true)
    expect(localDataStore.cache.size).toBe(0)
    await expect(localDataStore.unlockVault('wrong')).rejects.toThrow()
    expect(localDataStore.isUnlocked).toBe(false)
    await localDataStore.unlockVault(password)
    expect(localDataStore.isUnlocked).toBe(true)
  })
  it('does not partly open data with a modified ciphertext', async () => {
    await seed(); localDataStore.lock()
    const encrypted = database.values.get(STORAGE_KEYS.WEBDAV_CONFIG)
    encrypted.ciphertext = (encrypted.ciphertext[0] === 'A' ? 'B' : 'A') + encrypted.ciphertext.slice(1)
    await expect(localDataStore.unlockVault(password)).rejects.toThrow()
    expect(localDataStore.cache.size).toBe(0)
    expect(localDataStore.isUnlocked).toBe(false)
  })
  it('preserves old plaintext if the atomic encryption migration fails', async () => {
    await localDataStore.set('cards', [{ bank: 'OLD' }])
    database.controls.failNextWrite = true
    await expect(localDataStore.enableVault(password)).rejects.toThrow('quota')
    expect(database.values.get('cards')).toEqual([{ bank: 'OLD' }])
    expect(database.values.has(VAULT_META_KEY)).toBe(false)
    await localDataStore.enableVault(password)
    expect(database.values.get('cards').format).toBe('card-wallet-sealed-v1')
  })
  it('migrates legacy password and fixed-key WebDAV configuration only after correct authentication', async () => {
    const hash = CryptoJS.SHA256(password + 'app_salt_2024').toString()
    legacy.set(PasswordManager.PASSWORD_KEY, JSON.stringify(CryptoJS.AES.encrypt(hash, 'password_encryption_key').toString()))
    legacy.set(STORAGE_KEYS.WEBDAV_CONFIG, encryptData(JSON.stringify({ password: 'WEBDAV_SECRET', syncPassword: 'SYNC_SECRET' })))
    await localDataStore.set(STORAGE_KEYS.CARD_DATA, [{ bank: 'OLD_BANK' }])
    expect(await PasswordManager.verifyPassword('wrong')).toBe(false)
    expect(legacy.has(PasswordManager.PASSWORD_KEY)).toBe(true)
    expect(await PasswordManager.verifyPassword(password)).toBe(true)
    expect(legacy.has(PasswordManager.PASSWORD_KEY)).toBe(false)
    expect(legacy.has(STORAGE_KEYS.WEBDAV_CONFIG)).toBe(false)
    expect(localDataStore.get(STORAGE_KEYS.WEBDAV_CONFIG).syncPassword).toBe('SYNC_SECRET')
    expect(JSON.stringify([...database.values])).not.toContain('OLD_BANK')
  })
  it('rewraps only the master key on password change and rejects the old password', async () => {
    await seed()
    const rowBefore = structuredClone(database.values.get(STORAGE_KEYS.SYNC_RECORDS))
    await localDataStore.changeVaultPassword(password, 'replacement-password')
    expect(database.values.get(STORAGE_KEYS.SYNC_RECORDS)).toEqual(rowBefore)
    localDataStore.lock()
    await expect(localDataStore.unlockVault(password)).rejects.toThrow()
    await localDataStore.unlockVault('replacement-password')
    expect(localDataStore.get(STORAGE_KEYS.WEBDAV_CONFIG).password).toBe('WEBDAV_SECRET')
  })
  it('preserves the old password and data if password change cannot commit', async () => {
    await seed()
    database.controls.failNextWrite = true
    await expect(localDataStore.changeVaultPassword(password, 'replacement-password')).rejects.toThrow()
    localDataStore.lock(); await localDataStore.unlockVault(password)
    expect(localDataStore.get(STORAGE_KEYS.SYNC_RECORDS)).toHaveLength(1)
  })
  it('does not publish late writes after a lock', async () => {
    await seed()
    const write = localDataStore.set('late', 'secret')
    localDataStore.lock()
    await expect(write).rejects.toThrow('锁定')
    expect(database.values.has('late')).toBe(false)
    expect(localDataStore.cache.size).toBe(0)
  })
  it('rejects stale-tab writes rather than overwriting newer committed data', async () => {
    await seed()
    database.values.get(VAULT_META_KEY).revision += 1
    await expect(localDataStore.set('stale', 'bad')).rejects.toThrow('其他页面')
    expect(database.values.has('stale')).toBe(false)
    expect(localDataStore.isUnlocked).toBe(false)
  })
  it('commits ledger and metadata atomically and rolls all back on error', async () => {
    await seed()
    database.controls.failNextWrite = true
    await expect(localDataStore.setMany([['records', [1]], ['pending', true]])).rejects.toThrow('quota')
    expect(database.values.has('records')).toBe(false)
    expect(database.values.has('pending')).toBe(false)
    await localDataStore.setMany([['records', [1]], ['pending', true]])
    expect(localDataStore.get('records')).toEqual([1])
    expect(localDataStore.get('pending')).toBe(true)
  })
  it('clears encrypted snapshots, credentials and metadata together on confirmed reset', async () => {
    await seed()
    await localDataStore.set('snapshot', [{ bank: 'SECRET' }])
    localDataStore.lock()
    expect(await PasswordManager.clearAllAppData()).toBe(true)
    expect(database.values.size).toBe(0)
    expect(localDataStore.vaultMetadata).toBeNull()
    expect(PasswordManager.hasPassword()).toBe(false)
  })
  it('rejects unbounded KDF parameters without running attacker-selected work', async () => {
    const { metadata } = await createVault(password)
    await expect(unwrapMaster(password, { ...metadata, iterations: 999999999 })).rejects.toThrow('参数')
  })
  it('refuses to silently downgrade an encrypted database whose metadata is missing', async () => {
    await seed(); database.values.delete(VAULT_META_KEY)
    await localDataStore.resetForTests()
    await expect(localDataStore.initialize()).rejects.toThrow('加密信息缺失')
    expect(database.values.size).toBeGreaterThan(0)
  })
})
