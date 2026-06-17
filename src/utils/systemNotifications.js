import { getAllCardReminderSummary } from '@/utils/cardReminderRules'

const NOTIFICATION_KEY = 'card_reminder_system_notification_v1'

export const isSystemNotificationSupported = () => {
  return typeof window !== 'undefined' && 'Notification' in window
}

export const requestSystemNotificationPermission = async () => {
  if (!isSystemNotificationSupported()) {
    return 'unsupported'
  }
  if (Notification.permission === 'granted') {
    return 'granted'
  }
  if (Notification.permission === 'denied') {
    return 'denied'
  }
  return Notification.requestPermission()
}

export const notifySystem = (title, body, options = {}) => {
  if (!isSystemNotificationSupported() || Notification.permission !== 'granted') {
    return false
  }
  new Notification(title, {
    body,
    tag: options.tag || 'credit-card-reminder',
    renotify: false
  })
  return true
}

export const maybeNotifyDailyCardReminders = (cards, options = {}) => {
  if (!isSystemNotificationSupported() || Notification.permission !== 'granted') {
    return false
  }
  const summary = getAllCardReminderSummary(cards)
  if (summary.totalCount <= 0) return false

  const today = new Date().toISOString().slice(0, 10)
  const fingerprint = [
    today,
    summary.repaymentCount,
    summary.billCount,
    summary.annualCount,
    summary.expiryCount
  ].join('|')

  if (!options.force && localStorage.getItem(NOTIFICATION_KEY) === fingerprint) {
    return false
  }

  const body = [
    summary.repaymentCount > 0 ? `还款 ${summary.repaymentCount} 项` : '',
    summary.billCount > 0 ? `账单 ${summary.billCount} 项` : '',
    summary.annualCount > 0 ? `年费 ${summary.annualCount} 项` : '',
    summary.expiryCount > 0 ? `有效期 ${summary.expiryCount} 项` : ''
  ].filter(Boolean).join(' / ')

  const sent = notifySystem('卡片提醒', body, { tag: 'credit-card-reminder-daily' })
  if (sent) {
    localStorage.setItem(NOTIFICATION_KEY, fingerprint)
  }
  return sent
}
