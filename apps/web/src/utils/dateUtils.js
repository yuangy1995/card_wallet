import { formatCardTimestamp } from '@/utils/cardTimestamp'

/**
 * 格式化日期的工具函数
 * @param {string} dateString - 要格式化的日期字符串
 * @returns {string} - 格式化后的日期字符串
 */
export function formatDate(dateString) {
  return formatCardTimestamp(dateString)
}

/**
 * 计算两个日期之间的天数差
 * @param {string} startDate - 开始日期
 * @param {string} endDate - 结束日期
 * @returns {number} - 天数差
 */
export function daysBetween(startDate, endDate) {
  if (!startDate || !endDate) return 0;
  
  const start = new Date(startDate);
  const end = new Date(endDate);
  
  if (isNaN(start.getTime()) || isNaN(end.getTime())) return 0;
  
  // 计算天数差（毫秒转天数）
  const diffTime = Math.abs(end - start);
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  
  return diffDays;
}
