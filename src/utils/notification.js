import { ElNotification } from 'element-plus'

// 通知类型枚举
export const NotificationType = {
  SUCCESS: 'success',
  WARNING: 'warning',
  INFO: 'info',
  ERROR: 'error'
}

// 默认配置
const defaultOptions = {
  duration: 3000,
  showClose: true,
  position: 'top-right'
}

/**
 * 显示通知
 * @param {string} title - 通知标题
 * @param {string} message - 通知内容
 * @param {string} type - 通知类型
 * @param {Object} options - 额外的配置选项
 */
export const notify = (title, message, type = NotificationType.INFO, options = {}) => {
  ElNotification({
    title,
    message,
    type,
    ...defaultOptions,
    ...options
  })
}

// 快捷方法
export const notifySuccess = (title, message, options = {}) => {
  notify(title, message, NotificationType.SUCCESS, options)
}

export const notifyWarning = (title, message, options = {}) => {
  notify(title, message, NotificationType.WARNING, options)
}

export const notifyInfo = (title, message, options = {}) => {
  notify(title, message, NotificationType.INFO, options)
}

export const notifyError = (title, message, options = {}) => {
  notify(title, message, NotificationType.ERROR, options)
}

// 预定义的通知
export const predefinedNotifications = {
  // 卡片操作
  cardAdded: () => notifySuccess('添加成功', '信用卡信息已添加'),
  cardUpdated: () => notifySuccess('更新成功', '信用卡信息已更新'),
  cardDeleted: () => notifySuccess('删除成功', '信用卡已被删除'),
  
  // 数据操作
  dataImported: () => notifySuccess('导入成功', '数据已成功导入'),
  dataExported: () => notifySuccess('导出成功', '数据已成功导出'),
  dataCopied: () => notifySuccess('复制成功', '数据已复制到剪贴板'),
  
  // 错误提示
  invalidData: () => notifyError('数据错误', '请检查数据格式是否正确'),
  operationFailed: (message) => notifyError('操作失败', message),
  
  // 安全提示
  sensitiveInfoShown: () => notifyWarning('安全提示', '敏感信息将在30秒后自动隐藏'),
  sensitiveInfoHidden: () => notifyInfo('安全提示', '敏感信息已隐藏')
}
