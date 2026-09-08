import { beforeEach, describe, expect, it, vi } from 'vitest'
import { reactive } from 'vue'
import { cardSyncLedger } from './syncLedger'
import { activeCards } from './syncProtocol'
import { STORAGE_KEYS } from '@/config/constants'
import { CardDataStorage } from './storage'
import { localDataStore } from './indexedDbStorage'
import { createIndexedDbMock } from './indexedDbStorage.testUtils'

const card = (id) => ({
  id,
  country: 'CN',
  bank: 'Test Bank',
  cardNumber: '1234',
  lastModifyTime: '2026-01-01T00:00:00.000Z'
})

describe('web sync ledger', () => {
  let values

  beforeEach(async () => {
    vi.useRealTimers()
    values = new Map()
    vi.stubGlobal('localStorage', {
      getItem: (key) => values.has(key) ? values.get(key) : null,
      setItem: (key, value) => values.set(key, String(value)),
      removeItem: (key) => values.delete(key),
      clear: () => values.clear()
    })
    vi.stubGlobal('indexedDB', createIndexedDbMock())
    await localDataStore.resetForTests()
    await localDataStore.initialize()
  })

  it('keeps a local deletion as a pending tombstone', async () => {
    await cardSyncLedger.initialize([card('deleted')])
    const records = await cardSyncLedger.commit([], { deletedCardIds: ['deleted'] })

    expect(records[0].state).toBe('deleted')
    expect(records[0].card).toBeUndefined()
    expect(cardSyncLedger.isPending()).toBe(true)
    expect(activeCards(records)).toEqual([])
  })

  it('generates tombstones for cards removed by a confirmed restore', async () => {
    await cardSyncLedger.initialize([card('keep'), card('remove')])
    const records = await cardSyncLedger.commit([card('keep')], { replace: true })

    expect(records.find(record => record.cardId === 'remove').state).toBe('deleted')
    expect(activeCards(records).map(item => item.id)).toEqual(['keep'])
  })

  it('does not create a new event when only last modify time changed', async () => {
    const initial = card('same')
    const initialized = await cardSyncLedger.initialize([initial])
    const records = await cardSyncLedger.commit([
      {
        ...initial,
        lastModifyTime: '2026-05-27T01:23:45.000Z'
      }
    ])

    expect(records).toHaveLength(1)
    expect(records[0].mutationId).toBe(initialized[0].mutationId)
    expect(cardSyncLedger.isPending()).toBe(false)
  })

  it('does not create a new event for table display state changes', async () => {
    const initial = card('display')
    const initialized = await cardSyncLedger.initialize([initial])
    const records = await cardSyncLedger.commit([
      {
        ...initial,
        showCardNumber: true,
        showCVV: true,
        bankRowSpan: 2
      }
    ])

    expect(records).toHaveLength(1)
    expect(records[0].mutationId).toBe(initialized[0].mutationId)
    expect(records[0].card.showCardNumber).toBeUndefined()
    expect(records[0].card.bankRowSpan).toBeUndefined()
    expect(cardSyncLedger.isPending()).toBe(false)
  })

  it('uses the current sync time when a real field changes', async () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-05-27T01:23:45.678Z'))
    await cardSyncLedger.initialize([card('changed')])

    const records = await cardSyncLedger.commit([
      {
        ...card('changed'),
        bank: 'Updated Bank'
      }
    ])

    expect(records[0].state).toBe('active')
    expect(records[0].changedAt).toBe('2026-05-27T01:23:45.678Z')
    expect(records[0].card.lastModifyTime).toBe(Date.parse('2026-05-27T01:23:45.678Z'))
    expect(cardSyncLedger.isPending()).toBe(true)
  })

  it('assigns stable ids to cards before seeding the ledger', async () => {
    const records = await cardSyncLedger.initialize([
      {
        ...card(''),
        bank: 'Missing ID Bank'
      }
    ])

    expect(records).toHaveLength(1)
    expect(records[0].cardId).toBeTruthy()
    expect(activeCards(records)[0].id).toBe(records[0].cardId)
  })

  it('stores the canonical ledger outside localStorage', async () => {
    const records = await cardSyncLedger.initialize([card('indexeddb-ledger')])

    expect(values.has(STORAGE_KEYS.SYNC_RECORDS)).toBe(false)
    expect(values.has(STORAGE_KEYS.CARD_DATA)).toBe(false)
    expect(activeCards(records)[0].id).toBe('indexeddb-ledger')
  })

  it('clears legacy large localStorage keys when IndexedDB initializes', async () => {
    await localDataStore.resetForTests()
    values.set(STORAGE_KEYS.CARD_DATA, JSON.stringify([card('legacy-card-cache')]))
    values.set(STORAGE_KEYS.SYNC_RECORDS, JSON.stringify([]))
    values.set(STORAGE_KEYS.SYNC_PENDING, JSON.stringify(true))
    values.set(STORAGE_KEYS.SYNC_REVISION, JSON.stringify(9))

    await localDataStore.initialize()

    expect(values.has(STORAGE_KEYS.CARD_DATA)).toBe(false)
    expect(values.has(STORAGE_KEYS.SYNC_RECORDS)).toBe(false)
    expect(values.has(STORAGE_KEYS.SYNC_PENDING)).toBe(false)
    expect(values.has(STORAGE_KEYS.SYNC_REVISION)).toBe(false)
  })

  it('fails fast when IndexedDB is unavailable', async () => {
    await localDataStore.resetForTests()
    vi.stubGlobal('indexedDB', undefined)

    await expect(localDataStore.initialize()).rejects.toThrow('不支持 IndexedDB')
  })

  it('recovers cardData from the local database ledger', async () => {
    const records = await cardSyncLedger.initialize([card('recover-from-ledger')])

    expect(CardDataStorage.getCardData().map(item => item.id)).toEqual(['recover-from-ledger'])
    expect(records).toHaveLength(1)
  })

  it('persists Vue reactive card collections as plain JSON data', async () => {
    const reactiveCards = reactive([card('reactive-card')])

    await cardSyncLedger.initialize(reactiveCards)

    const storedRecords = cardSyncLedger.load()
    expect(storedRecords[0].cardId).toBe('reactive-card')
    expect(storedRecords[0].card.bank).toBe('Test Bank')
  })
})
