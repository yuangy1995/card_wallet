import { normalizeBankNameForMatch } from './bankName'
import { calculateCurrentInterestFreeDays } from './dateCalculator'
import { cardOrganizationName, cardOrganization } from './cardBrand'

const text = value => String(value ?? '').trim().toLowerCase()
export function cardSearchIndex(card) {
  return [card.bank, normalizeBankNameForMatch(card.bank), card.alias, card.cardNumber,
    String(card.cardNumber ?? '').replace(/[^0-9]/g, ''), card.level, card.type, card.country,
    card.equity, card.remark, card.limit, card.cardCategory === 'debit' ? '储蓄卡 儲蓄卡 debit' : '信用卡 credit',
    cardOrganizationName(cardOrganization(card))].map(text).join('\u001f')
}
export function matchesCardSearch(index, query) {
  query = text(query)
  if (!query || index.includes(query)) return true
  const compact = query.replace(/[\s-]/g, '')
  return /^[0-9]+$/.test(compact) && index.includes(compact)
}

export function matchesAdvancedFilters(card, form = {}) {
  const values = value => Array.isArray(value) ? value : value === '' || value == null ? [] : [value]
  for (const key of ['cardCategory', 'type', 'bank', 'level', 'country', 'isQualified']) {
    const selected = values(form[key])
    if (selected.length && !selected.some(value => text(value) === text(card[key]) ||
      (key === 'bank' && normalizeBankNameForMatch(value) === normalizeBankNameForMatch(card.bank)))) return false
  }
  for (const key of ['alias', 'equity', 'remark', 'limit']) {
    if (text(form[key]) && !text(card[key]).includes(text(form[key]))) return false
  }
  if (text(form.cardNumber)) {
    const query = String(form.cardNumber).replace(/[\s-]/g, '')
    if (!query || !String(card.cardNumber ?? '').replace(/[\s-]/g, '').includes(query)) return false
  }
  return true
}

export function sortCards(cards, mode, today = new Date()) {
  mode = typeof mode === 'string' ? (mode === 'modifyTime' ? 'modified-desc' : mode) : 'default'
  if (mode === 'default') return [...cards]
  const days = mode.startsWith('interest-') ? new Map(cards.map(card => [card.id, calculateCurrentInterestFreeDays(card, today)])) : new Map()
  const limit = card => card.cardCategory !== 'debit' && Number.isFinite(Number(card.limit)) ? Math.max(0, Number(card.limit)) : 0
  const cmp = (a, b) => a < b ? -1 : a > b ? 1 : 0
  return [...cards].sort((a, b) => {
    let order = 0
    if (mode === 'limit-asc') order = limit(a) - limit(b)
    else if (mode === 'limit-desc') order = limit(b) - limit(a)
    else if (mode === 'modified-desc') order = Number(b.lastModifyTime || 0) - Number(a.lastModifyTime || 0)
    else if (mode === 'annualFee') order = Number(a.nextAnnualFeeCollectionTime || Infinity) - Number(b.nextAnnualFeeCollectionTime || Infinity)
    else if (mode === 'bank-asc') order = cmp(normalizeBankNameForMatch(a.bank), normalizeBankNameForMatch(b.bank))
    else if (mode.startsWith('interest-')) {
      const left = days.get(a.id), right = days.get(b.id)
      if ((left < 0) !== (right < 0)) order = left < 0 ? 1 : -1
      else order = mode === 'interest-asc' ? left - right : right - left
    }
    return order || cmp(String(a.id), String(b.id))
  })
}
