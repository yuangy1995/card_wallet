import { nowCardTimestamp } from '@/utils/cardTimestamp'

/**
 * 信用卡数据默认值配置
 * Web端和移动端都应使用此配置确保一致性
 */

/**
 * 默认卡片数据结构
 * 所有字段都必须在这里定义，确保数据结构完整
 */
export const DEFAULT_CARD_DATA = {
  // 基本信息
  country: '',
  bank: '',
  alias: '',
  level: '',
  
  // 卡片信息
  cardNumber: '',
  cvv: '',
  valid: '',  // MM/YY 格式
  
  // 额度信息
  limit: null,
  type: '',
  isSharedLimit: true,  // 默认共享额度
  
  // 账单信息
  accountBillDate: '',  // String类型，1-31
  dueDate: '',  // String类型，1-31
  billingDaySpendingToNextBill: true,  // 默认计入下期账单
  
  // 年费信息
  annualFee: null,
  isQualified: '',
  nextAnnualFeeCollectionTime: null,
  
  // 时间追踪
  lastTime: null,
  lastModifyTime: null,
  
  // 附加信息
  equity: '',
  remark: '',
  cardImages: []
}

/**
 * 必填字段列表
 */
export const REQUIRED_FIELDS = [
  'id',
  'country',
  'bank',
  'cardNumber',
  'valid',
  'isSharedLimit',
  'billingDaySpendingToNextBill'
]

/**
 * 字段类型定义
 */
export const FIELD_TYPES = {
  id: 'string',
  country: 'string',
  bank: 'string',
  alias: 'string',
  cardNumber: 'string',
  cvv: 'string',
  valid: 'string',  // MM/YY 格式
  level: 'string',
  limit: 'number',
  type: 'string',
  isSharedLimit: 'boolean',
  accountBillDate: 'string',  // 统一为String
  dueDate: 'string',  // 统一为String
  billingDaySpendingToNextBill: 'boolean',
  annualFee: 'number',
  isQualified: 'string',
  nextAnnualFeeCollectionTime: 'number',
  lastTime: 'number',
  lastModifyTime: 'number',
  equity: 'string',
  remark: 'string',
  cardImages: 'array'
}

/**
 * 创建新卡片数据（自动生成ID和时间戳）
 * @param {Object} partialData - 部分数据
 * @returns {Object} 完整的卡片数据
 */
export function createNewCardData(partialData = {}) {
  return {
    ...DEFAULT_CARD_DATA,
    id: crypto.randomUUID(),
    lastModifyTime: nowCardTimestamp(),
    ...partialData
  }
}

/**
 * 获取所有字段名列表
 * @returns {string[]} 字段名数组
 */
export function getAllFieldNames() {
  return Object.keys(DEFAULT_CARD_DATA).concat(['id'])
}
