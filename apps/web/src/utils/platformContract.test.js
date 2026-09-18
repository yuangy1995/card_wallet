import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { creditLimitMetrics } from './cardMetrics'
import { calculateCurrentInterestFreeDays } from './dateCalculator'
import { getCardExpiryStatus, getAnnualFeeRemainingDays, getAnnualFeeDetection, getBillingCycleDetection } from './cardReminderRules'
import { cardSearchIndex, matchesCardSearch, sortCards } from './cardSearch'
import { mergeRecords } from './syncProtocol'
const fixtures = name => JSON.parse(readFileSync(new URL(`../../../../contracts/card-wallet/fixtures/${name}.json`, import.meta.url), 'utf8'))
const day = text => new Date(`${text}T12:00:00`)
describe('shared four-platform contract v1', () => {
  it.each(fixtures('search'))('search: $name', ({card, query, expected}) => {
    expect(matchesCardSearch(cardSearchIndex(card), query)).toBe(expected)
  })
  it.each(fixtures('sorting'))('sorting: $name', ({cards, mode, today, expected}) => {
    expect(sortCards(cards, mode, day(today)).map(card => card.id)).toEqual(expected)
    expect(sortCards([...cards].reverse(), mode, day(today)).map(card => card.id)).toEqual(expected)
  })
  it.each(fixtures('credit-limits'))('limits: $name', ({ cards, expected }) => {
    expect(Object.fromEntries(creditLimitMetrics(cards).totals.map(row => [row.currency, row.amount]))).toEqual(expected)
    expect(Object.fromEntries(creditLimitMetrics([...cards].reverse()).totals.map(row => [row.currency, row.amount]))).toEqual(expected)
  })
  it.each(fixtures('billing-dates'))('interest: $name', ({ card, today, expected }) => {
    expect(calculateCurrentInterestFreeDays(card, day(today))).toBe(expected)
  })
  it.each(fixtures('expiry'))('expiry: $name', ({ valid, today, expected }) => {
    expect(getCardExpiryStatus(valid, day(today))).toBe(expected)
  })
  it.each(fixtures('annual-fees'))('annual fee: $name', ({ target, today, status, expectedDays, expectedKind }) => {
    const date = day(target).getTime()
    expect(getAnnualFeeRemainingDays(date, day(today))).toBe(expectedDays)
    expect(getAnnualFeeDetection({ isQualified: status, nextAnnualFeeCollectionTime: date }, 60, day(today))?.kind ?? null).toBe(expectedKind)
  })
  it.each(fixtures('reminders'))('reminders: $name', ({ card, today, expected }) => {
    expect(getBillingCycleDetection(card, day(today)).map(({kind, days}) => ({kind, days}))).toEqual(expected)
  })
  it.each(fixtures('sync-conflicts'))('sync: $name', ({ records, expected }) => {
    const simplify = records => mergeRecords(records).map(({cardId, mutationId, state}) => ({cardId, mutationId, state}))
    expect(simplify(records)).toEqual(expected)
    expect(simplify([...records].reverse())).toEqual(expected)
    expect(simplify([...records, ...records])).toEqual(expected)
  })
})
