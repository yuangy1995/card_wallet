import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { batchCards } from './cardOperations'
import { migrateCardData } from './cardDataMigration'
import { normalizeCardForSync } from './syncProtocol'
import { canAppendImages } from './cardAttachments'
import { readFavorites, updateFavorites } from './localFavorites'
const cases = name => JSON.parse(readFileSync(new URL(`../../../../contracts/card-wallet/fixtures/${name}.json`, import.meta.url), 'utf8'))
const day = text => { const [y,m,d] = text.split('-').map(Number); return new Date(y,m-1,d,12) }
describe('batch and image contract v1', () => {
  for (const row of cases('batch-operations')) it(row.name, () => {
    const source = {...row.card, nextAnnualFeeCollectionTime: day(row.target).getTime()}
    const update = {...row.update, nextAnnualFeeDate: row.update.nextDate ? day(row.update.nextDate).getTime() : undefined}
    const [result] = batchCards([source], new Set(row.selected), update, day(row.today))
    for (const key of ['isQualified','annualFee','valid']) expect(result[key]).toEqual(row.expected[key])
    expect(result.nextAnnualFeeCollectionTime).toEqual(row.expected.nextDate ? day(row.expected.nextDate).getTime() : null)
    expect(result.lastModifyTime !== source.lastModifyTime).toEqual(row.expected.changed)
    expect(result.cardImages).toEqual(source.cardImages)
    expect(result.futureBenefit).toEqual(source.futureBenefit)
  })
  for (const row of cases('image-roundtrip')) it(row.name, () => {
    const result = normalizeCardForSync({...migrateCardData(row.card), remark:'只修改备注'})
    expect(result.cardImages).toEqual(row.card.cardImages)
    expect(result.futureBenefit).toEqual(row.card.futureBenefit)
    expect(canAppendImages(12,1)).toBe(false); expect(canAppendImages(11,1)).toBe(true)
  })
  it('uses the latest preference and only prunes confirmed deletions', () => {
    const values = new Map(); const storage = {getItem:key=>values.get(key)??null, setItem:(key,value)=>values.set(key,value)}
    updateFavorites({toggle:'a'}, storage); updateFavorites({toggle:'b'}, storage)
    expect([...readFavorites(storage)].sort()).toEqual(['a','b'])
    updateFavorites({deleted:[]},storage); expect([...readFavorites(storage)].sort()).toEqual(['a','b'])
    updateFavorites({deleted:['a']},storage); expect([...readFavorites(storage)]).toEqual(['b'])
  })
})
