import { describe, expect, it } from 'vitest'
import { getAppName } from './appName'

describe('getAppName', () => {
  it.each(['zh', 'zh-CN', 'zh-Hans', 'zh-TW'])('uses the Chinese name for %s', (language) => {
    expect(getAppName(language)).toBe('卡包')
  })

  it.each(['en', 'en-US', 'ja-JP', null])('uses the English name for %s', (language) => {
    expect(getAppName(language)).toBe('Card Wallet')
  })
})
