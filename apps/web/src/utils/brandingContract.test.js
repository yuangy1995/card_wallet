// @vitest-environment happy-dom
import { describe, it, expect } from 'vitest'
import { createApp, nextTick, ref } from 'vue'
import fixtures from '../../../../contracts/card-wallet/fixtures/branding.json'
import { createLogoMatcher, matchIssuer, normalizeIssuer } from './walletLogoCatalog'
import { cardOrganization } from './cardBrand'
import WalletBrandMark from '../components/common/WalletBrandMark.vue'

describe('shared four-platform branding contract', () => {
  it.each(fixtures.networks)('network $number / $level', item => {
    expect(cardOrganization({ cardNumber: item.number, level: item.level })).toBe(item.expected === 'unknown' ? 'other' : item.expected)
  })
  it.each(fixtures.issuers)('issuer $name / $country', item => {
    expect(matchIssuer(item.name, item.country)?.id || null).toBe(item.expected)
  })
  it('uses identical normalization and does not guess conflicting issuers', () => {
    expect(normalizeIssuer('ＳＯＣＩÉＴÉ')).toBe('societe')
    const match = createLogoMatcher([
      { id: 'a', name: 'Alpha Bank', aliases: ['Same Bank'], resource: 'a' },
      { id: 'b', name: 'Beta Bank', aliases: ['Same Bank'], resource: 'b' }
    ])
    expect(match('Same Bank')).toBeNull()
    expect(matchIssuer('Citizens Bank')?.id).not.toBe('citibank')
    for (let i = 0; i < 300; i++) expect(matchIssuer(`不存在的测试银行-${i}`)).toBeNull()
    expect(matchIssuer('HSBC')?.id).toBe('hsbc')
  })
  it('uses a same-origin image and falls back to a generic card after an image error', async () => {
    const host = document.createElement('div'); document.body.append(host)
    const app = createApp(WalletBrandMark, { bank: 'HSBC', onCard: true })
    app.provide('theme', { isDarkMode: ref(false) })
    try {
      app.mount(host); await nextTick()
      const image = host.querySelector('img')
      expect(image.getAttribute('src')).toContain('wallet-brands/wallet_issuer_hsbc_card.webp')
      expect(image.getAttribute('loading')).toBe('lazy')
      image.dispatchEvent(new Event('error')); await nextTick()
      expect(host.querySelector('img')).toBeNull()
      expect(host.querySelector('svg[aria-label="银行卡"]')).not.toBeNull()
      expect(host.textContent).toBe('')
    } finally { app.unmount(); host.remove() }
  })
  it('switches issuer variants with the shared theme, preserving image proportions', async () => {
    const host = document.createElement('div'); document.body.append(host)
    const dark = ref(false)
    const app = createApp(WalletBrandMark, { bank: 'HSBC' })
    app.provide('theme', { isDarkMode: dark })
    try {
      app.mount(host); await nextTick()
      expect(host.querySelector('img').getAttribute('src')).toContain('wallet_issuer_hsbc.webp')
      dark.value = true; await nextTick()
      expect(host.querySelector('img').getAttribute('src')).toContain('wallet_issuer_hsbc_card.webp')
    } finally { app.unmount(); host.remove() }
  })
})
