// @vitest-environment happy-dom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { effectScope, ref } from 'vue'
import { usePagedCards } from './usePagedCards'
const scopes = []
afterEach(() => { scopes.splice(0).forEach(scope => scope.stop()); localStorage.clear(); vi.restoreAllMocks() })
const make = (size = 50, key = 'walletTablePageSize') => {
  const cards = ref(Array.from({ length: 115 }, (_, i) => ({ id: String(i) })))
  const scope = effectScope(); scopes.push(scope)
  return { cards, ...scope.run(() => usePagedCards(cards, size, key)) }
}
describe('card page sizes and result changes', () => {
  it('keeps the table default and supports the last partial page', () => {
    const view = make(); expect(view.rows.value).toHaveLength(50)
    view.page.value = 3; expect(view.rows.value).toHaveLength(15)
    expect(view.rows.value[0].id).toBe('100')
  })
  it('resets on size change and remembers only a valid numeric preference', () => {
    const view = make(); view.page.value = 3; view.pageSize.value = 20
    expect(view.page.value).toBe(1); expect(view.rows.value).toHaveLength(20)
    expect(localStorage.getItem('walletTablePageSize')).toBe('20')
    expect(make().pageSize.value).toBe(20)
    view.pageSize.value = 0; expect(view.pageSize.value).toBe(20)
    view.pageSize.value = 200; expect(view.rows.value).toHaveLength(115)
  })
  it('resets after filtering, clearing the filter, and reordering', () => {
    const view = make(); const all = view.cards.value; view.page.value = 3
    view.cards.value = all.slice(0, 60); expect(view.page.value).toBe(1)
    view.page.value = 2; view.cards.value = all; expect(view.page.value).toBe(1)
    view.page.value = 2; view.cards.value = [...all].reverse(); expect(view.page.value).toBe(1)
  })
  it('does not leave the page when only record fields are updated', () => {
    const view = make(); view.page.value = 2
    view.cards.value = view.cards.value.map(card => ({ ...card, alias: 'Updated' }))
    expect(view.page.value).toBe(2)
  })
  it('handles empty results and keeps card-view preferences separate', () => {
    localStorage.setItem('walletTablePageSize', '200')
    const view = make(24, 'walletCardsPageSize'); expect(view.pageSize.value).toBe(24)
    view.page.value = 3; view.cards.value = []
    expect(view.page.value).toBe(1); expect(view.pageCount.value).toBe(1); expect(view.rows.value).toEqual([])
  })
  it('ignores malformed preferences and works when storage is disabled', () => {
    localStorage.setItem('walletTablePageSize', 'NaN'); expect(make().pageSize.value).toBe(50)
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => { throw new Error('disabled') })
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => { throw new Error('disabled') })
    const view = make(); view.pageSize.value = 100; expect(view.rows.value).toHaveLength(100)
  })
})
