import { describe, expect, it } from 'vitest'
import { backupPayloadInfo, cardsFromBackupPayload, isLegacyBackupPayload, isSyncSnapshotPayload } from '@/utils/backupPayload'
import { activeRecord, createSnapshot, deletedRecord } from '@/utils/syncProtocol'

describe('backup payload adapters', () => {
  it('reads legacy backup card arrays', () => {
    const cards = [{ id: 'card-1', bank: 'Bank A' }]

    expect(cardsFromBackupPayload({ cards })).toEqual(cards)
    expect(cardsFromBackupPayload(JSON.stringify({ cards }))).toEqual(cards)
    expect(isLegacyBackupPayload({ cards })).toBe(true)
    expect(backupPayloadInfo({ cards })).toMatchObject({
      cards,
      isLegacy: true,
      isSyncSnapshot: false,
      isRecognized: true
    })
  })

  it('reads v3 sync snapshots as active cards only', () => {
    const active = activeRecord({ id: 'card-1', bank: 'Bank A' }, '2026-05-27T00:00:00.000Z')
    const deleted = deletedRecord('card-2', '2026-05-27T00:01:00.000Z')
    const snapshot = createSnapshot([active, deleted])

    expect(isSyncSnapshotPayload(snapshot)).toBe(true)
    expect(isLegacyBackupPayload(snapshot)).toBe(false)
    expect(cardsFromBackupPayload(snapshot)).toEqual([active.card])
    expect(backupPayloadInfo(snapshot)).toMatchObject({
      cards: [active.card],
      isLegacy: false,
      isSyncSnapshot: true,
      isRecognized: true
    })
  })

  it('reads legacy data array backups', () => {
    const cards = [{ id: 'card-2', bank: 'Bank B' }]

    expect(cardsFromBackupPayload({ data: cards })).toEqual(cards)
    expect(isLegacyBackupPayload({ data: cards })).toBe(true)
  })

  it('marks unknown objects as unrecognized instead of treating them as an empty backup', () => {
    const info = backupPayloadInfo({ hello: 'world' })

    expect(info.cards).toEqual([])
    expect(info.isLegacy).toBe(false)
    expect(info.isSyncSnapshot).toBe(false)
    expect(info.isRecognized).toBe(false)
  })
})
