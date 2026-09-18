// Display hints only. Unambiguous level hints and number boundaries match the native clients.
export function cardOrganization(card = {}) {
  const value = String(card.level || '').toLowerCase()
  const words = new Set(value.split(/[^\p{L}\p{N}]+/u).filter(Boolean))
  const hints = new Set()
  if (/银联|銀聯/.test(value) || words.has('unionpay')) hints.add('unionpay')
  if (words.has('discover') || /发现|發現/.test(value)) hints.add('discover')
  if (words.has('visa')) hints.add('visa')
  if (words.has('mastercard') || /万事达|萬事達/.test(value)) hints.add('mastercard')
  if (words.has('jcb')) hints.add('jcb')
  if (words.has('amex') || words.has('ae') || /american express|运通|運通/.test(value)) hints.add('amex')
  if (words.has('diners') || /大莱|大萊/.test(value)) hints.add('diners')
  if (hints.size === 1) return [...hints][0]
  const digits = String(card.cardNumber || '').replace(/[^0-9]/g, '')
  const length = digits.length
  if (length < 4) return 'other'
  const two = Number(digits.slice(0, 2)), three = Number(digits.slice(0, 3)), four = Number(digits.slice(0, 4))
  if (length === 15 && [34, 37].includes(two)) return 'amex'
  if (length === 16 && ((two >= 51 && two <= 55) || (four >= 2221 && four <= 2720))) return 'mastercard'
  if (length >= 16 && length <= 19 && four >= 3528 && four <= 3589) return 'jcb'
  if (length >= 16 && length <= 19 && (four === 6011 || two === 65 || (three >= 644 && three <= 649))) return 'discover'
  if ([13, 16, 19].includes(length) && digits.startsWith('4')) return 'visa'
  if (length >= 16 && length <= 19 && [62, 81].includes(two)) return 'unionpay'
  if (length === 14 && ((three >= 300 && three <= 305) || [36, 38, 39].includes(two))) return 'diners'
  return 'other'
}
export const cardOrganizationName = value => ({ visa: 'VISA', mastercard: 'MasterCard', amex: '美国运通', unionpay: '银联', discover: 'Discover', jcb: 'JCB', diners: 'Diners Club', other: '其他卡组织' })[value] || '其他卡组织'
