import { normalizeBankValue } from '@/utils/referenceDataUtils'

/**
 * 银行名称格式化工具
 * 统一处理银行名称的显示和存储
 */

/**
 * 获取银行显示名称（去除英文部分）
 * @param {string} fullName - 完整的银行名称
 * @returns {string} 中文银行名称
 */
export function getBankDisplayName(fullName) {
  if (!fullName) return ''
  return normalizeBankValue(fullName)
}

/**
 * 获取银行英文名称
 * @param {string} fullName - 完整的银行名称
 * @returns {string} 英文银行名称
 */
export function getBankEnglishName(fullName) {
  if (!fullName) return ''
  const match = fullName.match(/\((.*?)\)/)
  return match ? match[1] : ''
}

/**
 * 构建完整银行名称
 * @param {string} chineseName - 中文名称
 * @param {string} englishName - 英文名称
 * @returns {string} 完整的银行名称
 */
export function buildFullBankName(chineseName, englishName) {
  if (!englishName) return chineseName
  return `${chineseName}(${englishName})`
}

/**
 * 银行名称比较（忽略英文部分）
 * @param {string} bank1 - 银行名称1
 * @param {string} bank2 - 银行名称2
 * @returns {boolean} 是否为同一银行
 */
export function isSameBank(bank1, bank2) {
  return getBankDisplayName(bank1) === getBankDisplayName(bank2)
}

/**
 * 批量处理银行名称（用于显示）
 * @param {Array} cards - 卡片数据数组
 * @returns {Array} 处理后的卡片数据
 */
export function formatBankNamesForDisplay(cards) {
  if (!Array.isArray(cards)) return []
  
  return cards.map(card => ({
    ...card,
    bankDisplayName: getBankDisplayName(card.bank)
  }))
}

export default {
  getBankDisplayName,
  getBankEnglishName,
  buildFullBankName,
  isSameBank,
  formatBankNamesForDisplay
}
