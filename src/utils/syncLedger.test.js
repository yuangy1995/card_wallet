import { beforeEach, describe, expect, it, vi } from 'vitest'
import { cardSyncLedger } from './syncLedger'
import { activeCards } from './syncProtocol'

const card = (id) => ({
  id,
  country: 'CN',
  bank: 'Test Bank',
  cardNumber: '1234',
  lastModifyTime: '2026-01-01T00:00:00.000Z'
})

describe('web sync ledger', () => {
  beforeEach(() => {
    vi.useRealTimers()
    const values = new Map()
    vi.stubGlobal('localStorage', {
      getItem: (key) => values.has(key) ? values.get(key) : null,
      setItem: (key, value) => values.set(key, String(value)),
      removeItem: (key) => values.delete(key),
      clear: () => values.clear()
    })
  })

  it('keeps a local deletion as a pending tombstone', () => {
    cardSyncLedger.initialize([card('deleted')])
    const records = cardSyncLedger.commit([], { deletedCardIds: ['deleted'] })

    expect(records[0].state).toBe('deleted')
    expect(records[0].card).toBeUndefined()
    expect(cardSyncLedger.isPending()).toBe(true)
    expect(activeCards(records)).toEqual([])
  })

  it('generates tombstones for cards removed by a confirmed restore', () => {
    cardSyncLedger.initialize([card('keep'), card('remove')])
    const records = cardSyncLedger.commit([card('keep')], { replace: true })

    expect(records.find(record => record.cardId === 'remove').state).toBe('deleted')
    expect(activeCards(records).map(item => item.id)).toEqual(['keep'])
  })

  it('does not create a new event when only last modify time changed', () => {
    const initial = card('same')
    const initialized = cardSyncLedger.initialize([initial])
    const records = cardSyncLedger.commit([
      {
        ...initial,
        lastModifyTime: '2026-05-27T01:23:45.000Z'
      }
    ])

    expect(records).toHaveLength(1)
    expect(records[0].mutationId).toBe(initialized[0].mutationId)
    expect(cardSyncLedger.isPending()).toBe(false)
  })

  it('does not create a new event for table display state changes', () => {
    const initial = card('display')
    const initialized = cardSyncLedger.initialize([initial])
    const records = cardSyncLedger.commit([
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

  it('uses the current sync time when a real field changes', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-05-27T01:23:45.678Z'))
    cardSyncLedger.initialize([card('changed')])

    const records = cardSyncLedger.commit([
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

  it('assigns stable ids to cards before seeding the ledger', () => {
    const records = cardSyncLedger.initialize([
      {
        ...card(''),
        bank: 'Missing ID Bank'
      }
    ])

    expect(records).toHaveLength(1)
    expect(records[0].cardId).toBeTruthy()
    expect(activeCards(records)[0].id).toBe(records[0].cardId)
  })
})
