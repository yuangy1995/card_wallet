import { describe, it, expect } from 'vitest'
import fixture from '../../../../contracts/card-wallet/fixtures/unknown-fields.json'
import { migrateCardData } from './cardDataMigration'
import { activeRecord, mergeRecords } from './syncProtocol'
import { futureCardFields } from './cardFutureFields'

describe('opaque future fields from older integration branches', () => {
  it('preserves all JSON values through migration, editing and sync', () => {
    const migrated = migrateCardData(structuredClone(fixture))
    const edited = { ...migrated, alias: 'edited' }
    const synced = mergeRecords([activeRecord(edited)]).find(x => x.cardId === fixture.id).card
    expect(synced.futureProgram).toEqual(fixture.futureProgram)
    expect(synced.futureNull).toBeNull()
    expect(synced.cardImages[0].futureImage).toEqual(fixture.cardImages[0].futureImage)
    expect(synced.alias).toBe('edited')
    for (const key of ['showCVV', '_localOnly', 'legacyId', 'extraFields']) expect(synced).not.toHaveProperty(key)
    for (const key of ['showCVV', '_localOnly']) expect(synced.cardImages[0]).not.toHaveProperty(key)
  })
  it('does not let opaque fields shadow identity or introduce prototype keys', () => {
    const input = JSON.parse('{"id":"shadow","constructor":{},"prototype":{},"__proto__":{"polluted":true},"future":null}')
    const extra = futureCardFields(input, new Set(['id']))
    expect(extra).toEqual({ future: null })
    expect({}.polluted).toBeUndefined()
  })
  it('preserves fields across repeated migrations', () => {
    const once = migrateCardData(structuredClone(fixture))
    expect(migrateCardData(JSON.parse(JSON.stringify(once)))).toEqual(once)
  })
})
