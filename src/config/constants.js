/**
 * 应用常量配置
 */

// 数据维护相关常量
export const BACKUP_CONSTANTS = {
  ANNUAL_FEE_CHECK_DAYS: 60     // 年费检查天数
}

// 存储相关常量
export const STORAGE_KEYS = {
  CARD_DATA: 'cardData',
  SYNC_RECORDS: 'cardSyncRecordsV4',
  SYNC_PENDING: 'cardSyncPendingV4',
  SYNC_REVISION: 'cardSyncMutationRevisionV4',
  WEBDAV_CONFIG: 'webdav_config',
  TABLE_CUSTOM_COLUMNS: 'tableCustomColumns'
}

// UI相关常量
export const UI_CONSTANTS = {
  MESSAGE_DURATION: 3000,        // 消息显示时长
  LOADING_DELAY: 500,           // 加载延迟
  DEBOUNCE_DELAY: 300           // 防抖延迟
}

// 安全相关常量
export const SECURITY_CONSTANTS = {
  AUTO_LOCK_TIMEOUT: 2 * 60 * 1000, // 2分钟自动锁定
  MAX_FAILED_ATTEMPTS: 5,           // 最大失败尝试次数
  PASSWORD_MIN_LENGTH: 6            // 密码最小长度
}
