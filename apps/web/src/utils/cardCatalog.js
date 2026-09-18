import { calculateCurrentInterestFreeDays } from './dateCalculator'
import { cardOrganization, cardOrganizationName } from './cardBrand'

export const sortOptions = [
  ['default', '默认排序'], ['limit-desc', '额度：从高到低'], ['limit-asc', '额度：从低到高'],
  ['interest-desc', '免息期：从长到短'], ['interest-asc', '免息期：从短到长'],
  ['modifyTime', '最近修改时间'], ['annualFee', '下次年费时间']
]
export function cardSearchText(card) {
  return [card.bank, card.alias, card.cardNumber, card.level, card.type, card.country,
    card.equity, card.remark, card.limit ?? 0, card.cardCategory === 'debit' ? '储蓄卡 儲蓄卡 debit' : '信用卡 credit',
    cardOrganizationName(cardOrganization(card))].map(value => String(value ?? '')).join('\n').toLowerCase()
}
export function matchesCard(card, query, index = cardSearchText(card)) {
  const text = String(query ?? '').trim().toLowerCase()
  if (!text) return true
  const compact = text.replace(/[\s-]/g, '')
  if (!compact) return false
  return index.includes(text) || (/^[0-9]+$/.test(compact) && String(card.cardNumber ?? '').replace(/[\s-]/g, '').includes(compact))
}
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0
export function sortCards(cards, key = 'default', today = new Date()) {
  const days = key.startsWith('interest-') ? new Map(cards.map(card => [card.id, calculateCurrentInterestFreeDays(card, today)])) : null
  return [...cards].sort((a, b) => {
    let order = 0
    if (key.startsWith('limit-')) {
      const left = a.cardCategory === 'debit' ? 0 : Math.max(0, Number(a.limit) || 0)
      const right = b.cardCategory === 'debit' ? 0 : Math.max(0, Number(b.limit) || 0)
      order = key === 'limit-asc' ? left - right : right - left
    } else if (days) {
      const left = days.get(a.id), right = days.get(b.id)
      order = left < 0 && right >= 0 ? 1 : left >= 0 && right < 0 ? -1 : key === 'interest-asc' ? left - right : right - left
    } else if (key === 'modifyTime') {
      order = Number(b.lastModifyTime || 0) - Number(a.lastModifyTime || 0)
    } else if (key === 'annualFee') {
      order = Number(a.nextAnnualFeeCollectionTime || Number.MAX_SAFE_INTEGER) - Number(b.nextAnnualFeeCollectionTime || Number.MAX_SAFE_INTEGER)
    } else {
      for (const field of ['country', 'bank', 'alias']) {
        order = compare(String(a[field] || ''), String(b[field] || ''))
        if (order) break
      }
    }
    return order || compare(String(a.id), String(b.id))
  })
}
