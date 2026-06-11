import {
  countryData as sharedCountryData,
  bankList as sharedBankList,
  cardLevelData as sharedCardLevelData,
  currencyData as sharedCurrencyData,
  qualificationStatusData as sharedQualificationStatusData,
} from '@/config/referenceData'

const mapCountryData = sharedCountryData.map(item => ({
  name: item.englishName,
  chineseName: item.value,
  value: item.value,
  aliases: item.aliases || [],
}))

const mapBankList = sharedBankList.map(item => ({
  name: item.chineseName,
  chineseName: item.value,
  englishName: item.englishName,
  value: item.value,
  aliases: item.aliases || [],
}))

const mapCardLevel = sharedCardLevelData.map(item => ({
  name: item.chineseName,
  chineseName: item.value,
  englishName: item.englishName,
  value: item.value,
  aliases: item.aliases || [],
}))

const mapCurrencyList = sharedCurrencyData.map(item => ({
  name: item.chineseName,
  chineseName: item.value,
  englishName: item.englishName,
  label: item.chineseName,
  value: item.value,
}))

const qualificationStatus = sharedQualificationStatusData.map(item => ({
  name: item.chineseName,
  value: item.value,
}))

export const creditCardOptions = {
  cardCategory: [
    { label: '信用卡', value: 'credit' },
    { label: '储蓄卡', value: 'debit' },
  ],
  countryData: mapCountryData,
  bankList: mapBankList,
  cardLevel: mapCardLevel,
  currencyList: mapCurrencyList,
  cardType: [
    {
      value: '1',
      label: '消费精彩',
      children: [
        { value: '多倍积分', label: '多倍积分' },
        { value: '消费返现', label: '消费返现' },
      ],
    },
    {
      value: '2',
      label: '美食诱惑',
      children: [
        {
          value: '餐饮饭票',
          label: '餐饮饭票',
          children: [
            { value: '吉野家', label: '吉野家' },
            { value: '肯德基', label: '肯德基' },
            { value: '麦当劳', label: '麦当劳' },
          ],
        },
        { value: '外卖优惠', label: '外卖优惠' },
      ],
    },
    { value: '3', label: '旅行无忧' },
    { value: '4', label: '健康生活' },
    { value: '5', label: '品质生活' },
    { value: '7', label: '车主生活' },
    { value: '7', label: '积分兑换' },
  ],
  tableCustomData: [
    { label: '卡类别', value: 'cardCategory', checked: true },
    { label: '国家', value: 'country', checked: true },
    { label: '银行', value: 'bank', checked: true },
    { label: '卡号', value: 'cardNumber', checked: true },
    { label: '等级', value: 'level', checked: true },
    { label: '别名', value: 'alias', checked: true },
    { label: '额度', value: 'limit', checked: true },
    { label: '币种', value: 'type', checked: true },
    { label: 'CVV', value: 'cvv', checked: true },
    { label: '有效期', value: 'valid', checked: true },
    { label: '年费', value: 'annualFee', checked: true },
    { label: '最后修改时间', value: 'lastModifyTime', checked: true },
    { label: '年费是否达标', value: 'isQualified', checked: true },
    { label: '下次年费收取时间', value: 'nextAnnualFeeCollectionTime', checked: true },
    { label: '上次提额时间', value: 'lastTime', checked: true },
    { label: '免息期', value: 'interestFreePeriod', checked: true },
    { label: '权益', value: 'equity', checked: true },
    { label: '备注', value: 'remark', checked: true },
  ],
  isQualified: qualificationStatus,
}
