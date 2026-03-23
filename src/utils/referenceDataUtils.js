import { bankList, countryData } from '@/config/referenceData'

function normalizeText(value = '') {
  return String(value).toLowerCase().trim().replace(/[\s\-_]+/g, '')
}

export function normalizeCountryValue(value = '') {
  if (!value) return ''

  const normalized = normalizeText(value)
  const matched = countryData.find(item =>
    item.value === value ||
    item.chineseName === value ||
    normalizeText(item.englishName) === normalized ||
    normalizeText(item.value) === normalized ||
    (item.aliases || []).some(alias => normalizeText(alias) === normalized)
  )

  return matched ? matched.value : value
}

export function normalizeBankValue(value = '') {
  if (!value) return ''

  const normalized = normalizeText(value.replace(/\(.*?\)/g, ''))
  const matched = bankList.find(item =>
    item.value === value ||
    item.chineseName === value ||
    normalizeText(item.englishName) === normalized ||
    normalizeText(item.value) === normalized ||
    (item.aliases || []).some(alias => normalizeText(alias) === normalized)
  )

  return matched ? matched.value : value.replace(/\(.*?\)/g, '').trim()
}

export function isSameCountryValue(first, second) {
  return !!first && !!second && normalizeCountryValue(first) === normalizeCountryValue(second)
}

export function isSameBankValue(first, second) {
  return !!first && !!second && normalizeBankValue(first) === normalizeBankValue(second)
}
