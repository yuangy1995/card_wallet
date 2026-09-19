import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { webcrypto } from 'node:crypto'
import fixture from '../../../../contracts/card-wallet/fixtures/session-roundtrip.json'
import { localDataStore } from './indexedDbStorage'
import { createDatabase } from './vaultDatabase.testUtils'
import { STORAGE_KEYS } from '@/config/constants'
import { mergeRecords } from './syncProtocol'

let database
beforeEach(async () => {
  database = createDatabase()
  const preferences = new Map()
  vi.stubGlobal('crypto', webcrypto)
  vi.stubGlobal('indexedDB', database.indexedDB)
  vi.stubGlobal('localStorage', {
    getItem: key => preferences.get(key) ?? null,
    setItem: (key, value) => preferences.set(key, String(value)),
    removeItem: key => preferences.delete(key)
  })
  await localDataStore.resetForTests()
  await localDataStore.initialize()
})
afterEach(async () => { await localDataStore.resetForTests(); vi.unstubAllGlobals() })

it('preserves the shared ledger, images, future fields and pending upload across cold locked reopen', async () => {
  const records = mergeRecords(structuredClone(fixture))
  await localDataStore.setMany([
    [STORAGE_KEYS.SYNC_RECORDS, records],
    [STORAGE_KEYS.SYNC_PENDING, true],
    [STORAGE_KEYS.SYNC_REVISION, 7]
  ])
  await localDataStore.enableVault('synthetic-roundtrip-password')
  const ciphertext = structuredClone(database.values.get(STORAGE_KEYS.SYNC_RECORDS))
  expect(JSON.stringify(ciphertext)).not.toContain('Synthetic Session Bank')
  localDataStore.lock()
  expect(localDataStore.cache.size).toBe(0)
  await localDataStore.resetForTests()
  await localDataStore.initialize()
  expect(localDataStore.isUnlocked).toBe(false)
  expect(localDataStore.cache.size).toBe(0)
  await localDataStore.unlockVault('synthetic-roundtrip-password')
  const restored = localDataStore.get(STORAGE_KEYS.SYNC_RECORDS)
  expect(restored).toEqual(records)
  expect(localDataStore.get(STORAGE_KEYS.SYNC_PENDING)).toBe(true)
  expect(localDataStore.get(STORAGE_KEYS.SYNC_REVISION)).toBe(7)
  expect(database.values.get(STORAGE_KEYS.SYNC_RECORDS)).toEqual(ciphertext)
  expect(restored.find(record => record.state === 'active').card.cardImages).toEqual(fixture[0].card.cardImages)
  expect(restored.find(record => record.state === 'active').card.futureSession).toEqual(fixture[0].card.futureSession)
  expect(mergeRecords(restored, structuredClone(fixture))).toEqual(records)
})
