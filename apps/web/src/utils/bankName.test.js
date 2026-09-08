import { describe, expect, it } from 'vitest'
import {
  bankNamesReferToSameBank,
  normalizeBankNameForMatch
} from './bankName'

describe('bank name utilities', () => {
  it('matches legacy bank names that include an English suffix in parentheses', () => {
    expect(normalizeBankNameForMatch('东亚银行(Bank of East Asia)')).toBe('东亚银行')
    expect(normalizeBankNameForMatch('东亚银行（Bank of East Asia）')).toBe('东亚银行')
    expect(bankNamesReferToSameBank('东亚银行(Bank of East Asia)', '东亚银行')).toBe(true)
  })
})
