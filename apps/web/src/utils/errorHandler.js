/**
 * 统一错误处理工具
 */
import { ElMessage, ElNotification } from 'element-plus'

/**
 * 错误类型定义
 */
export const ERROR_TYPES = {
  NETWORK: 'network',
  VALIDATION: 'validation',
  PERMISSION: 'permission',
  STORAGE: 'storage',
  ENCRYPTION: 'encryption',
  FILE: 'file',
  UNKNOWN: 'unknown'
}

/**
 * 错误处理器类
 */
export class ErrorHandler {
  /**
   * 处理错误
   * @param {Error|string} error - 错误对象或错误信息
   * @param {string} type - 错误类型
   * @param {string} context - 错误上下文
   * @param {boolean} showUser - 是否向用户显示错误信息
   */
  static handle(error, type = ERROR_TYPES.UNKNOWN, context = '', showUser = true) {
    const errorMessage = typeof error === 'string' ? error : error.message || '未知错误'
    const fullMessage = context ? `${context}: ${errorMessage}` : errorMessage

    // 记录错误到控制台（开发环境）
    if (process.env.NODE_ENV === 'development') {
      console.error(`[${type.toUpperCase()}] ${fullMessage}`, error)
    }

    // 向用户显示错误信息
    if (showUser) {
      this.showErrorToUser(errorMessage, type, context)
    }

    // 返回格式化的错误信息
    return {
      type,
      context,
      message: errorMessage,
      fullMessage,
      timestamp: new Date().toISOString()
    }
  }

  /**
   * 向用户显示错误信息
   */
  static showErrorToUser(message, type, context) {
    const title = this.getErrorTitle(type)
    
    if (type === ERROR_TYPES.NETWORK || type === ERROR_TYPES.ENCRYPTION) {
      // 重要错误使用通知
      ElNotification({
        title,
        message: context ? `${context}: ${message}` : message,
        type: 'error',
        duration: 5000
      })
    } else {
      // 一般错误使用消息
      ElMessage({
        message: context ? `${context}: ${message}` : message,
        type: 'error',
        duration: 3000
      })
    }
  }

  /**
   * 获取错误标题
   */
  static getErrorTitle(type) {
    const titles = {
      [ERROR_TYPES.NETWORK]: '网络错误',
      [ERROR_TYPES.VALIDATION]: '验证错误',
      [ERROR_TYPES.PERMISSION]: '权限错误',
      [ERROR_TYPES.STORAGE]: '存储错误',
      [ERROR_TYPES.ENCRYPTION]: '加密错误',
      [ERROR_TYPES.FILE]: '文件错误',
      [ERROR_TYPES.UNKNOWN]: '系统错误'
    }
    return titles[type] || '错误'
  }

  /**
   * 网络错误处理
   */
  static network(error, context = '网络请求') {
    return this.handle(error, ERROR_TYPES.NETWORK, context)
  }

  /**
   * 验证错误处理
   */
  static validation(error, context = '数据验证') {
    return this.handle(error, ERROR_TYPES.VALIDATION, context)
  }

  /**
   * 存储错误处理
   */
  static storage(error, context = '本地存储') {
    return this.handle(error, ERROR_TYPES.STORAGE, context)
  }

  /**
   * 加密错误处理
   */
  static encryption(error, context = '数据加密') {
    return this.handle(error, ERROR_TYPES.ENCRYPTION, context)
  }

  /**
   * 文件错误处理
   */
  static file(error, context = '文件操作') {
    return this.handle(error, ERROR_TYPES.FILE, context)
  }
}

/**
 * 便捷函数
 */
export const handleError = ErrorHandler.handle.bind(ErrorHandler)
export const handleNetworkError = ErrorHandler.network.bind(ErrorHandler)
export const handleValidationError = ErrorHandler.validation.bind(ErrorHandler)
export const handleStorageError = ErrorHandler.storage.bind(ErrorHandler)
export const handleEncryptionError = ErrorHandler.encryption.bind(ErrorHandler)
export const handleFileError = ErrorHandler.file.bind(ErrorHandler)
