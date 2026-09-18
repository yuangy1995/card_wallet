/**
 * 信用卡数据迁移和验证工具
 * 用于将老数据结构转换为新数据结构，支持字段扩展和格式转换
 */

import { normalizeCardImages } from './cardAttachments'
import { normalizeCardForSync } from './syncProtocol'
import { DEFAULT_CARD_DATA, REQUIRED_FIELDS, FIELD_TYPES } from '@/config/defaultCardData'
import { CARD_TIMESTAMP_FIELDS, normalizeCardTimeFields, nowCardTimestamp, toCardTimestamp } from '@/utils/cardTimestamp'

/**
 * 转换有效期格式：YYYY-MM-DD 或 YYYY-MM 转为 MM/YY
 * @param {string} valid - 老格式的有效期
 * @returns {string} MM/YY 格式的有效期
 */
function convertValidToMMYY(valid) {
  if (!valid) return ''
  
  // 如果已经是 MM/YY 格式，直接返回
  if (/^\d{2}\/\d{2}$/.test(valid)) {
    return valid
  }
  
  try {
    let month, year
    
    // 处理 YYYY-MM-DD 格式
    if (/^\d{4}-\d{2}-\d{2}$/.test(valid)) {
      const [yearStr, monthStr] = valid.split('-')
      month = monthStr
      year = yearStr.slice(2) // 取后两位
    }
    // 处理 YYYY-MM 格式
    else if (/^\d{4}-\d{2}$/.test(valid)) {
      const [yearStr, monthStr] = valid.split('-')
      month = monthStr
      year = yearStr.slice(2) // 取后两位
    }
    // 处理 Date 对象字符串
    else {
      const date = new Date(valid)
      if (!isNaN(date.getTime())) {
        month = String(date.getMonth() + 1).padStart(2, '0')
        year = String(date.getFullYear()).slice(2)
      } else {
        console.warn(`无法转换有效期格式: ${valid}`)
        return ''
      }
    }
    
    return `${month}/${year}`
  } catch (error) {
    console.error(`转换有效期失败: ${valid}`, error)
    return ''
  }
}

/**
 * 统一账单日/还款日为String类型
 * @param {any} value - 账单日或还款日
 * @returns {string} 字符串格式的日期
 */
function normalizeDate(value) {
  if (value === undefined || value === null || value === '') {
    return ''
  }
  return String(value)
}

/**
 * 确保布尔值类型正确
 * @param {any} value - 待转换的值
 * @param {boolean} defaultValue - 默认值
 * @returns {boolean}
 */
function ensureBoolean(value, defaultValue) {
  if (typeof value === 'boolean') {
    return value
  }
  if (value === 'true' || value === '1' || value === 1) {
    return true
  }
  if (value === 'false' || value === '0' || value === 0) {
    return false
  }
  return defaultValue
}

/**
 * 确保数值类型正确
 * @param {any} value - 待转换的值
 * @param {number} defaultValue - 默认值
 * @returns {number}
 */
function ensureNumber(value, defaultValue) {
  const num = Number(value)
  return isNaN(num) ? defaultValue : num
}

function normalizeCardCategory(value) {
  return value === 'debit' ? 'debit' : 'credit'
}


/**
 * 迁移单条卡片数据
 * @param {Object} oldCard - 老数据结构
 * @param {boolean} trackChanges - 是否追踪字段变化
 * @returns {Object} 新数据结构或包含变化信息的对象
 */
export function migrateCardData(oldCard, trackChanges = false) {
  if (!oldCard || typeof oldCard !== 'object') {
    console.error('无效的卡片数据:', oldCard)
    return null
  }
  
  // 追踪字段变化
  const changes = trackChanges ? [] : null
  
  // 从默认数据开始，确保所有字段都存在
  const migratedCard = { ...DEFAULT_CARD_DATA, ...normalizeCardForSync(oldCard) }
  
  // 1. 处理ID字段
  const stableId = firstStringValue(oldCard, ['id', 'cardId', '_id', 'uuid'])
  if (stableId) {
    migratedCard.id = stableId
  } else {
    // 如果没有ID，生成一个新的UUID
    migratedCard.id = crypto.randomUUID()
    console.warn('卡片缺少内部编号，已自动补齐:', migratedCard.id)
  }

  migratedCard.cardCategory = normalizeCardCategory(oldCard.cardCategory)
  if (trackChanges && oldCard.cardCategory === undefined) {
    changes.push({
      field: 'cardCategory',
      oldValue: undefined,
      newValue: migratedCard.cardCategory,
      reason: '补齐卡片类别，历史数据默认按信用卡处理'
    })
  }
  
  // 2. 复制基本字符串字段
  const stringFields = [
    'country', 'bank', 'alias', 'level', 'cardNumber', 
    'cvv', 'type', 'isQualified', 'equity', 'remark'
  ]
  stringFields.forEach(field => {
    if (oldCard[field] !== undefined && oldCard[field] !== null) {
      migratedCard[field] = String(oldCard[field])
    }
  })

  CARD_TIMESTAMP_FIELDS.forEach(field => {
    const oldValue = oldCard[field]
    const fallback = field === 'lastModifyTime' ? nowCardTimestamp() : null
    const normalizedValue = toCardTimestamp(oldValue, fallback)
    migratedCard[field] = normalizedValue

    const valueWasMissing = oldValue === undefined || oldValue === null || oldValue === ''
    const shouldTrackTimestampChange = field === 'lastModifyTime'
      ? oldValue !== normalizedValue
      : !valueWasMissing && oldValue !== normalizedValue
    if (trackChanges && shouldTrackTimestampChange) {
      changes.push({
        field,
        oldValue,
        newValue: normalizedValue,
        reason: valueWasMissing
          ? '添加时间戳'
          : '时间字段统一转换为毫秒时间戳'
      })
    }
  })
  
  // 3. 转换有效期格式为 MM/YY
  if (oldCard.valid) {
    const oldValid = oldCard.valid
    const newValid = convertValidToMMYY(oldCard.valid)
    migratedCard.valid = newValid
    
    if (trackChanges && oldValid !== newValid) {
      changes.push({
        field: 'valid',
        oldValue: oldValid,
        newValue: newValid,
        reason: '有效期格式转换为 MM/YY'
      })
    }
  }
  
  // 4. 统一账单日和还款日为String类型
  const oldAccountBillDate = oldCard.accountBillDate
  const newAccountBillDate = normalizeDate(oldCard.accountBillDate)
  migratedCard.accountBillDate = newAccountBillDate
  
  if (trackChanges && typeof oldAccountBillDate === 'number') {
    changes.push({
      field: 'accountBillDate',
      oldValue: oldAccountBillDate,
      newValue: newAccountBillDate,
      reason: '类型从 Number 转为 String'
    })
  }
  
  const oldDueDate = oldCard.dueDate
  const newDueDate = normalizeDate(oldCard.dueDate)
  migratedCard.dueDate = newDueDate
  
  if (trackChanges && typeof oldDueDate === 'number') {
    changes.push({
      field: 'dueDate',
      oldValue: oldDueDate,
      newValue: newDueDate,
      reason: '类型从 Number 转为 String'
    })
  }
  
  // 5. 确保数值类型正确
  migratedCard.limit = ensureNumber(oldCard.limit, 0)
  migratedCard.annualFee = ensureNumber(oldCard.annualFee, 0)
  
  // 6. 确保布尔值类型正确，添加新字段的默认值
  const oldIsSharedLimit = oldCard.isSharedLimit
  migratedCard.isSharedLimit = ensureBoolean(
    oldCard.isSharedLimit, 
    DEFAULT_CARD_DATA.isSharedLimit
  )
  
  if (trackChanges && oldIsSharedLimit === undefined) {
    changes.push({
      field: 'isSharedLimit',
      oldValue: undefined,
      newValue: migratedCard.isSharedLimit,
      reason: '补齐缺少的信息'
    })
  }
  
  const oldBillingDay = oldCard.billingDaySpendingToNextBill
  migratedCard.billingDaySpendingToNextBill = ensureBoolean(
    oldCard.billingDaySpendingToNextBill,
    DEFAULT_CARD_DATA.billingDaySpendingToNextBill
  )
  
  if (trackChanges && oldBillingDay === undefined) {
    changes.push({
      field: 'billingDaySpendingToNextBill',
      oldValue: undefined,
      newValue: migratedCard.billingDaySpendingToNextBill,
      reason: '补齐缺少的信息'
    })
  }
  
  // 7. 如果没有lastModifyTime，添加当前时间
  if (!migratedCard.lastModifyTime) {
    const timestamp = nowCardTimestamp()
    migratedCard.lastModifyTime = timestamp
    
    if (trackChanges) {
      changes.push({
        field: 'lastModifyTime',
        oldValue: undefined,
        newValue: timestamp,
        reason: '添加最后修改时间'
      })
    }
  }
  
  migratedCard.cardImages = normalizeCardImages(oldCard.cardImages)

  // 8. 移除老数据中可能存在的废弃字段
  // 例如：annualFeeDate 字段已不再使用
  if (oldCard.annualFeeDate && trackChanges) {
    changes.push({
      field: 'annualFeeDate',
      oldValue: oldCard.annualFeeDate,
      newValue: undefined,
      reason: '移除不再使用的信息'
    })
  }
  delete migratedCard.annualFeeDate
  
  if (trackChanges) {
    return {
      card: migratedCard,
      changes: changes,
      hasChanges: changes.length > 0
    }
  }
  
  return migratedCard
}

/**
 * 批量迁移卡片数据
 * @param {Array} oldCards - 老数据数组
 * @param {boolean} trackChanges - 是否追踪字段变化
 * @returns {Object} { data: 迁移后的数据, errors: 错误列表, details: 详细信息 }
 */
export function migrateCardDataBatch(oldCards, trackChanges = false) {
  if (!Array.isArray(oldCards)) {
    console.error('输入数据必须是数组')
    return { data: [], errors: ['输入数据必须是数组'], details: [] }
  }
  
  const migratedData = []
  const errors = []
  const details = []
  
  oldCards.forEach((card, index) => {
    try {
      const migrated = migrateCardData(card, trackChanges)
      
      if (trackChanges && migrated) {
        migratedData.push(migrated.card)
        if (migrated.hasChanges) {
          details.push({
            index,
            cardId: card.id,
            cardInfo: {
              bank: card.bank,
              alias: card.alias,
              cardNumber: card.cardNumber
            },
            changes: migrated.changes
          })
        }
      } else if (migrated) {
        migratedData.push(migrated)
      } else {
        errors.push({
          index,
          cardId: card.id,
          message: '卡片整理失败'
        })
      }
    } catch (error) {
      console.error(`迁移卡片失败 (索引: ${index}):`, error)
      errors.push({
        index,
        cardId: card.id,
        message: error.message
      })
    }
  })
  
  return {
    data: migratedData,
    errors,
    details,
    success: errors.length === 0
  }
}

function firstStringValue(source, keys) {
  for (const key of keys) {
    const value = source?.[key]
    if (value === undefined || value === null) continue
    const normalized = String(value).trim()
    if (normalized) return normalized
  }
  return ''
}

/**
 * 验证卡片数据完整性
 * @param {Object} card - 卡片数据
 * @returns {Object} { valid: boolean, errors: string[] }
 */
export function validateCardData(card) {
  const errors = []
  
  if (!card || typeof card !== 'object') {
    return { valid: false, errors: ['无效的卡片数据'] }
  }
  
  // 1. 检查必填字段
  REQUIRED_FIELDS.forEach(field => {
    const value = card[field]
    if (value === undefined || value === null || value === '') {
      errors.push(`缺少必填信息: ${field}`)
    }
  })
  
  // 2. 检查字段类型
  Object.keys(FIELD_TYPES).forEach(field => {
    if (card[field] !== undefined && card[field] !== null && card[field] !== '') {
      const expectedType = FIELD_TYPES[field]
      const actualType = Array.isArray(card[field]) ? 'array' : typeof card[field]
      
      if (actualType !== expectedType) {
        errors.push(`${field} 的内容格式不正确`)
      }
    }
  })
  
  // 3. 检查卡号格式
  if (card.cardNumber) {
    const cleanNumber = String(card.cardNumber).replace(/\D/g, '')
    if (cleanNumber.length < 13 || cleanNumber.length > 19) {
      errors.push('卡号长度必须在13-19位之间')
    }
  }
  
  // 4. 检查有效期格式 (MM/YY)
  if (card.valid && !/^\d{2}\/\d{2}$/.test(card.valid)) {
    errors.push('有效期格式错误，应为 MM/YY')
  }
  
  // 5. 检查CVV格式
  if (card.cvv && !/^\d{3,4}$/.test(card.cvv)) {
    errors.push('CVV必须为3-4位数字')
  }
  
  // 6. 检查isQualified值
  if (card.isQualified && !['1', '2', '3'].includes(card.isQualified)) {
    errors.push('年费达标状态值错误，应为 "1"、"2" 或 "3"')
  }
  
  // 7. 检查账单日和还款日
  if (card.accountBillDate) {
    const day = parseInt(card.accountBillDate, 10)
    if (isNaN(day) || day < 1 || day > 31) {
      errors.push('账单日必须在1-31之间')
    }
  }
  
  if (card.dueDate) {
    const day = parseInt(card.dueDate, 10)
    if (isNaN(day) || day < 1 || day > 31) {
      errors.push('还款日必须在1-31之间')
    }
  }
  
  return {
    valid: errors.length === 0,
    errors
  }
}

/**
 * 批量验证卡片数据
 * @param {Array} cards - 卡片数据数组
 * @returns {Object} { valid: boolean, invalidCards: Array }
 */
export function validateCardDataBatch(cards) {
  if (!Array.isArray(cards)) {
    return { valid: false, invalidCards: [{ error: '输入必须是数组' }] }
  }
  
  const invalidCards = []
  
  cards.forEach((card, index) => {
    const validation = validateCardData(card)
    if (!validation.valid) {
      invalidCards.push({
        index,
        id: card.id,
        errors: validation.errors
      })
    }
  })
  
  return {
    valid: invalidCards.length === 0,
    invalidCards,
    total: cards.length,
    validCount: cards.length - invalidCards.length
  }
}

/**
 * 修复和规范化卡片数据（不抛出错误，尽力修复）
 * @param {Object} card - 卡片数据
 * @returns {Object} 修复后的卡片数据
 */
export function sanitizeCardData(card) {
  try {
    // 使用迁移函数来修复数据
    return normalizeCardTimeFields(migrateCardData(card), { fillLastModifyTime: true })
  } catch (error) {
    console.error('修复卡片数据失败:', error)
    // 返回一个包含错误信息的最小化卡片数据
    return {
      ...DEFAULT_CARD_DATA,
      id: card.id || crypto.randomUUID(),
      remark: `数据修复失败: ${error.message}`,
      lastModifyTime: nowCardTimestamp()
    }
  }
}

/**
 * 检查数据是否需要迁移
 * @param {Object} card - 卡片数据
 * @returns {boolean} 是否需要迁移
 */
export function needsMigration(card) {
  if (!card) return true
  
  // 检查是否缺少新字段
  if (card.cardCategory === undefined) return true
  if (card.isSharedLimit === undefined) return true
  if (card.billingDaySpendingToNextBill === undefined) return true
  
  // 检查有效期格式是否为旧格式
  if (card.valid && !/^\d{2}\/\d{2}$/.test(card.valid)) return true
  
  // 检查账单日/还款日是否为Number类型
  if (typeof card.accountBillDate === 'number') return true
  if (typeof card.dueDate === 'number') return true

  if (!card.lastModifyTime) return true
  if (CARD_TIMESTAMP_FIELDS.some(field => card[field] && typeof card[field] !== 'number')) return true
  
  return false
}

/**
 * 自动迁移本地存储的数据
 * @param {Array} cards - 卡片数据数组
 * @param {boolean} trackChanges - 是否追踪详细变化
 * @returns {Object} { migrated: boolean, data: Array, summary: Object, details: Array }
 */
export function autoMigrateLocalData(cards, trackChanges = false) {
  if (!Array.isArray(cards) || cards.length === 0) {
    return { 
      migrated: false, 
      data: [], 
      summary: { total: 0, migrated: 0 },
      details: []
    }
  }
  
  // 检查是否需要迁移
  const needsMigrationCount = cards.filter(needsMigration).length
  
  if (needsMigrationCount === 0) {
    return { 
      migrated: false, 
      data: cards, 
      summary: { 
        total: cards.length, 
        migrated: 0,
        message: '数据已经是最新状态，无需处理'
      },
      details: []
    }
  }
  
  // 执行迁移（追踪变化用于详细报告）
  const result = migrateCardDataBatch(cards, true)
  
  if (!result.success) {
    console.error('迁移过程中出现错误:', result.errors)
  }
  
  return {
    migrated: true,
    data: result.data,
    summary: {
      total: cards.length,
      migrated: needsMigrationCount,
      success: result.data.length,
      errors: result.errors.length,
      errorDetails: result.errors
    },
    details: result.details || []
  }
}

/**
 * 导出所有迁移和验证函数
 */
export default {
  migrateCardData,
  migrateCardDataBatch,
  validateCardData,
  validateCardDataBatch,
  sanitizeCardData,
  needsMigration,
  autoMigrateLocalData,
  convertValidToMMYY
}
