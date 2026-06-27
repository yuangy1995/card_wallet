const BANK_PARENTHESES_PATTERN = /\s*[（(][^（）()]*[）)]\s*/g

export const displayBankName = (value = '') => String(value ?? '').trim()

export const normalizeBankNameForMatch = (value = '') => displayBankName(value)
  .replace(BANK_PARENTHESES_PATTERN, '')
  .replace(/\s+/g, '')
  .trim()

export const bankNamesReferToSameBank = (left, right) => {
  const leftDisplay = displayBankName(left)
  const rightDisplay = displayBankName(right)
  if (!leftDisplay || !rightDisplay) return false
  if (leftDisplay === rightDisplay) return true

  const leftKey = normalizeBankNameForMatch(leftDisplay)
  const rightKey = normalizeBankNameForMatch(rightDisplay)
  return Boolean(leftKey && rightKey && leftKey === rightKey)
}


