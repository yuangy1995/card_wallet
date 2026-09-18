import { getAnnualFeeDetection } from './cardReminderRules'

const addYear = value => {
  if (!value) return value
  const date = new Date(value)
  if (!Number.isFinite(date.getTime())) return value
  const year = date.getFullYear() + 1, month = date.getMonth(), day = date.getDate()
  date.setDate(1); date.setFullYear(year); date.setMonth(month)
  date.setDate(Math.min(day, new Date(year, month + 1, 0).getDate()))
  return date.getTime()
}
export function annualStatus(card, status, now = new Date()) {
  if (card.cardCategory === 'debit' || !['1', '2', '3'].includes(status)) return card
  if (status === '1' && card.isQualified === '1' && !getAnnualFeeDetection(card, 60, now)) return card
  const next = status === '1' ? addYear(card.nextAnnualFeeCollectionTime) : status === '3' ? null : card.nextAnnualFeeCollectionTime
  if (status === card.isQualified && next === card.nextAnnualFeeCollectionTime) return card
  return { ...card, isQualified: status, nextAnnualFeeCollectionTime: next, lastModifyTime: now.getTime() }
}
export function batchCards(cards, ids, update, now = new Date()) {
  return cards.map(card => {
    if (!ids.has(card.id)) return card
    let result = { ...card }
    if (update.cardCategory != null) result.cardCategory = update.cardCategory === 'debit' ? 'debit' : 'credit'
    if (result.cardCategory !== 'debit') {
      if (['1', '2', '3'].includes(update.status)) {
        if (update.status === '1' && update.nextAnnualFeeDate == null) result = annualStatus(result, update.status, now)
        else result.isQualified = update.status
      }
      if (update.annualFee != null && Number.isFinite(update.annualFee) && update.annualFee >= 0) result.annualFee = update.annualFee
      if (result.isQualified === '3') result.nextAnnualFeeCollectionTime = null
      else if (update.nextAnnualFeeDate != null) result.nextAnnualFeeCollectionTime = update.nextAnnualFeeDate
    }
    if (update.valid != null) result.valid = update.valid
    if (Object.keys(result).every(key => result[key] === card[key])) return card
    return { ...result, lastModifyTime: now.getTime() }
  })
}
