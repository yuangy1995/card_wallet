import { normalizeBankNameForMatch } from './bankName'

export const cardCurrency = card => String(card.type ?? '').trim().toUpperCase()
export const sharedLimitKey = card => JSON.stringify([
  String(card.country ?? '').trim(), normalizeBankNameForMatch(card.bank), cardCurrency(card)
])
const amount = value => {
  const result = Number(value)
  return Number.isFinite(result) && result >= 0 ? result : 0
}

// 同地区、同银行、同币种共享取最大值；独立额度累加，不推测空币种或汇率。
export function creditLimitMetrics(cards = []) {
  const pools = new Map()
  const independent = []
  for (const card of cards) {
    if (card.cardCategory === 'debit') continue
    const currency = cardCurrency(card)
    const limit = amount(card.limit)
    if (card.isSharedLimit !== false) {
      const key = sharedLimitKey(card)
      const pool = pools.get(key) || { key, country: card.country || '', bank: card.bank || '', currency, totalLimit: 0, cardCount: 0 }
      pool.totalLimit = Math.max(pool.totalLimit, limit)
      pool.cardCount++
      pools.set(key, pool)
    } else {
      independent.push({ key: card.id, country: card.country || '', bank: card.bank || '', alias: card.alias, currency, limit })
    }
  }
  const shared = [...pools.values()]
  const sums = new Map()
  const add = (currency, value) => sums.set(currency, (sums.get(currency) || 0) + Math.round(value * 100))
  shared.forEach(pool => add(pool.currency, pool.totalLimit))
  independent.forEach(card => add(card.currency, card.limit))
  return { shared, independent, totals: [...sums].sort(([a], [b]) => a.localeCompare(b)).map(([currency, cents]) => ({ currency, amount: cents / 100 })) }
}

export const formatCreditAmount = (value, currency) => `${currency || '未设置币种'} ${Number(value || 0).toLocaleString('zh-CN', { maximumFractionDigits: 2 })}`

// 只合并当前页内连续、口径及显示值均相同的单元格，不能跨过独立卡或其他币种。
export function prepareTableRows(cards) {
  const rows = cards.map(card => ({ ...card }))
  const signatures = {
    country: card => String(card.country || ''),
    bank: card => JSON.stringify([card.country || '', card.bank || '']),
    limit: (card, i) => card.cardCategory !== 'debit' && card.isSharedLimit !== false
      ? JSON.stringify([sharedLimitKey(card), card.limit]) : `row:${i}`,
    lastTime: (card, i) => card.cardCategory !== 'debit' && card.isSharedLimit !== false
      ? JSON.stringify([sharedLimitKey(card), card.lastTime]) : `row:${i}`
  }
  for (const [field, key] of Object.entries(signatures)) {
    for (let start = 0; start < rows.length;) {
      let end = start + 1
      while (end < rows.length && key(rows[start], start) === key(rows[end], end)) end++
      for (let i = start; i < end; i++) {
        rows[i][`${field}RowSpan`] = i === start ? end - start : 0
        rows[i][`show${field[0].toUpperCase()}${field.slice(1)}`] = i === start
      }
      start = end
    }
  }
  return rows
}

// 新增共享卡继承同口径的最大额度，不能因列表顺序把其他卡的额度降为较小值。
export function existingSharedLimitCard(cards, candidate) {
  if (candidate.cardCategory === 'debit' || candidate.isSharedLimit === false) return null
  const pool = sharedLimitKey(candidate)
  return cards.reduce((best, card) => {
    if (card.id === candidate.id || card.cardCategory === 'debit' || card.isSharedLimit === false || sharedLimitKey(card) !== pool) return best
    if (!best || amount(card.limit) > amount(best.limit) ||
        (amount(card.limit) === amount(best.limit) && String(card.id).localeCompare(String(best.id)) < 0)) return card
    return best
  }, null)
}
