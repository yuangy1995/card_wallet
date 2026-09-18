// 仅用于展示提示，不代表 BIN 校验或持卡权验证。所有 Web 视图共用这一规则。
export function cardOrganization(card = {}) {
  const digits = String(card.cardNumber || '').replace(/\D/g, '')
  if (/^4/.test(digits)) return 'visa'
  if (/^5[1-5]/.test(digits) || (digits.length >= 4 && Number(digits.slice(0, 4)) >= 2221 && Number(digits.slice(0, 4)) <= 2720)) return 'mastercard'
  if (/^3[47]/.test(digits)) return 'amex'
  if (/^(30[0-5]|3095|36|38|39)/.test(digits)) return 'diners'
  // 622 区间可能存在联名/受理网络重叠；不据此判断银行归属。
  if (/^62/.test(digits)) return 'unionpay'
  if (/^(6011|64[4-9]|65)/.test(digits)) return 'discover'
  if (digits.length >= 4 && Number(digits.slice(0, 4)) >= 3528 && Number(digits.slice(0, 4)) <= 3589) return 'jcb'
  const text = `${card.level || ''} ${card.alias || ''}`.toLowerCase()
  const hints = [
    ['visa', /visa|维萨/], ['mastercard', /mastercard|master card|万事达/],
    ['amex', /amex|american express|运通/], ['unionpay', /unionpay|银联/],
    ['discover', /discover|发现/], ['jcb', /jcb/], ['diners', /diners|大来/]
  ].filter(([, pattern]) => pattern.test(text))
  return hints.length === 1 ? hints[0][0] : 'other'
}
export const cardOrganizationName = value => ({ visa: 'VISA', mastercard: 'MasterCard', amex: '美国运通', unionpay: '银联', discover: 'Discover', jcb: 'JCB', diners: 'Diners Club', other: '其他卡组织' })[value] || '其他卡组织'
