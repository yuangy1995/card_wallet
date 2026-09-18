// @vitest-environment node
import { describe, it, expect } from 'vitest'
import { readFavoriteIDs, toggledFavorites, retainedFavorites } from './localFavorites'
describe('local-only favorite sets', () => {
  it('deduplicates IDs and never keeps empty/malformed entries', () => {
    expect(Array.from(readFavoriteIDs(['a', 'b', 'b', '', null, 4]))).toEqual(['a','b'])
    expect(Array.from(readFavoriteIDs({one: true}))).toEqual([])
  })
  it('toggles without mutating a caller-owned array', () => {
    const ids=['a']; expect(toggledFavorites(ids,'b')).toEqual(['a','b']);expect(ids).toEqual(['a'])
    expect(toggledFavorites(ids,'a')).toEqual([])
  })
  it('only prunes against committed full data, not the current filtered page', () => {
    expect(retainedFavorites(['a','b'],new Set(['a','b','c']))).toEqual(['a','b'])
    expect(retainedFavorites(['a','b'],new Set(['b']))).toEqual(['b'])
  })
})
