import { describe, expect, it } from 'vitest'
import { activeCards, activeRecord, cardsEqualForSync, createSnapshot, deletedRecord, mergeRecords } from './syncProtocol'

const card = (id, lastModifyTime = '') => ({
  id,
  country: 'CN',
  bank: 'Test Bank',
  cardNumber: '1234',
  lastModifyTime
})

describe('v3 card sync protocol', () => {
  it('takes the newest mutation and carries the normalized timestamp into the card', () => {
    const older = activeRecord(card('one'), '2026-01-01T00:00:00.000Z')
    const newer = activeRecord(card('one'), '2026-01-02T00:00:00.000Z')
    const merged = mergeRecords(older, newer)

    expect(merged).toHaveLength(1)
    expect(merged[0].mutationId).toBe(newer.mutationId)
    expect(merged[0].card.lastModifyTime).toBe(Date.parse('2026-01-02T00:00:00.000Z'))
  })

  it('lets a tombstone win at an identical timestamp and prevents resurrection', () => {
    const changedAt = '2026-01-01T00:00:00.000Z'
    const live = activeRecord(card('deleted'), changedAt)
    const tombstone = deletedRecord('deleted', changedAt)
    const merged = mergeRecords(live, tombstone)

    expect(merged[0].state).toBe('deleted')
    expect(activeCards(merged)).toEqual([])
  })

  it('serializes deleted records without card data in a v3 snapshot', () => {
    const snapshot = createSnapshot([deletedRecord('gone')])
    const encoded = JSON.parse(JSON.stringify(snapshot))

    expect(encoded.schemaVersion).toBe('3.0.0')
    expect(encoded.records[0].card).toBeUndefined()
  })

  it('ignores display-only fields and last modify time when comparing cards', () => {
    const left = {
      ...card('same', '2026-01-01T00:00:00.000Z'),
      showCardNumber: true,
      countryRowSpan: 2
    }
    const right = {
      ...card('same', '2026-05-27T01:23:45.000Z'),
      showCardNumber: false,
      countryRowSpan: 1
    }

    expect(cardsEqualForSync(left, right)).toBe(true)
  })

  it('strips display-only fields from active sync records', () => {
    const record = activeRecord({
      ...card('clean'),
      showCVV: true,
      bankRowSpan: 3,
      _status: 'modified'
    }, '2026-05-27T00:00:00.000Z')

    expect(record.card.showCVV).toBeUndefined()
    expect(record.card.bankRowSpan).toBeUndefined()
    expect(record.card._status).toBeUndefined()
    expect(record.card.lastModifyTime).toBe(Date.parse('2026-05-27T00:00:00.000Z'))
  })

  it('converts legacy identity aliases to id and removes alias fields from v3 card payload', () => {
    const record = activeRecord({
      ...card(''),
      cardId: 'legacy-card-id',
      uuid: 'legacy-uuid',
      cardNumber: '6224000000005468'
    }, '2026-05-27T00:00:00.000Z')

    expect(record.cardId).toBe('legacy-card-id')
    expect(record.card.id).toBe('legacy-card-id')
    expect(record.card.cardId).toBeUndefined()
    expect(record.card.uuid).toBeUndefined()
    expect(record.card._id).toBeUndefined()
  })

  it('assigns an identity before writing an active record when a card has no id', () => {
    const record = activeRecord({
      ...card(''),
      cardNumber: '6224000000005468'
    }, '2026-05-27T00:00:00.000Z')

    expect(record.cardId).toBeTruthy()
    expect(record.card.id).toBe(record.cardId)
  })

  it('uses cardId as the identity inside a v3 record', () => {
    const merged = mergeRecords([{
      cardId: 'record-id',
      mutationId: 'mutation',
      changedAt: '2026-05-27T00:00:00.000Z',
      state: 'active',
      card: {
        ...card('stale-payload-id'),
        cardNumber: '6224000000005468'
      }
    }])

    expect(activeCards(merged)[0].id).toBe('record-id')
  })

  it('normalizes card date fields to timestamps inside active records', () => {
    const record = activeRecord({
      ...card('time-fields'),
      lastTime: '2026-05-27',
      nextAnnualFeeCollectionTime: '2026-06-01'
    }, '2026-05-27T00:00:00.000Z')

    expect(record.card.lastTime).toBe(new Date(2026, 4, 27).getTime())
    expect(record.card.nextAnnualFeeCollectionTime).toBe(new Date(2026, 5, 1).getTime())
  })

  it('does not rekey different card ids even when the full card number matches', () => {
    const localWeb = activeRecord({
      ...card('web-id'),
      cardNumber: '6224 0000 0000 5468',
      limit: 90000
    }, '2026-05-27T07:12:47.000Z')
    const incomingMac = activeRecord({
      ...card('mac-id'),
      cardNumber: '6224000000005468',
      limit: 40000
    }, '2026-05-27T07:33:20.000Z')

    const merged = mergeRecords([localWeb], [incomingMac])
    const cards = activeCards(merged)

    expect(cards).toHaveLength(2)
    expect(cards).toContainEqual(expect.objectContaining({ id: 'web-id', limit: 90000 }))
    expect(cards).toContainEqual(expect.objectContaining({ id: 'mac-id', limit: 40000 }))
  })

  it('keeps identity stable when a card number changes under the same card id', () => {
    const beforeReplacement = activeRecord({
      ...card('stable-id'),
      cardNumber: '6224000000005468',
      limit: 90000
    }, '2026-05-27T07:12:47.000Z')
    const afterReplacement = activeRecord({
      ...card('stable-id'),
      cardNumber: '6224000000009999',
      limit: 40000
    }, '2026-05-27T07:33:20.000Z')

    const cards = activeCards(mergeRecords([beforeReplacement], [afterReplacement]))

    expect(cards).toHaveLength(1)
    expect(cards[0].id).toBe('stable-id')
    expect(cards[0].cardNumber).toBe('6224000000009999')
    expect(cards[0].limit).toBe(40000)
  })
})
