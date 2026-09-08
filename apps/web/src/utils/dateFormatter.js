/**
 * 日期格式化工具
 */

/**
 * 格式化日期为中文格式字符串
 * @param {Date} date - 要格式化的日期对象
 * @returns {string} 格式化后的日期字符串 (YYYY-MM-DD HH:mm:ss)
 */
export const formatDateToChinese = (date = new Date()) => {
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  })
}

/**
 * 创建当前时间的中文格式字符串
 * @returns {string} 当前时间的格式化字符串
 */
export const getCurrentTimeFormatted = () => {
  return formatDateToChinese(new Date())
}

export const getCurrentTimestamp = () => Date.now()
