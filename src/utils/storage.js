/**
 * 本地存储封装工具
 */
import { STORAGE_KEYS } from '@/config/constants'
import { handleStorageError } from '@/utils/errorHandler'
import { autoMigrateLocalData } from '@/utils/cardDataMigration'

/**
 * 本地存储管理器
 */
export class StorageManager {
  /**
   * 获取存储的数据
   * @param {string} key - 存储键
   * @param {any} defaultValue - 默认值
   * @returns {any} 存储的数据
   */
  static get(key, defaultValue = null) {
    try {
      const value = localStorage.getItem(key)
      if (value === null) {
        return defaultValue
      }
      return JSON.parse(value)
    } catch (error) {
      handleStorageError(error, `读取存储数据 ${key}`)
      return defaultValue
    }
  }

  /**
   * 设置存储数据
   * @param {string} key - 存储键
   * @param {any} value - 存储值
   * @returns {boolean} 是否设置成功
   */
  static set(key, value) {
    try {
      const jsonValue = JSON.stringify(value)
      localStorage.setItem(key, jsonValue)
      return true
    } catch (error) {
      handleStorageError(error, `保存存储数据 ${key}`)
      return false
    }
  }

  /**
   * 移除存储数据
   * @param {string} key - 存储键
   * @returns {boolean} 是否移除成功
   */
  static remove(key) {
    try {
      localStorage.removeItem(key)
      return true
    } catch (error) {
      handleStorageError(error, `删除存储数据 ${key}`)
      return false
    }
  }

  /**
   * 清空所有存储数据
   * @returns {boolean} 是否清空成功
   */
  static clear() {
    try {
      localStorage.clear()
      return true
    } catch (error) {
      handleStorageError(error, '清空存储数据')
      return false
    }
  }

  /**
   * 检查键是否存在
   * @param {string} key - 存储键
   * @returns {boolean} 键是否存在
   */
  static has(key) {
    return localStorage.getItem(key) !== null
  }

  /**
   * 获取所有键
   * @returns {string[]} 所有存储键
   */
  static keys() {
    try {
      return Object.keys(localStorage)
    } catch (error) {
      handleStorageError(error, '获取存储键列表')
      return []
    }
  }
}

/**
 * 信用卡数据存储
 */
export class CardDataStorage {
  /**
   * 获取信用卡数据（自动迁移老数据）
   * @param {boolean} returnMigrationInfo - 是否返回迁移信息
   * @returns {Array|Object} 信用卡数据数组或包含迁移信息的对象
   */
  static getCardData(returnMigrationInfo = false) {
    const rawData = StorageManager.get(STORAGE_KEYS.CARD_DATA, [])
    
    // 自动迁移老数据
    const migrationResult = autoMigrateLocalData(rawData)
    
    if (migrationResult.migrated) {
      // 自动保存迁移后的数据
      this.saveCardData(migrationResult.data)
      
      if (returnMigrationInfo) {
        return {
          data: migrationResult.data,
          migrationInfo: migrationResult
        }
      }
      return migrationResult.data
    }
    
    if (returnMigrationInfo) {
      return {
        data: rawData,
        migrationInfo: migrationResult
      }
    }
    return rawData
  }

  /**
   * 保存信用卡数据
   * @param {Array} cardData - 信用卡数据数组
   * @returns {boolean} 是否保存成功
   */
  static saveCardData(cardData) {
    return StorageManager.set(STORAGE_KEYS.CARD_DATA, cardData)
  }

  /**
   * 获取表格列配置
   * @returns {Array} 列配置数组
   */
  static getTableColumns() {
    return StorageManager.get(STORAGE_KEYS.TABLE_CUSTOM_COLUMNS, [])
  }

  /**
   * 保存表格列配置
   * @param {Array} columns - 列配置数组
   * @returns {boolean} 是否保存成功
   */
  static saveTableColumns(columns) {
    return StorageManager.set(STORAGE_KEYS.TABLE_CUSTOM_COLUMNS, columns)
  }

  /**
   * 获取WebDAV配置
   * @returns {Object|null} WebDAV配置对象
   */
  static getWebDAVConfig() {
    return StorageManager.get(STORAGE_KEYS.WEBDAV_CONFIG, null)
  }

  /**
   * 保存WebDAV配置
   * @param {Object} config - WebDAV配置对象
   * @returns {boolean} 是否保存成功
   */
  static saveWebDAVConfig(config) {
    return StorageManager.set(STORAGE_KEYS.WEBDAV_CONFIG, config)
  }
}

/**
 * 便捷函数导出
 */
export const getCardData = CardDataStorage.getCardData
export const saveCardData = CardDataStorage.saveCardData
export const getTableColumns = CardDataStorage.getTableColumns
export const saveTableColumns = CardDataStorage.saveTableColumns
