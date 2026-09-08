export const AnnualFeeReminderKind = {
  UNQUALIFIED: 'unqualified',
  WARNING: 'warning',
  OVERDUE: 'overdue'
}

export const CardExpiryStatus = {
  EXPIRED: 'expired',
  SOON_EXPIRING: 'soonExpiring',
  NORMAL: 'normal'
}

const DAY_MS = 24 * 60 * 60 * 1000
const BILL_WARNING_DAYS = 3
const REPAYMENT_WARNING_DAYS = 7

export const normalizeCardCategory = (card) => card?.cardCategory === 'debit' ? 'debit' : 'credit'

export const isCreditCard = (card) => normalizeCardCategory(card) === 'credit'

const getDayNumber = (value) => {
  const day = Number.parseInt(value, 10)
  return Number.isInteger(day) && day >= 1 && day <= 31 ? day : null
}

const getMonthDayDate = (day, baseDate, monthOffset = 0) => {
  const year = baseDate.getFullYear()
  const month = baseDate.getMonth() + monthOffset
  const lastDay = new Date(year, month + 1, 0).getDate()
  return new Date(year, month, Math.min(day, lastDay))
}

const daysUntil = (targetDate, now = new Date()) => {
  const current = new Date(now)
  current.setHours(0, 0, 0, 0)
  const target = new Date(targetDate)
  target.setHours(0, 0, 0, 0)
  return Math.ceil((target - current) / DAY_MS)
}

const getNextBillDate = (accountBillDate, now = new Date()) => {
  const billDay = getDayNumber(accountBillDate)
  if (!billDay) return null
  const current = getMonthDayDate(billDay, now, 0)
  return daysUntil(current, now) >= 0 ? current : getMonthDayDate(billDay, now, 1)
}

const getDueDateForBillMonth = (accountBillDate, dueDate, now = new Date(), monthOffset = 0) => {
  const billDay = getDayNumber(accountBillDate)
  const dueDay = getDayNumber(dueDate)
  if (!billDay || !dueDay) return null
  const dueMonthOffset = monthOffset + (dueDay < billDay ? 1 : 0)
  return getMonthDayDate(dueDay, now, dueMonthOffset)
}

const getNextDueDate = (accountBillDate, dueDate, now = new Date()) => {
  const currentDueDate = getDueDateForBillMonth(accountBillDate, dueDate, now, 0)
  if (!currentDueDate) return null
  return daysUntil(currentDueDate, now) >= 0
    ? currentDueDate
    : getDueDateForBillMonth(accountBillDate, dueDate, now, 1)
}

export const getAnnualFeeRemainingDays = (nextAnnualFeeCollectionTime, now = new Date()) => {
  if (!nextAnnualFeeCollectionTime) return null
  const targetDate = new Date(nextAnnualFeeCollectionTime)
  if (Number.isNaN(targetDate.getTime())) return null
  return Math.ceil((targetDate - now) / DAY_MS)
}

export const getAnnualFeeDetection = (card, warningDays = 60, now = new Date()) => {
  if (!isCreditCard(card) || card?.isQualified === '3') return null
  const diffDays = getAnnualFeeRemainingDays(card?.nextAnnualFeeCollectionTime, now)
  if (diffDays === null) return null

  if (card?.isQualified === '2' && diffDays <= warningDays && diffDays > 0) {
    return { kind: AnnualFeeReminderKind.UNQUALIFIED, days: diffDays, diffDays }
  }

  if (diffDays <= warningDays && diffDays > 0 && card?.isQualified !== '2') {
    return { kind: AnnualFeeReminderKind.WARNING, days: diffDays, diffDays }
  }

  if (diffDays <= 0 && diffDays > -warningDays) {
    return { kind: AnnualFeeReminderKind.OVERDUE, days: Math.abs(diffDays), diffDays }
  }

  return null
}

export const getAnnualFeeReminderGroups = (cards, warningDays = 60, now = new Date()) => {
  const groups = {
    unqualified: [],
    warning: [],
    overdue: []
  }

  cards.forEach(card => {
    const result = getAnnualFeeDetection(card, warningDays, now)
    if (!result) return
    groups[result.kind].push({ ...card, reminder: result, diffDays: result.diffDays })
  })

  Object.keys(groups).forEach(kind => {
    groups[kind].sort((a, b) => (a.reminder?.diffDays ?? 0) - (b.reminder?.diffDays ?? 0))
  })

  return groups
}

const parseExpiryDate = (valid) => {
  if (!valid) return null
  const trimmed = String(valid).trim()
  if (!trimmed) return null

  let month
  let year

  const mmYyMatch = trimmed.match(/^(\d{1,2})\/(\d{2}|\d{4})$/)
  if (mmYyMatch) {
    month = Number(mmYyMatch[1])
    year = Number(mmYyMatch[2])
    year = year < 100 ? 2000 + year : year
  } else {
    const date = new Date(trimmed)
    if (Number.isNaN(date.getTime())) return null
    month = date.getMonth() + 1
    year = date.getFullYear()
  }

  if (!Number.isInteger(month) || !Number.isInteger(year) || month < 1 || month > 12) {
    return null
  }

  return new Date(year, month - 1, 1)
}

export const getCardExpiryStatus = (valid, now = new Date(), warningMonths = 6) => {
  const expiryDate = parseExpiryDate(valid)
  if (!expiryDate) return null

  const sixMonthsLater = new Date(now)
  sixMonthsLater.setMonth(sixMonthsLater.getMonth() + warningMonths)

  if (expiryDate < now) return CardExpiryStatus.EXPIRED
  if (expiryDate < sixMonthsLater) return CardExpiryStatus.SOON_EXPIRING
  return CardExpiryStatus.NORMAL
}

export const getCardExpiryStats = (cards, now = new Date(), warningMonths = 6) => {
  return cards.reduce((stats, card) => {
    const status = getCardExpiryStatus(card?.valid, now, warningMonths)
    if (status === CardExpiryStatus.EXPIRED) stats.expiredCards++
    else if (status === CardExpiryStatus.SOON_EXPIRING) stats.soonExpiring++
    else if (status === CardExpiryStatus.NORMAL) stats.normalCards++
    return stats
  }, { expiredCards: 0, soonExpiring: 0, normalCards: 0 })
}

export const getCardExpiryReminderCards = (cards, now = new Date(), warningMonths = 6) => {
  return cards
    .map(card => {
      const status = getCardExpiryStatus(card?.valid, now, warningMonths)
      return status === CardExpiryStatus.EXPIRED || status === CardExpiryStatus.SOON_EXPIRING
        ? { ...card, expiryStatus: status }
        : null
    })
    .filter(Boolean)
    .sort((a, b) => {
      const statusWeight = {
        [CardExpiryStatus.EXPIRED]: 0,
        [CardExpiryStatus.SOON_EXPIRING]: 1
      }
      const statusDiff = statusWeight[a.expiryStatus] - statusWeight[b.expiryStatus]
      if (statusDiff !== 0) return statusDiff
      return String(a.bank || '').localeCompare(String(b.bank || ''))
    })
}

export const getBillingCycleDetection = (card, now = new Date(), options = {}) => {
  if (!isCreditCard(card)) return []
  const billWarningDays = options.billWarningDays ?? BILL_WARNING_DAYS
  const repaymentWarningDays = options.repaymentWarningDays ?? REPAYMENT_WARNING_DAYS
  const reminders = []

  const billDate = getNextBillDate(card?.accountBillDate, now)
  if (billDate) {
    const days = daysUntil(billDate, now)
    if (days >= 0 && days <= billWarningDays) {
      reminders.push({
        kind: 'bill',
        days,
        date: billDate,
        title: days === 0 ? '今天是账单日' : `${days} 天后账单日`
      })
    }
  }

  const dueDate = getNextDueDate(card?.accountBillDate, card?.dueDate, now)
  if (dueDate) {
    const days = daysUntil(dueDate, now)
    if (days >= 0 && days <= repaymentWarningDays) {
      reminders.push({
        kind: 'repayment',
        days,
        date: dueDate,
        title: days === 0 ? '今天是还款日' : `${days} 天后还款日`
      })
    }
  }

  return reminders
}

export const getBillingCycleReminderGroups = (cards, now = new Date(), options = {}) => {
  const groups = { bill: [], repayment: [] }
  cards.forEach(card => {
    getBillingCycleDetection(card, now, options).forEach(reminder => {
      groups[reminder.kind].push({ ...card, reminder })
    })
  })
  Object.keys(groups).forEach(kind => {
    groups[kind].sort((a, b) => a.reminder.days - b.reminder.days)
  })
  return groups
}

export const getAllCardReminderSummary = (cards, now = new Date()) => {
  const annual = getAnnualFeeReminderGroups(cards, 60, now)
  const expiry = getCardExpiryReminderCards(cards, now)
  const billing = getBillingCycleReminderGroups(cards, now)
  return {
    annualCount: annual.unqualified.length + annual.warning.length + annual.overdue.length,
    expiryCount: expiry.length,
    billCount: billing.bill.length,
    repaymentCount: billing.repayment.length,
    totalCount: annual.unqualified.length + annual.warning.length + annual.overdue.length +
      expiry.length + billing.bill.length + billing.repayment.length
  }
}

const issue = (severity, title, description, card = null) => ({
  severity,
  title,
  description,
  cardId: card?.id,
  cardName: card ? `${card.bank || '未知银行'} - ${card.alias || '未命名卡片'}` : ''
})

export const analyzeCardDataIssues = (cards) => {
  const issues = []
  const numberGroups = new Map()

  cards.forEach(card => {
    const cardNumber = String(card.cardNumber || '').replace(/\D/g, '')
    if (!cardNumber) {
      issues.push(issue('error', '卡号缺失', '这张卡没有录入卡号，无法用于验卡或重复检测。', card))
    } else {
      const list = numberGroups.get(cardNumber) || []
      list.push(card)
      numberGroups.set(cardNumber, list)
    }

    if (!card.bank) {
      issues.push(issue('warning', '银行缺失', '建议补全发卡银行，便于统计、同步审计和共享额度识别。', card))
    }

    if (card.valid && getCardExpiryStatus(card.valid) === null) {
      issues.push(issue('error', '有效期格式异常', `当前有效期为“${card.valid}”，建议使用 MM/YY。`, card))
    }

    if (isCreditCard(card)) {
      const billDay = getDayNumber(card.accountBillDate)
      const dueDay = getDayNumber(card.dueDate)
      if (!card.accountBillDate || !card.dueDate) {
        issues.push(issue('warning', '账单/还款配置缺失', '信用卡缺少账单日或还款日，无法计算还款提醒和免息期。', card))
      } else {
        if (!billDay) issues.push(issue('error', '账单日非法', '账单日必须是 1-31 之间的数字。', card))
        if (!dueDay) issues.push(issue('error', '还款日非法', '还款日必须是 1-31 之间的数字。', card))
      }
      if (card.isQualified !== '3' && !card.nextAnnualFeeCollectionTime) {
        issues.push(issue('warning', '年费日期缺失', '非终免年费卡片缺少下次年费收取时间，年费提醒可能不完整。', card))
      }
    } else {
      if (card.accountBillDate || card.dueDate || Number(card.annualFee || 0) > 0 || card.nextAnnualFeeCollectionTime) {
        issues.push(issue('info', '储蓄卡包含信用卡字段', '储蓄卡不会参与账单、还款和年费提醒，建议清理相关字段。', card))
      }
    }
  })

  numberGroups.forEach(group => {
    if (group.length > 1) {
      issues.push(issue(
        'error',
        '卡号重复',
        group.map(card => `${card.bank || '未知银行'} - ${card.alias || '未命名卡片'}`).join('、')
      ))
    }
  })

  const sharedGroups = new Map()
  cards.filter(isCreditCard).filter(card => card.isSharedLimit).forEach(card => {
    const key = `${card.country || ''}|${card.bank || ''}|${card.type || ''}`
    const list = sharedGroups.get(key) || []
    list.push(card)
    sharedGroups.set(key, list)
  })
  sharedGroups.forEach(group => {
    const limits = new Set(group.map(card => Number(card.limit || 0)))
    if (group.length > 1 && limits.size > 1) {
      issues.push(issue(
        'warning',
        '共享额度不一致',
        group.map(card => `${card.alias || '未命名卡片'}：${card.limit || 0}`).join('、')
      ))
    }
  })

  const severityWeight = { error: 0, warning: 1, info: 2 }
  return issues.sort((a, b) => severityWeight[a.severity] - severityWeight[b.severity])
}
