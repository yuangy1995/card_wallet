import { describe, it, expect } from 'vitest'
import { creditLimitMetrics, prepareTableRows } from './cardMetrics'
import { pageGroups, mergePageSelection } from './cardPagination'
import { cardOrganization } from './cardBrand'
import { escapeHTML, toCSV } from './safeExport'
import { calculateCurrentInterestFreeDays } from './dateCalculator'
const card = (id, extra = {}) => ({ id, country: 'US', bank: 'Bank', type: 'USD', limit: 100, isSharedLimit: true, ...extra })
describe('credit amount and pagination contract', () => {
  it('keeps currencies and regions separate and takes max shared plus independent', () => {
    const cards = [card('a'), card('b', { limit: 200 }), card('c', { limit: 40, isSharedLimit: false }),
      card('d', { country: 'HK', limit: 300 }), card('e', { type: 'HKD', limit: 500 }), card('f', { cardCategory: 'debit', limit: 999 })]
    const result = creditLimitMetrics(cards)
    expect(result.totals).toEqual([{ currency: 'HKD', amount: 500 }, { currency: 'USD', amount: 540 }])
    expect(creditLimitMetrics([...cards].reverse()).totals).toEqual(result.totals)
  })
  it('normalizes bank labels and currency case while preserving unknown currency', () => {
    const result = creditLimitMetrics([card('a', { bank: 'Bank (US)' }), card('b', { bank: 'Bank', type: ' usd ', limit: 250 }), card('c', { type: '', limit: 20 })])
    expect(result.shared).toHaveLength(2)
    expect(result.totals).toEqual([{ currency: '', amount: 20 }, { currency: 'USD', amount: 250 }])
  })
  it('does not add NaN, infinity, negatives or debit cards to limits', () => {
    expect(creditLimitMetrics([card('a', { limit: Infinity }), card('b', { limit: -1 }), card('c', { limit: 'invalid' })]).totals).toEqual([{ currency: 'USD', amount: 0 }])
    expect(creditLimitMetrics([card('d', { cardCategory: 'debit' })]).totals).toEqual([])
  })
  it('adds decimal independent amounts in cents', () => {
    expect(creditLimitMetrics([card('a', { isSharedLimit: false, limit: 0.1 }), card('b', { isSharedLimit: false, limit: 0.2 })]).totals[0].amount).toBe(0.3)
  })
  it('does not merge table cells across independent rows, currency or different values', () => {
    const rows = prepareTableRows([card('a'), card('b'), card('c', { isSharedLimit: false }), card('d'), card('e', { type: 'HKD' }), card('f', { limit: 300 })])
    expect(rows.map(row => row.limitRowSpan)).toEqual([2, 0, 1, 1, 1, 1])
    expect(prepareTableRows([card('a'), card('b')]).map(row => row.bankRowSpan)).toEqual([2, 0])
    expect(card('a')).not.toHaveProperty('limitRowSpan')
  })
  it('bounds 2000 cards to one page without changing full-group totals', () => {
    const all = Array.from({ length: 2000 }, (_, i) => card(String(i)))
    const groups = [{ key: 'bank', cards: all, totals: creditLimitMetrics(all).totals }]
    const page = pageGroups(groups, 20, 24)
    expect(page[0].cards).toHaveLength(24)
    expect(page[0].cards[0].id).toBe('456')
    expect(page[0].fullCount).toBe(2000)
    expect(page[0].totals).toEqual(groups[0].totals)
  })
  it('can slice across group boundaries', () => {
    const result = pageGroups([{ key: 'a', cards: [card('a')] }, { key: 'b', cards: [card('b'), card('c')] }], 1, 2)
    expect(result.map(group => group.cards.map(item => item.id))).toEqual([['a'], ['b']])
  })
  it('preserves selections outside the current page', () => {
    expect(mergePageSelection([card('a'), card('b')], [card('c')], [card('b'), card('c')]).map(row => row.id)).toEqual(['a', 'c'])
    expect(mergePageSelection([card('a'), card('b')], [], [card('b')]).map(row => row.id)).toEqual(['a'])
  })
})
describe('input safety and shared presentation rules', () => {
  it('escapes all dynamic HTML delimiters', () => expect(escapeHTML(`<img src=x onerror="bad">&'`)).toBe('&lt;img src=x onerror=&quot;bad&quot;&gt;&amp;&#39;'))
  it('exports an empty CSV and escapes quotes, newlines and formulas', () => {
    expect(toCSV([], ['银行'])).toBe('\uFEFF"银行"')
    const csv = toCSV([{ bank: '=1+1', note: 'a,"b"\nc' }], ['bank', 'note'])
    expect(csv).toContain('"\'=1+1"')
    expect(csv).toContain('"a,""b""\nc"')
  })
  it.each([['222100','mastercard'], ['272000','mastercard'], ['272100','other'], ['358900','jcb'], ['644123','discover'], ['361234','diners'], ['621234','unionpay']])('detects %s as %s', (number, expected) => expect(cardOrganization({ cardNumber: number })).toBe(expected))
  it('keeps ambiguous textual network hints unknown', () => expect(cardOrganization({ level: 'Visa Mastercard' })).toBe('other'))
  it('respects actual February billing day and the same-day rule', () => {
    const date = new Date(2026, 1, 28, 12)
    const c = { accountBillDate: '31', dueDate: '5' }
    expect(calculateCurrentInterestFreeDays({ ...c, billingDaySpendingToNextBill: false }, date)).toBe(5)
    expect(calculateCurrentInterestFreeDays({ ...c, billingDaySpendingToNextBill: true }, date)).toBe(36)
  })
  it('rejects partially numeric days and debit cards', () => {
    expect(calculateCurrentInterestFreeDays({ accountBillDate: '2x', dueDate: '20' })).toBe(-1)
    expect(calculateCurrentInterestFreeDays(card('debit', { cardCategory: 'debit' }))).toBe(-1)
  })
})
