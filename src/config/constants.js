/**
 * 应用常量配置
 */

// 备份相关常量
export const BACKUP_CONSTANTS = {
  MAX_BACKUP_COUNT: 50,          // 最大备份数量
  ANNUAL_FEE_CHECK_DAYS: 60,     // 年费检查天数
  WEBDAV_BACKUP_DIR: '/credit-card-backup'  // WebDAV备份目录
}

// 存储相关常量
export const STORAGE_KEYS = {
  CARD_DATA: 'cardData',
  CARD_DATA_BACKUPS: 'cardDataBackups',
  WEBDAV_CONFIG: 'webdav_config',
  TABLE_CUSTOM_COLUMNS: 'tableCustomColumns'
}

// 加密相关常量
export const ENCRYPTION_CONSTANTS = {
  ENCRYPTED_PREFIX: 'ENCRYPTED:',
  DEFAULT_PASSWORD: 'default_password_2023'
}

// UI相关常量
export const UI_CONSTANTS = {
  MESSAGE_DURATION: 3000,        // 消息显示时长
  LOADING_DELAY: 500,           // 加载延迟
  DEBOUNCE_DELAY: 300           // 防抖延迟
}
