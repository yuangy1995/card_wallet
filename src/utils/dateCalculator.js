/**
 * 日期计算工具类
 */

/**
 * 将时间戳转换为指定格式的日期字符串
 * @param {number} timestamp - 时间戳
 * @param {string} format - 日期格式
 * @returns {string} 格式化后的日期字符串
 */
export function timestampToTime(timestamp, format) {
  if (!timestamp) return ''
  
  const date = new Date(timestamp)
  const year = date.getFullYear()
  const month = (date.getMonth() + 1).toString().padStart(2, '0')
  const day = date.getDate().toString().padStart(2, '0')
  const hour = date.getHours().toString().padStart(2, '0')
  const minute = date.getMinutes().toString().padStart(2, '0')
  const second = date.getSeconds().toString().padStart(2, '0')

  const formatMap = {
    'YYYY': year,
    'MM': month,
    'DD': day,
    'HH': hour,
    'mm': minute,
    'ss': second
  }

  let result = format
  Object.entries(formatMap).forEach(([key, value]) => {
    result = result.replace(key, value)
  })

  return result
}

/**
 * 计算两个日期之间的天数差
 * @param {string} dateString1 - 第一个日期字符串
 * @param {string} dateString2 - 第二个日期字符串
 * @returns {number} 天数差
 */
export function getDaysDifference(dateString1, dateString2) {
  const date1 = new Date(dateString1)
  const date2 = new Date(dateString2)
  const timeDiff = Math.abs(date2.getTime() - date1.getTime())
  return Math.ceil(timeDiff / (1000 * 3600 * 24))
}

/**
 * 账单日补全
 * @param {string|number} accountBillDate - 账单日
 * @param {string} dateType - 日期类型 (current/next)
 * @returns {string} 完整的账单日期
 */
export function completeAccountBillDate(accountBillDate, dateType = 'current') {
  if (!accountBillDate) return ''

  const currentDate = new Date()
  const year = currentDate.getFullYear()
  const month = currentDate.getMonth() + 1
  const day = parseInt(accountBillDate)

  // 获取当月的最后一天
  const lastDay = new Date(year, month, 0).getDate()
  // 如果账单日大于当月最后一天，使用当月最后一天
  const actualDay = day > lastDay ? lastDay : day

  let targetMonth = month
  let targetYear = year

  if (dateType === 'next') {
    targetMonth = month + 1
    if (targetMonth > 12) {
      targetMonth = 1
      targetYear++
    }
  }

  return `${targetYear}-${targetMonth.toString().padStart(2, '0')}-${actualDay.toString().padStart(2, '0')}`
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
  
  let targetYear = billDate.getFullYear()
  let targetMonth = billDate.getMonth() + 1

  // 如果还款日小于账单日，说明是下个月
  if (dueDateNum < parseInt(accountBillDate)) {
    targetMonth++
    if (targetMonth > 12) {
      targetMonth = 1
      targetYear++
    }
  }

  // 获取目标月份的最后一天
  const lastDay = new Date(targetYear, targetMonth, 0).getDate()
  // 如果还款日大于当月最后一天，使用当月最后一天
  const actualDay = dueDateNum > lastDay ? lastDay : dueDateNum

  return `${targetYear}-${targetMonth.toString().padStart(2, '0')}-${actualDay.toString().padStart(2, '0')}`
}

/**
 * 计算本期免息期
 * @param {string|number} accountBillDate - 账单日
 * @param {string|number} dueDate - 还款日
 * @returns {number} 免息天数
 */
export function calculateInterestFreePeriod(accountBillDate, dueDate) {
  if (!accountBillDate || !dueDate) return 0

  const currentBillDate = completeAccountBillDate(accountBillDate, 'current')
  const nextBillDate = completeAccountBillDate(accountBillDate, 'next')
  const currentDueDate = completeDueDate(accountBillDate, dueDate, 'current')

  // 获取当前日期
  const today = new Date()
  const todayString = timestampToTime(today.getTime(), 'YYYY-MM-DD')

  // 如果今天已经过了本期账单日，则计算下期免息期
  if (todayString > currentBillDate) {
    return getDaysDifference(nextBillDate, completeDueDate(accountBillDate, dueDate, 'next'))
  }

  return getDaysDifference(currentBillDate, currentDueDate)
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
  const todayString = timestampToTime(today.getTime(), 'YYYY-MM-DD')
  const currentDueDate = completeDueDate(accountBillDate, dueDate, 'current')

  // 如果已经过了还款日，返回0
  if (todayString > currentDueDate) return 0

  return getDaysDifference(todayString, currentDueDate)
}

/**
 * 检查是否接近年费收取时间
 * @param {string} nextAnnualFeeDate - 下次年费收取时间
 * @param {number} warningDays - 提前警告的天数
 * @returns {boolean} 是否接近年费收取时间
 */
export function isNearAnnualFeeDate(nextAnnualFeeDate, warningDays = 60) {
  if (!nextAnnualFeeDate) return false

  const today = new Date()
  const todayString = timestampToTime(today.getTime(), 'YYYY-MM-DD')
  const remainingDays = getDaysDifference(todayString, nextAnnualFeeDate)

  return remainingDays <= warningDays && remainingDays >= 0
}
