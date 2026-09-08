import { describe, expect, it, vi } from 'vitest'
import { migrateCardData, needsMigration } from './cardDataMigration'

const legacyCard = {
  id: 'legacy',
  country: '中国',
  bank: '中国银行',
  cardNumber: '3568176000000000',
  valid: '12/30',
  limit: 10000,
  type: 'CNY',
  isSharedLimit: true,
  billingDaySpendingToNextBill: true,
  annualFee: 0,
  isQualified: '1',
  nextAnnualFeeCollectionTime: '2026-06-01',
  lastTime: '2026-05-27',
  lastModifyTime: '2026-05-27 01:23:45'
}

describe('card data migration timestamp fields', () => {
  it('migrates legacy date strings to millisecond timestamps', () => {
    const migrated = migrateCardData(legacyCard)

    expect(migrated.nextAnnualFeeCollectionTime).toBe(new Date(2026, 5, 1).getTime())
    expect(migrated.lastTime).toBe(new Date(2026, 4, 27).getTime())
    expect(migrated.lastModifyTime).toBe(new Date(2026, 4, 27, 1, 23, 45).getTime())
    expect(needsMigration(legacyCard)).toBe(true)
    expect(needsMigration(migrated)).toBe(false)
  })

  it('fills missing lastModifyTime with the current timestamp', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-05-27T00:00:00.000Z'))

    const migrated = migrateCardData({
      ...legacyCard,
      lastModifyTime: '',
      lastTime: '',
      nextAnnualFeeCollectionTime: ''
    })

    expect(migrated.lastModifyTime).toBe(Date.now())
    expect(migrated.lastTime).toBeNull()
    expect(migrated.nextAnnualFeeCollectionTime).toBeNull()
    vi.useRealTimers()
  })

  it('preserves cardId aliases instead of generating a new id', () => {
    const migrated = migrateCardData({
      ...legacyCard,
      id: '',
      cardId: 'stable-legacy-id'
    })

    expect(migrated.id).toBe('stable-legacy-id')
    expect(migrated.cardId).toBeUndefined()
  })

  it('does not keep unknown legacy identity fields as the card id', () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

    const migrated = migrateCardData({
      ...legacyCard,
      id: '',
      legacyId: 'unknown-legacy-id'
    })

    expect(migrated.id).toBeTruthy()
    expect(migrated.id).not.toBe('unknown-legacy-id')
    expect(migrated.legacyId).toBeUndefined()

    warnSpy.mockRestore()
  })
})
