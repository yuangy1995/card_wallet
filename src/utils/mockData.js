import { creditCardOptions } from '../config/creditCardOptions'
import { createNewCardData } from '../config/defaultCardData'

const COMMON_COUNTRIES = [
  '中国',
  '香港特别行政区',
  '美国',
  '英国',
  '新加坡',
  '日本',
  '德国',
  '澳大利亚'
]

const BANKS_BY_COUNTRY = {
  中国: ['工商银行', '建设银行', '农业银行', '中国银行', '招商银行', '交通银行', '中信银行', '浦发银行', '广发银行', '平安银行'],
  香港特别行政区: ['汇丰银行', '渣打银行', '恒生银行', '东亚银行', '星展银行', '众安银行', '招商永隆银行'],
  美国: ['美国银行', '摩根大通银行', '花旗银行', '汇丰银行'],
  英国: ['汇丰银行', '渣打银行', '花旗银行'],
  新加坡: ['星展银行', '华侨银行', '渣打银行', '花旗银行'],
  日本: ['中国银行', '花旗银行', '汇丰银行'],
  德国: ['德意志银行', '花旗银行', '汇丰银行'],
  澳大利亚: ['汇丰银行', '花旗银行', '渣打银行']
}

const CURRENCY_BY_COUNTRY = {
  中国: ['CNY'],
  香港特别行政区: ['HKD', 'CNY', 'USD'],
  澳门特别行政区: ['MOP', 'HKD', 'CNY'],
  台湾: ['TWD', 'USD'],
  美国: ['USD'],
  英国: ['GBP', 'USD'],
  新加坡: ['SGD', 'USD'],
  德国: ['EUR'],
  日本: ['JPY', 'USD'],
  韩国: ['KRW', 'USD'],
  澳大利亚: ['AUD', 'USD'],
  加拿大: ['CAD', 'USD'],
  法国: ['EUR'],
  意大利: ['EUR'],
  西班牙: ['EUR'],
  荷兰: ['EUR'],
  瑞士: ['CHF', 'EUR'],
  泰国: ['THB', 'USD'],
  马来西亚: ['MYR', 'USD'],
  印度尼西亚: ['IDR', 'USD'],
  菲律宾: ['PHP', 'USD'],
  越南: ['VND', 'USD'],
  印度: ['INR', 'USD'],
  新西兰: ['NZD', 'USD']
}

const CARD_ORGANIZATION_BINS = {
  unionpay: ['622202', '622230', '622848', '622580', '622680', '622555', '622155', '625908'],
  visa: ['401288', '411111', '453201', '455673', '491678'],
  mastercard: ['510510', '520082', '531234', '545454', '555555'],
  amex: ['34', '37'],
  jcb: ['352800', '356600', '358900']
}

const BANK_ORGANIZATION_BINS = {
  工商银行: { unionpay: ['622202', '622230', '622235'], visa: ['427020'], mastercard: ['530970'] },
  建设银行: { unionpay: ['622700', '622725', '625955'], visa: ['436742'], mastercard: ['532450'] },
  农业银行: { unionpay: ['622848', '622845', '625996'], visa: ['404118'], mastercard: ['535910'] },
  中国银行: { unionpay: ['622760', '622752', '625905'], visa: ['409666'], mastercard: ['518378'] },
  招商银行: { unionpay: ['622580', '622588', '625802'], visa: ['439225'], mastercard: ['518710'] },
  交通银行: { unionpay: ['622250', '622251', '625028'], visa: ['458123'], mastercard: ['521899'] },
  中信银行: { unionpay: ['622680', '622688', '625910'], visa: ['433669'], mastercard: ['518212'] },
  浦发银行: { unionpay: ['622516', '622520', '625957'], visa: ['404738'], mastercard: ['517650'] },
  广发银行: { unionpay: ['622555', '622556', '625952'], visa: ['406365'], mastercard: ['520152'] },
  平安银行: { unionpay: ['622155', '622156', '625911'], visa: ['435744'], mastercard: ['526855'] }
}

const LIMIT_RANGES = {
  classic: [3000, 50000],
  gold: [20000, 120000],
  platinum: [50000, 300000],
  premium: [150000, 800000],
  top: [500000, 3000000]
}

const CURRENCY_LIMIT_SCALE = {
  CNY: 1,
  CNH: 1,
  HKD: 1.1,
  MOP: 1.05,
  TWD: 4.4,
  USD: 0.14,
  EUR: 0.13,
  GBP: 0.11,
  SGD: 0.19,
  AUD: 0.21,
  CAD: 0.19,
  CHF: 0.12,
  JPY: 20,
  KRW: 180,
  THB: 5,
  MYR: 0.65,
  IDR: 2200,
  VND: 3500,
  PHP: 8,
  INR: 11,
  NZD: 0.23
}

const ANNUAL_FEE_RANGES = {
  CNY: [0, 3600],
  CNH: [0, 3600],
  HKD: [0, 4200],
  MOP: [0, 3800],
  TWD: [0, 15000],
  USD: [0, 650],
  EUR: [0, 600],
  GBP: [0, 520],
  SGD: [0, 800],
  AUD: [0, 900],
  CAD: [0, 850],
  CHF: [0, 550],
  JPY: [0, 90000],
  KRW: [0, 800000],
  THB: [0, 24000],
  MYR: [0, 3000],
  IDR: [0, 9000000],
  VND: [0, 15000000],
  PHP: [0, 36000],
  INR: [0, 45000],
  NZD: [0, 950]
}

const EQUITY_POOL = [
  '机场贵宾厅、延误险、境外返现',
  '餐饮优惠、生日月多倍积分',
  '酒店会籍、接送机、旅行保险',
  '线上消费返现、影音会员',
  '加油返现、洗车权益、道路救援',
  '高铁贵宾厅、积分兑换里程',
  '免货币转换费、境外免费提现'
]

const REMARK_POOL = [
  '测试数据：共享额度联动',
  '测试数据：年费提醒场景',
  '测试数据：境外消费主力卡',
  '测试数据：账单日消费计入下期',
  '测试数据：独立额度观察',
  '测试数据：卡片页展示样例'
]

const randomInt = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min
const randomPick = (items) => items[randomInt(0, items.length - 1)]
const randomBool = (probability = 0.5) => Math.random() < probability

const optionValue = (item) => item?.chineseName || item?.value || item?.name || ''

const optionByValue = (items, value) => {
  return items.find(item => optionValue(item) === value || item.value === value || item.name === value)
}

const pickFromOptions = (items, preferredValues = []) => {
  const preferred = preferredValues
    .map(value => optionByValue(items, value))
    .filter(Boolean)

  return optionValue(randomPick(preferred.length ? preferred : items))
}

const addDays = (date, days) => {
  const result = new Date(date)
  result.setDate(result.getDate() + days)
  return result
}

const randomDate = (start, end) => {
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()))
}

const roundToStep = (value, step) => Math.round(value / step) * step

const getCardOrganization = (cardLevel = '') => {
  if (cardLevel.includes('MasterCard')) return 'mastercard'
  if (cardLevel.includes('VISA')) return 'visa'
  if (cardLevel.includes('JCB')) return 'jcb'
  if (cardLevel.includes('AE')) return 'amex'
  if (cardLevel.includes('银联')) return 'unionpay'
  return randomPick(['unionpay', 'visa', 'mastercard'])
}

const getLimitRangeKey = (cardLevel = '') => {
  if (cardLevel.includes('无限') || cardLevel.includes('世界之极') || cardLevel.includes('百夫长黑金')) return 'top'
  if (cardLevel.includes('钻石') || cardLevel.includes('世界') || cardLevel.includes('御尊') || cardLevel.includes('百夫长')) return 'premium'
  if (cardLevel.includes('白金') || cardLevel.includes('御玺') || cardLevel.includes('钛金')) return 'platinum'
  if (cardLevel.includes('金卡')) return 'gold'
  return 'classic'
}

const getBin = (bankName, organization) => {
  const bankBins = BANK_ORGANIZATION_BINS[bankName]?.[organization]
  const organizationBins = CARD_ORGANIZATION_BINS[organization] || CARD_ORGANIZATION_BINS.unionpay
  return randomPick(bankBins || organizationBins)
}

const appendLuhnCheckDigit = (partialNumber) => {
  let sum = 0
  const reversedDigits = partialNumber.split('').reverse()

  reversedDigits.forEach((value, index) => {
    let digit = Number(value)
    if (index % 2 === 0) {
      digit *= 2
      if (digit > 9) digit -= 9
    }
    sum += digit
  })

  return `${partialNumber}${(10 - (sum % 10)) % 10}`
}

const generateCardNumber = (bankName, organization) => {
  const length = organization === 'amex' ? 15 : 16
  let number = getBin(bankName, organization)

  while (number.length < length - 1) {
    number += randomInt(0, 9)
  }

  return appendLuhnCheckDigit(number.slice(0, length - 1))
}

const generateCVV = (organization) => {
  const length = organization === 'amex' ? 4 : 3
  const min = Number('1'.padEnd(length, '0'))
  const max = Number('9'.repeat(length))
  return String(randomInt(min, max))
}

const generateValidDate = () => {
  const now = new Date()
  const validDate = new Date(now.getFullYear() + randomInt(1, 6), randomInt(0, 11), 1)
  const month = String(validDate.getMonth() + 1).padStart(2, '0')
  const year = String(validDate.getFullYear()).slice(2)
  return `${month}/${year}`
}

const generateBillDates = () => {
  const accountBillDate = randomInt(1, 28)
  const dueDate = ((accountBillDate + randomInt(15, 25) - 1) % 28) + 1

  return {
    accountBillDate: String(accountBillDate),
    dueDate: String(dueDate)
  }
}

const generateLimit = (cardLevel, currencyCode) => {
  const [min, max] = LIMIT_RANGES[getLimitRangeKey(cardLevel)]
  const scale = CURRENCY_LIMIT_SCALE[currencyCode] || 1
  const step = scale >= 10 ? 1000 : scale >= 1 ? 100 : 10
  return Math.max(step, roundToStep(randomInt(min, max) * scale, step))
}

const generateAnnualFee = (currencyCode, isQualified) => {
  if (isQualified === '3') return 0
  if (randomBool(0.22)) return 0

  const [min, max] = ANNUAL_FEE_RANGES[currencyCode] || ANNUAL_FEE_RANGES.CNY
  const step = max >= 10000 ? 1000 : max >= 1000 ? 100 : 10
  return roundToStep(randomInt(Math.max(min, step), max), step)
}

const generateAnnualFeeDate = (isQualified) => {
  if (isQualified === '3') return null

  const now = new Date()
  const offsetDays = isQualified === '2'
    ? randomInt(-20, 75)
    : randomInt(90, 420)

  return addDays(now, offsetDays).setHours(0, 0, 0, 0)
}

const generateQualificationStatus = () => {
  const roll = Math.random()
  if (roll < 0.45) return '1'
  if (roll < 0.78) return '2'
  return '3'
}

const generateLastTime = () => {
  const now = new Date()
  return randomDate(
    new Date(now.getFullYear() - 3, now.getMonth(), now.getDate()),
    now
  ).getTime()
}

const generateLastModifyTime = () => {
  const now = new Date()
  return randomDate(addDays(now, -90), now).getTime()
}

const generateSharedPoolKey = (card) => {
  return `${card.country}-${card.bank}-${card.type}`
}

const applySharedLimitPool = (card, sharedPools) => {
  if (!card.isSharedLimit) return card

  const poolKey = generateSharedPoolKey(card)
  if (!sharedPools.has(poolKey)) {
    sharedPools.set(poolKey, {
      limit: card.limit,
      lastTime: card.lastTime
    })
  }

  const pool = sharedPools.get(poolKey)
  return {
    ...card,
    limit: pool.limit,
    lastTime: pool.lastTime
  }
}

const createScenarioSeeds = (count) => {
  const seedCount = Math.max(4, Math.min(12, Math.ceil(count / 4)))

  return Array.from({ length: seedCount }, () => {
    const country = pickFromOptions(
      creditCardOptions.countryData,
      randomBool(0.8) ? COMMON_COUNTRIES : []
    )
    const bank = pickFromOptions(
      creditCardOptions.bankList,
      BANKS_BY_COUNTRY[country] || []
    )
    const type = pickFromOptions(
      creditCardOptions.currencyList,
      CURRENCY_BY_COUNTRY[country] || ['CNY', 'USD', 'HKD', 'EUR']
    )

    return { country, bank, type }
  })
}

// 生成单个信用卡数据，字段结构对齐 DEFAULT_CARD_DATA。
export const generateCreditCard = ({ sharedPools = new Map(), scenario = null, index = 0 } = {}) => {
  const country = scenario?.country || pickFromOptions(
    creditCardOptions.countryData,
    randomBool(0.75) ? COMMON_COUNTRIES : []
  )
  const bank = scenario?.bank || pickFromOptions(
    creditCardOptions.bankList,
    BANKS_BY_COUNTRY[country] || []
  )
  const type = scenario?.type || pickFromOptions(
    creditCardOptions.currencyList,
    CURRENCY_BY_COUNTRY[country] || ['CNY', 'USD', 'HKD', 'EUR']
  )
  const level = pickFromOptions(creditCardOptions.cardLevel)
  const organization = getCardOrganization(level)
  const isQualified = generateQualificationStatus()
  const billDates = generateBillDates()
  const isSharedLimit = randomBool(0.7)
  const baseCard = createNewCardData({
    country,
    bank,
    alias: `${bank}${level}-${type}-${String(index + 1).padStart(2, '0')}`,
    level,
    cardNumber: generateCardNumber(bank, organization),
    cvv: generateCVV(organization),
    valid: generateValidDate(),
    limit: generateLimit(level, type),
    type,
    isSharedLimit,
    accountBillDate: billDates.accountBillDate,
    dueDate: billDates.dueDate,
    billingDaySpendingToNextBill: randomBool(0.65),
    annualFee: generateAnnualFee(type, isQualified),
    isQualified,
    nextAnnualFeeCollectionTime: generateAnnualFeeDate(isQualified),
    lastTime: generateLastTime(),
    lastModifyTime: generateLastModifyTime(),
    equity: randomBool(0.72) ? randomPick(EQUITY_POOL) : '',
    remark: randomBool(0.65) ? randomPick(REMARK_POOL) : ''
  })

  return applySharedLimitPool(baseCard, sharedPools)
}

// 生成多条随机信用卡数据，保留共享额度分组，便于表格合并列和统计模块一起验证。
export const generateMockData = (count = 50) => {
  const sharedPools = new Map()
  const scenarios = createScenarioSeeds(count)

  return Array.from({ length: count }, (_, index) => {
    const scenario = randomBool(0.82) ? randomPick(scenarios) : null
    return generateCreditCard({ sharedPools, scenario, index })
  })
}
