/**
 * 数据迁移测试工具
 * 用于测试和验证数据迁移功能
 */

import { 
  migrateCardData, 
  migrateCardDataBatch, 
  validateCardData,
  validateCardDataBatch,
  needsMigration,
  autoMigrateLocalData,
  convertValidToMMYY
} from './cardDataMigration'

/**
 * 测试用例：老数据格式
 */
const OLD_DATA_SAMPLES = [
  // 老格式1：有效期为 YYYY-MM-DD，账单日为Number
  {
    id: '123',
    country: '中国',
    bank: '招商银行',
    cardNumber: '6225880123456789',
    valid: '2028-12-01',  // 老格式
    limit: 50000,
    type: 'CNY',
    annualFee: 0,
    isQualified: '2',
    accountBillDate: 5,  // Number类型
    dueDate: 25,  // Number类型
    // 缺少 isSharedLimit 和 billingDaySpendingToNextBill
  },
  
  // 老格式2：有效期为 YYYY-MM
  {
    id: '456',
    country: '美国',
    bank: 'Chase Bank',
    cardNumber: '4512340000000008',
    valid: '2030-06',  // 老格式
    limit: 10000,
    type: 'USD',
    annualFee: 95,
    isQualified: '1',
    accountBillDate: '15',  // 已经是String
    dueDate: '5',  // 已经是String
    // 缺少新字段
  },
  
  // 混合格式：部分字段正确
  {
    id: '789',
    country: '中国',
    bank: '工商银行',
    cardNumber: '6222021234567890',
    valid: '03/29',  // 已经是新格式
    limit: 80000,
    type: 'CNY',
    annualFee: 200,
    isQualified: '1',
    accountBillDate: 10,  // Number类型
    dueDate: 30,  // Number类型
    isSharedLimit: true,  // 已有此字段
    // 只缺少 billingDaySpendingToNextBill
  },
  
  // 完全新格式
  {
    id: 'abc-def-123',
    country: '中国',
    bank: '建设银行',
    cardNumber: '6227000012345678',
    valid: '12/26',  // 新格式
    limit: 30000,
    type: 'CNY',
    annualFee: 0,
    isQualified: '3',
    accountBillDate: '20',  // String类型
    dueDate: '10',  // String类型
    isSharedLimit: true,
    billingDaySpendingToNextBill: true,
    equity: '机场贵宾厅',
    remark: '主力卡'
  }
]

/**
 * 运行所有测试
 */
export function runMigrationTests() {
  console.group('🧪 数据迁移测试开始')
  
  try {
    testConvertValidFormat()
    testNeedsMigration()
    testSingleCardMigration()
    testBatchMigration()
    testValidation()
    testAutoMigration()
    
    console.log('✅ 所有测试通过！')
  } catch (error) {
    console.error('❌ 测试失败:', error)
  } finally {
    console.groupEnd()
  }
}

/**
 * 测试1：有效期格式转换
 */
function testConvertValidFormat() {
  console.group('测试1：有效期格式转换')
  
  const testCases = [
    { input: '2028-12-01', expected: '12/28' },
    { input: '2030-06', expected: '06/30' },
    { input: '03/29', expected: '03/29' },  // 已经是正确格式
    { input: '', expected: '' },  // 空值
  ]
  
  testCases.forEach(({ input, expected }) => {
    const result = convertValidToMMYY(input)
    console.assert(
      result === expected, 
      `转换 "${input}" 失败: 期望 "${expected}", 实际 "${result}"`
    )
    console.log(`✓ ${input} -> ${result}`)
  })
  
  console.groupEnd()
}

/**
 * 测试2：检测是否需要迁移
 */
function testNeedsMigration() {
  console.group('测试2：检测是否需要迁移')
  
  const results = OLD_DATA_SAMPLES.map((sample, index) => {
    const needs = needsMigration(sample)
    console.log(`样本${index + 1}: ${needs ? '需要迁移 ⚠️' : '无需迁移 ✓'}`)
    return needs
  })
  
  // 前3个需要迁移，第4个不需要
  console.assert(results[0] === true, '样本1应该需要迁移')
  console.assert(results[1] === true, '样本2应该需要迁移')
  console.assert(results[2] === true, '样本3应该需要迁移')
  console.assert(results[3] === false, '样本4不应该需要迁移')
  
  console.groupEnd()
}

/**
 * 测试3：单条数据迁移
 */
function testSingleCardMigration() {
  console.group('测试3：单条数据迁移')
  
  const oldCard = OLD_DATA_SAMPLES[0]
  const migratedCard = migrateCardData(oldCard)
  
  console.log('原始数据:', oldCard)
  console.log('迁移后数据:', migratedCard)
  
  // 验证关键字段
  console.assert(migratedCard.valid === '12/28', '有效期应转换为 MM/YY 格式')
  console.assert(typeof migratedCard.accountBillDate === 'string', '账单日应为String类型')
  console.assert(typeof migratedCard.dueDate === 'string', '还款日应为String类型')
  console.assert(typeof migratedCard.isSharedLimit === 'boolean', 'isSharedLimit应为Boolean')
  console.assert(typeof migratedCard.billingDaySpendingToNextBill === 'boolean', 'billingDaySpendingToNextBill应为Boolean')
  console.assert(migratedCard.equity === '', 'equity应有默认值')
  console.assert(migratedCard.remark === '', 'remark应有默认值')
  
  console.log('✓ 单条迁移测试通过')
  console.groupEnd()
}

/**
 * 测试4：批量迁移
 */
function testBatchMigration() {
  console.group('测试4：批量迁移')
  
  const result = migrateCardDataBatch(OLD_DATA_SAMPLES)
  
  console.log(`总数: ${OLD_DATA_SAMPLES.length}`)
  console.log(`成功: ${result.data.length}`)
  console.log(`错误: ${result.errors.length}`)
  console.log(`状态: ${result.success ? '✓ 成功' : '✗ 失败'}`)
  
  if (result.errors.length > 0) {
    console.error('错误详情:', result.errors)
  }
  
  console.assert(result.data.length === OLD_DATA_SAMPLES.length, '所有数据都应该成功迁移')
  console.assert(result.success === true, '批量迁移应该成功')
  
  console.groupEnd()
}

/**
 * 测试5：数据验证
 */
function testValidation() {
  console.group('测试5：数据验证')
  
  // 先迁移数据
  const result = migrateCardDataBatch(OLD_DATA_SAMPLES)
  
  // 验证迁移后的数据
  const validation = validateCardDataBatch(result.data)
  
  console.log(`验证结果: ${validation.valid ? '✓ 全部通过' : '✗ 存在问题'}`)
  console.log(`总数: ${validation.total}`)
  console.log(`有效: ${validation.validCount}`)
  console.log(`无效: ${validation.invalidCards.length}`)
  
  if (validation.invalidCards.length > 0) {
    console.error('无效数据:', validation.invalidCards)
  }
  
  console.assert(validation.valid === true, '迁移后的数据应该全部通过验证')
  
  console.groupEnd()
}

/**
 * 测试6：自动迁移
 */
function testAutoMigration() {
  console.group('测试6：自动迁移')
  
  const migrationResult = autoMigrateLocalData(OLD_DATA_SAMPLES)
  
  console.log('迁移摘要:', migrationResult.summary)
  console.log(`是否执行迁移: ${migrationResult.migrated ? '是' : '否'}`)
  
  if (migrationResult.migrated) {
    const summary = migrationResult.summary
    console.log(`- 总数: ${summary.total}`)
    console.log(`- 需要迁移: ${summary.migrated}`)
    console.log(`- 成功迁移: ${summary.success}`)
    console.log(`- 错误数: ${summary.errors}`)
    
    console.assert(summary.success === summary.total, '应该全部迁移成功')
  }
  
  // 测试已经是新格式的数据
  const newFormatData = [OLD_DATA_SAMPLES[3]]  // 第4个样本已经是新格式
  const noMigrationResult = autoMigrateLocalData(newFormatData)
  
  console.log('\n测试新格式数据:', noMigrationResult.summary)
  console.assert(noMigrationResult.migrated === false, '新格式数据应该无需迁移')
  
  console.groupEnd()
}

/**
 * 生成测试报告
 */
export function generateMigrationReport(cards) {
  console.group('📊 数据迁移报告')
  
  const needsMigrationCount = cards.filter(needsMigration).length
  const totalCount = cards.length
  
  console.log(`总卡片数: ${totalCount}`)
  console.log(`需要迁移: ${needsMigrationCount}`)
  console.log(`已是新格式: ${totalCount - needsMigrationCount}`)
  console.log(`迁移比例: ${((needsMigrationCount / totalCount) * 100).toFixed(2)}%`)
  
  // 分析需要迁移的原因
  const reasons = {
    missingIsSharedLimit: 0,
    missingBillingDay: 0,
    wrongValidFormat: 0,
    wrongDateType: 0
  }
  
  cards.forEach(card => {
    if (card.isSharedLimit === undefined) reasons.missingIsSharedLimit++
    if (card.billingDaySpendingToNextBill === undefined) reasons.missingBillingDay++
    if (card.valid && !/^\d{2}\/\d{2}$/.test(card.valid)) reasons.wrongValidFormat++
    if (typeof card.accountBillDate === 'number' || typeof card.dueDate === 'number') reasons.wrongDateType++
  })
  
  console.log('\n迁移原因统计:')
  console.log(`- 缺少 isSharedLimit: ${reasons.missingIsSharedLimit}`)
  console.log(`- 缺少 billingDaySpendingToNextBill: ${reasons.missingBillingDay}`)
  console.log(`- 有效期格式错误: ${reasons.wrongValidFormat}`)
  console.log(`- 日期类型错误: ${reasons.wrongDateType}`)
  
  console.groupEnd()
  
  return {
    totalCount,
    needsMigrationCount,
    reasons
  }
}

export default {
  runMigrationTests,
  generateMigrationReport
}
