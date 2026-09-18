import entries from '../assets/wallet-brand-catalog.json'

// Display metadata only. No card number is inspected, persisted or sent to another service.
const traditional = '銀國業興華農發門灣臺廣東滙豐慶陽儲郵長蘇龍寧漢廈恆華僑滬浙齊魯晉遼瀋陝鄭濰烏義壽營濟贛贊聯眾雲貴黔陸'
const simplified = '银国业兴华农发门湾台广东汇丰庆阳储邮长苏龙宁汉厦恒华侨沪浙齐鲁晋辽沈陕郑潍乌义寿营济赣赞联众云贵黔陆'
const translations = new Map([...traditional].map((char, index) => [char, [...simplified][index]]))
export const normalizeIssuer = value => [...String(value || '').normalize('NFKD').toLowerCase().replace(/\p{M}/gu, '').replace(/[^\p{L}\p{N}]/gu, '')]
  .map(char => translations.get(char) || char).join('')
  .replace(/(?:股份有限公司|有限责任公司|有限公司|corporation|limited|ltd|inc)$/, '')

export function createLogoMatcher(catalog) {
  const index = catalog.flatMap(issuer => [...new Set([...issuer.aliases, issuer.name].map(normalizeIssuer))]
    .filter(Boolean).map(value => ({ value, issuer })))
  const exact = new Map()
  for (const alias of index) {
    if (!exact.has(alias.value)) exact.set(alias.value, [])
    exact.get(alias.value).push(alias)
  }
  const cache = new Map()
  return (name = '', country = '') => {
    const key = JSON.stringify([name, country])
    if (cache.has(key)) {
      const result = cache.get(key)
      cache.delete(key); cache.set(key, result)
      return result
    }
    const normalized = normalizeIssuer(name)
    if (!normalized) return null
    const malaysian = ['malaysia', 'my', '马来西亚'].includes(normalizeIssuer(country)) || normalized.includes('马来西亚')
    const restrictRHB = malaysian && normalized.includes('兴业银行')
    const precise = new Map((restrictRHB ? [] : exact.get(normalized) || []).map(({ issuer }) => [issuer.id, issuer]))
    let result = null
    if (precise.size === 1) result = [...precise.values()][0]
    else {
      const words = new Set(String(name).toLowerCase().match(/[a-z0-9]+/g) || [])
      let score = -1
      const best = new Map()
      for (const { value, issuer } of index) {
        if (restrictRHB && !issuer.id.includes('rhb')) continue
        const nonLatin = /[^\x00-\x7F]/.test(value)
        const matches = value === normalized || words.has(value) ||
          (nonLatin && [...value].length >= 3 && normalized.includes(value)) ||
          (!nonLatin && value.length >= 8 && (normalized.startsWith(value) || normalized.endsWith(value)))
        if (!matches) continue
        const weight = [...value].length + (value === normalized ? 10000 : 0)
        if (weight > score) { score = weight; best.clear() }
        if (weight === score) best.set(issuer.id, issuer)
      }
      if (best.size === 1) result = [...best.values()][0]
    }
    cache.set(key, result)
    if (cache.size > 256) cache.delete(cache.keys().next().value)
    return result
  }
}
export const matchIssuer = createLogoMatcher(entries)
