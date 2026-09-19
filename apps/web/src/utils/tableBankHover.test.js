import { describe, expect, it } from 'vitest'
import { bankHoverRange } from './tableBankHover'
const card = (id, bank, country = '中国') => ({ id, bank, country })
describe('visible bank group hover range', () => {
  it('covers all Shanghai Bank rows when hovering a child row', () => {
    const rows = [card('1', '上海银行'), card('2', '上海银行'), card('3', '建设银行')]
    expect(bankHoverRange(rows, '2')).toEqual({ start: 0, end: 2 })
  })
  it('covers a construction bank group without its neighbours', () => {
    const rows = [card('1', '上海银行'), ...Array.from({ length: 5 }, (_, i) => card(String(i + 2), '建设银行')), card('7', '招商银行')]
    expect(bankHoverRange(rows, '4')).toEqual({ start: 1, end: 6 })
  })
  it('does not join another country or a non-contiguous matching bank', () => {
    const rows = [card('1', 'HSBC', 'US'), card('2', 'HSBC', 'UK'), card('3', 'Other', 'UK'), card('4', 'HSBC', 'UK')]
    expect(bankHoverRange(rows, '2')).toEqual({ start: 1, end: 2 })
    expect(bankHoverRange(rows, '4')).toEqual({ start: 3, end: 4 })
  })
  it('only includes rows on this page and clears a disappeared record', () => {
    expect(bankHoverRange([card('2', '上海银行')], '2')).toEqual({ start: 0, end: 1 })
    expect(bankHoverRange([], '2')).toBeNull()
  })
})
