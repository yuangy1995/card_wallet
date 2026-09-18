import { describe, it, expect } from 'vitest'
import limits from '../../../../contracts/card-wallet/fixtures/credit-limits.json'
import dates from '../../../../contracts/card-wallet/fixtures/billing-dates.json'
import syncCases from '../../../../contracts/card-wallet/fixtures/sync-cases.json'
import { creditLimitMetrics } from './cardMetrics'
import { calculateCurrentInterestFreeDays } from './dateCalculator'
import { mergeRecords } from './syncProtocol'

describe('four-platform contract v1', () => {
  for (const fixture of limits) it(`credit: ${fixture.name}`, () => {
    for (const cards of [fixture.cards, [...fixture.cards].reverse()]) {
      expect(Object.fromEntries(creditLimitMetrics(cards).totals.map(x => [x.currency, x.amount]))).toEqual(fixture.expected)
    }
  })
  for (const fixture of dates) it(`date: ${fixture.name}`, () => {
    const [year, month, day] = fixture.today.split('-').map(Number)
    expect(calculateCurrentInterestFreeDays(fixture.card, new Date(year, month - 1, day, 12))).toBe(fixture.expected)
  })
  for (const fixture of syncCases) it(`sync: ${fixture.name}`, () => {
    const summarize = records => records.map(({ cardId, state, mutationId }) => ({ cardId, state, mutationId }))
    const merged = mergeRecords(...fixture.collections)
    expect(summarize(merged)).toEqual(fixture.expected)
    expect(summarize(mergeRecords(...[...fixture.collections].reverse()))).toEqual(fixture.expected)
    expect(summarize(mergeRecords(merged, merged))).toEqual(fixture.expected)
    expect(summarize(mergeRecords(JSON.parse(JSON.stringify(merged))))).toEqual(fixture.expected)
  })
})
