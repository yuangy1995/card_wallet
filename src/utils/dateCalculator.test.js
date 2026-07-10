import { describe, expect, it } from 'vitest'
import { calculateCurrentInterestFreeDays } from './dateCalculator'

const creditCard = (overrides = {}) => ({
  cardCategory: 'credit',
  accountBillDate: '10',
  dueDate: '20',
  billingDaySpendingToNextBill: true,
  ...overrides
})

describe('calculateCurrentInterestFreeDays', () => {
  it('uses the current statement when spending before the bill day', () => {
    const today = new Date(2026, 0, 5, 12)
    expect(calculateCurrentInterestFreeDays(creditCard(), today)).toBe(15)
  })

  it('moves bill-day spending according to the configured attribution rule', () => {
    const today = new Date(2026, 0, 10, 12)
    expect(calculateCurrentInterestFreeDays(creditCard(), today)).toBe(41)
    expect(calculateCurrentInterestFreeDays(creditCard({ billingDaySpendingToNextBill: false }), today)).toBe(10)
  })

  it('places an earlier due day in the month after the statement', () => {
    const today = new Date(2026, 0, 5, 12)
    expect(calculateCurrentInterestFreeDays(creditCard({ dueDate: '5' }), today)).toBe(31)
  })

  it('rejects debit cards and invalid billing settings', () => {
    const today = new Date(2026, 0, 5, 12)
    expect(calculateCurrentInterestFreeDays(creditCard({ cardCategory: 'debit' }), today)).toBe(-1)
    expect(calculateCurrentInterestFreeDays(creditCard({ accountBillDate: '32' }), today)).toBe(-1)
    expect(calculateCurrentInterestFreeDays(null, today)).toBe(-1)
  })
})
