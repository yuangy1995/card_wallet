/**
 * 日期计算工具类
 */

/**
 * 将时间戳转换为指定格式的日期字符串
 * @param {number} timestamp - 时间戳
 * @param {string} format - 日期格式
 * @returns {string} 格式化后的日期字符串
 */
export function timestampToTime(timestamp, format = 'YYYY-MM-DD') {
  if (!timestamp) return ''
  
  const date = new Date(timestamp)
  const formatMap = {
    'YYYY': date.getFullYear(),
    'MM': (date.getMonth() + 1).toString().padStart(2, '0'),
    'DD': date.getDate().toString().padStart(2, '0'),
    'HH': date.getHours().toString().padStart(2, '0'),
    'mm': date.getMinutes().toString().padStart(2, '0'),
    'ss': date.getSeconds().toString().padStart(2, '0')
  }

  return Object.entries(formatMap).reduce((result, [key, value]) => 
    result.replace(key, value), format)
}

/**
 * 计算两个日期之间的天数差
 * @param {string|Date} date1 - 第一个日期
 * @param {string|Date} date2 - 第二个日期
 * @returns {number} 天数差
 */
export function getDaysDifference(date1, date2) {
  const d1 = new Date(date1)
  const d2 = new Date(date2)
  return Math.ceil(Math.abs(d2 - d1) / (1000 * 3600 * 24))
}

/**
 * 获取指定月份的最后一天
 * @param {number} year - 年份
 * @param {number} month - 月份
 * @returns {number} 最后一天的日期
 */
const getLastDayOfMonth = (year, month) => new Date(year, month, 0).getDate()

/**
 * 账单日补全
 * @param {string|number} accountBillDate - 账单日
 * @param {string} dateType - 日期类型 (current/next)
 * @returns {string} 完整的账单日期
 */
export function completeAccountBillDate(accountBillDate, dateType = 'current') {
  if (!accountBillDate) return ''

  const currentDate = new Date()
  let year = currentDate.getFullYear()
  let month = currentDate.getMonth() + 1
  const day = parseInt(accountBillDate)

  if (dateType === 'next') {
    month++
    if (month > 12) {
      month = 1
      year++
    }
  }

  const lastDay = getLastDayOfMonth(year, month)
  const actualDay = Math.min(day, lastDay)

  return `${year}-${month.toString().padStart(2, '0')}-${actualDay.toString().padStart(2, '0')}`
}

/**
 * 还款日补全
 * @param {string|number} accountBillDate - 账单日
 * @param {string|number} dueDate - 还款日
 * @param {string} dateType - 日期类型 (current/next)
 * @returns {string} 完整的还款日期
 */
export function completeDueDate(accountBillDate, dueDate, dateType = 'current') {
  if (!accountBillDate || !dueDate) return ''

  const billDate = new Date(completeAccountBillDate(accountBillDate, dateType))
  const dueDateNum = parseInt(dueDate)
  const billDateNum = parseInt(accountBillDate)
  
  let year = billDate.getFullYear()
  let month = billDate.getMonth() + 1

  if (dueDateNum < billDateNum) {
    month++
    if (month > 12) {
      month = 1
      year++
    }
  }

  const lastDay = getLastDayOfMonth(year, month)
  const actualDay = Math.min(dueDateNum, lastDay)

  return `${year}-${month.toString().padStart(2, '0')}-${actualDay.toString().padStart(2, '0')}`
}

/**
 * 计算本期免息期
 * @param {string|number} accountBillDate - 账单日
 * @param {string|number} dueDate - 还款日
 * @returns {number} 免息天数
 */
export function calculateInterestFreePeriod(accountBillDate, dueDate) {
  if (!accountBillDate || !dueDate) return 0

  const today = new Date()
  const currentBillDate = completeAccountBillDate(accountBillDate, 'current')
  const todayString = timestampToTime(today.getTime())

  if (todayString > currentBillDate) {
    const nextBillDate = completeAccountBillDate(accountBillDate, 'next')
    return getDaysDifference(nextBillDate, completeDueDate(accountBillDate, dueDate, 'next'))
  }

  return getDaysDifference(currentBillDate, completeDueDate(accountBillDate, dueDate, 'current'))
}

/**
 * 计算上期账单还款剩余天数
 * @param {string|number} accountBillDate - 账单日
 * @param {string|number} dueDate - 还款日
 * @returns {number} 剩余天数
 */
export function calculateRemainingDaysForPreviousBill(accountBillDate, dueDate) {
  if (!accountBillDate || !dueDate) return 0

  const today = new Date()
  const todayString = timestampToTime(today.getTime())
  const currentDueDate = completeDueDate(accountBillDate, dueDate, 'current')

  return todayString > currentDueDate ? 0 : getDaysDifference(todayString, currentDueDate)
}

/**
 * 检查是否接近年费收取时间
 * @param {string|Date} nextAnnualFeeDate - 下次年费收取时间
 * @param {number} warningDays - 提前警告的天数
 * @returns {boolean} 是否接近年费收取时间
 */
export function isNearAnnualFeeDate(nextAnnualFeeDate, warningDays = 60) {
  if (!nextAnnualFeeDate) return false

  const today = new Date()
  const remainingDays = getDaysDifference(today, nextAnnualFeeDate)
  return remainingDays <= warningDays && remainingDays >= 0
}
