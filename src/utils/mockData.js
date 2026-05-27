import { creditCardOptions } from '../config/creditCardOptions'

// 银行BIN列表（用于生成有效的卡号）
const bankBins = {
  '中国工商银行': ['622202', '622230', '622235', '622210', '622215'],
  '中国建设银行': ['622909', '622908', '622901', '622921', '622915'],
  '中国银行': ['622760', '622750', '622751', '622752', '622759'],
  '中国农业银行': ['622848', '622845', '622850', '622847', '622839'],
  '招商银行': ['622580', '622588', '622598', '622609', '622586'],
  '交通银行': ['622250', '622251', '622254', '622255', '622258'],
  '中信银行': ['622680', '622682', '622684', '622688', '622689'],
  '浦发银行': ['622516', '622517', '622518', '622520', '622525'],
  '广发银行': ['622555', '622556', '622557', '622558', '622559'],
  '平安银行': ['622155', '622156', '622157', '622158', '622159']
}

// 额度范围配置
const limitRanges = {
  '普卡': [1000, 50000],
  '金卡': [50000, 100000],
  '白金卡': [100000, 300000],
  '钻石卡': [300000, 1000000],
  '无限卡': [1000000, 5000000]
}

// 年费范围配置
const annualFeeRanges = {
  'CNY': [0, 500],
  'USD': [0, 100],
  'EUR': [0, 80],
  'GBP': [0, 70],
  'JPY': [0, 5000],
  'HKD': [0, 400],
  'AUD': [0, 120],
  'CAD': [0, 120],
  'CHF': [0, 90],
  'SGD': [0, 150]
}

// 生成随机数字
const randomInt = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min

// 生成随机日期
const randomDate = (start, end) => {
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()))
}

// 生成随机卡号
const generateCardNumber = (bin) => {
  let number = bin
  while (number.length < 15) {
    number += randomInt(0, 9)
  }
  
  // Luhn算法校验位
  let sum = 0
  let isEven = false
  
  for (let i = number.length - 1; i >= 0; i--) {
    let digit = parseInt(number[i])
    
    if (isEven) {
      digit *= 2
      if (digit > 9) digit -= 9
    }
    
    sum += digit
    isEven = !isEven
  }
  
  const checkDigit = (10 - (sum % 10)) % 10
  return number + checkDigit
}

// 生成随机CVV
const generateCVV = () => {
  return String(randomInt(100, 999))
}

// 获取卡片基础等级
const getBaseCardLevel = (cardLevel) => {
  const levelMap = {
    '普卡': '普卡',
    '金卡': '金卡',
    '白金卡': '白金卡',
    '钻石卡': '钻石卡',
    '御玺卡': '白金卡',
    '无限卡': '无限卡',
    '世界卡': '无限卡',
    '钛金卡': '白金卡',
    '百夫长': '无限卡'
  }
  
  for (const [key, value] of Object.entries(levelMap)) {
    if (cardLevel.includes(key)) {
      return value
    }
  }
  return '普卡'
}

// 获取币种代码
const getCurrencyCode = (currencyName) => {
  const match = currencyName.match(/\(([^)]+)\)/)
  return match ? match[1] : 'CNY'
}

// 生成单个信用卡数据
export const generateCreditCard = () => {
  const now = new Date()
  
  // 随机选择国家（使用配置中的所有国家，权重相等）
  const country = creditCardOptions.countryData[randomInt(0, creditCardOptions.countryData.length - 1)].chineseName
  
  // 随机选择银行
  const bankName = creditCardOptions.bankList[randomInt(0, creditCardOptions.bankList.length - 1)].name.split('(')[0]
  const bin = bankBins[bankName]?.[randomInt(0, 4)] || bankBins['中国工商银行'][randomInt(0, 4)]
  
  // 随机选择卡等级
  const cardLevel = creditCardOptions.cardLevel[randomInt(0, creditCardOptions.cardLevel.length - 1)].name
  const baseLevel = getBaseCardLevel(cardLevel)
  
  // 随机选择币种
  const currency = creditCardOptions.currencyList[randomInt(0, creditCardOptions.currencyList.length - 1)].name
  const currencyCode = getCurrencyCode(currency)
  
  // 生成有效期（1-5年内）- 使用MM/YY格式
  const validYears = randomInt(1, 5)
  const validDate = new Date(now.getFullYear() + validYears, randomInt(0, 11))
  const validMonth = String(validDate.getMonth() + 1).padStart(2, '0')
  const validYear = String(validDate.getFullYear()).slice(2) // 取后两位
  const valid = `${validMonth}/${validYear}` // MM/YY格式
  
  // 生成年费日期（随机分布在过去1年到未来1年之间）
  const annualFeeDate = randomDate(
    new Date(now.getFullYear() - 1, now.getMonth()),
    new Date(now.getFullYear() + 1, now.getMonth())
  )

  // 生成下次年费收取时间（基于年费日期加一年）
  const nextAnnualFeeDate = new Date(annualFeeDate)
  nextAnnualFeeDate.setFullYear(nextAnnualFeeDate.getFullYear() + 1)

  // 生成最后提额时间（随机分布在过去2年内）
  const lastTime = randomDate(
    new Date(now.getFullYear() - 2, now.getMonth()),
    now
  ).getTime()

  // 生成别名（使用银行名称、卡等级和币种）
  const alias = `${bankName}${cardLevel}(${currencyCode})`
  
  // 随机生成年费达标状态
  const isQualifiedStates = ['1', '2', '3'] // 1: 已达标, 2: 未达标, 3: 终免年费
  const isQualified = isQualifiedStates[randomInt(0, 2)]
  
  // 生成账单日和还款日（String类型）
  const accountBillDate = randomInt(1, 28).toString() // 避免使用29-31日，以处理2月份的情况
  const daysAfterBill = randomInt(10, 25) // 还款日通常在账单日后10-25天
  let dueDate = parseInt(accountBillDate) + daysAfterBill
  if (dueDate > 28) {
    dueDate = dueDate - 28 // 如果超过28号，转到下月初
  }
  dueDate = dueDate.toString()
  
  // 生成最后修改时间
  const lastModifyTime = now.getTime()
  
  return {
    id: crypto.randomUUID(), // 使用UUID
    country,
    bank: bankName,
    alias,
    cardNumber: generateCardNumber(bin),
    cvv: generateCVV(),
    valid, // MM/YY格式
    limit: randomInt(...(limitRanges[baseLevel] || limitRanges['普卡'])),
    type: currencyCode,
    annualFee: randomInt(...(annualFeeRanges[currencyCode] || annualFeeRanges['CNY'])),
    nextAnnualFeeCollectionTime: nextAnnualFeeDate.getTime(),
    lastTime,
    isQualified,
    level: cardLevel,
    accountBillDate, // String类型
    dueDate, // String类型
    // 🆕 新增字段
    isSharedLimit: Math.random() > 0.3, // 70%概率共享额度
    billingDaySpendingToNextBill: Math.random() > 0.5, // 50%概率计入下期
    lastModifyTime, // 最后修改时间
    equity: '', // 权益信息默认为空
    remark: '' // 备注信息默认为空
  }
}

// 生成多条随机信用卡数据
export const generateMockData = (count = 15) => {
  return Array.from({ length: count }, () => generateCreditCard())
}
