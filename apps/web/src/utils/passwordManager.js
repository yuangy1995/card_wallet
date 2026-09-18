import { StorageManager } from './storage'
import { localDataStore } from './indexedDbStorage'
import { STORAGE_KEYS } from '@/config/constants'
import { globalCache, cardDataCache } from './cache'

/**
 * 密码管理器 - 负责应用锁定和密码验证
 */
export class PasswordManager {
  static PASSWORD_KEY = 'app_security_password'
  static LOCK_STATE_KEY = 'app_lock_state'
  static FAILED_ATTEMPTS_KEY = 'password_failed_attempts'
  static LAST_ACTIVITY_KEY = 'last_activity_time'
  
  // 默认5分钟无操作自动锁定（当前仅用默认值）
  static AUTO_LOCK_TIMEOUT = 5 * 60 * 1000

  static async legacyPasswordMatches(password) {
    const encrypted = StorageManager.get(this.PASSWORD_KEY)
    if (typeof encrypted !== 'string') return false
    const { default: CryptoJS } = await import('crypto-js')
    try {
      const oldHash = CryptoJS.AES.decrypt(encrypted, 'password_encryption_key').toString(CryptoJS.enc.Utf8)
      return oldHash === CryptoJS.SHA256(password + 'app_salt_2024').toString()
    } catch { return false }
  }

  static async legacyExtraEntries() {
    const entries = []
    const raw = localStorage.getItem(STORAGE_KEYS.WEBDAV_CONFIG)
    if (raw) {
      let config
      if (raw.startsWith('default:') || raw.startsWith('encrypted:')) {
        const { decryptData } = await import('./encryption')
        config = decryptData(raw)
        if (typeof config === 'string') config = JSON.parse(config)
      } else config = JSON.parse(raw)
      entries.push([STORAGE_KEYS.WEBDAV_CONFIG, config])
    }
    const backups = localStorage.getItem('cardDataBackups')
    if (backups) entries.push(['cardDataBackups', JSON.parse(backups)])
    return entries
  }

  static cleanupLegacySecrets() {
    for (const key of [this.PASSWORD_KEY, STORAGE_KEYS.WEBDAV_CONFIG, 'cardDataBackups',
      STORAGE_KEYS.CARD_DATA, STORAGE_KEYS.SYNC_RECORDS, STORAGE_KEYS.SYNC_PENDING,
      STORAGE_KEYS.SYNC_REVISION, STORAGE_KEYS.SYNC_LAST_SNAPSHOT, STORAGE_KEYS.SYNC_HISTORY]) {
      if (!StorageManager.remove(key)) throw new Error('本地加密已保存，但旧数据未能清理，请允许浏览器存储后重新解锁。')
    }
    // 旧的签名凭证不能解密保险库；只有带 PRF 包装密钥的新凭证可继续使用。
    const credential = StorageManager.get('platform_unlock_credential')
    if (credential && !credential.vault) StorageManager.remove('platform_unlock_credential')
  }

  static async setAppPassword(password, oldPassword = '') {
    if (typeof password !== 'string' || password.length < 6) throw new Error('密码至少需要6位数')
    await localDataStore.initialize()
    if (localDataStore.vaultMetadata) {
      await localDataStore.changeVaultPassword(oldPassword, password)
    } else {
      if (this.hasPassword() && !(await this.legacyPasswordMatches(oldPassword))) throw new Error('当前密码不正确')
      await localDataStore.enableVault(password, await this.legacyExtraEntries())
    }
    this.cleanupLegacySecrets()
    this.resetFailedAttempts()
    return true
  }

  static async verifyPassword(password) {
    if (this.isTemporarilyLocked()) return false
    await localDataStore.initialize()
    try {
      if (localDataStore.vaultMetadata) {
        await localDataStore.unlockVault(password)
      } else {
        if (!(await this.legacyPasswordMatches(password))) { this.incrementFailedAttempts(); return false }
        await localDataStore.enableVault(password, await this.legacyExtraEntries())
      }
      this.cleanupLegacySecrets()
      this.resetFailedAttempts()
      return true
    } catch (error) {
      localDataStore.lock()
      if (error.name === 'OperationError') { this.incrementFailedAttempts(); return false }
      throw error
    }
  }

  /**
   * 检查是否已设置密码
   */
  static hasPassword() {
    return Boolean(localDataStore.vaultMetadata) || StorageManager.has(this.PASSWORD_KEY)
  }

  /**
   * 锁定应用
   */
  static lockApp() {
    localDataStore.lock()
    globalCache.clear()
    cardDataCache.clear()
    StorageManager.set(this.LOCK_STATE_KEY, {
      isLocked: true,
      lockTime: Date.now()
    })
  }

  /**
   * 解锁应用
   */
  static unlockApp() {
    if (localDataStore.vaultMetadata && !localDataStore.isUnlocked) throw new Error('请先验证密码。')
    StorageManager.set(this.LOCK_STATE_KEY, {
      isLocked: false,
      unlockTime: Date.now()
    })
    this.updateLastActivity()
  }

  /**
   * 检查应用是否被锁定
   */
  static isAppLocked() {
    const lockState = StorageManager.get(this.LOCK_STATE_KEY)
    return Boolean(localDataStore.vaultMetadata && !localDataStore.isUnlocked) || lockState?.isLocked || false
  }

  /**
   * 更新最后活动时间
   */
  static updateLastActivity() {
    StorageManager.set(this.LAST_ACTIVITY_KEY, Date.now())
  }

  static getRemainingLockTime() {
    const now = Date.now()
    const lastActivity = StorageManager.get(this.LAST_ACTIVITY_KEY, now)
    return Math.max(0, this.AUTO_LOCK_TIMEOUT - Math.max(0, now - lastActivity))
  }

  /**
   * 检查是否应该自动锁定
   */
  static shouldAutoLock() {
    if (!this.hasPassword()) return false
    return this.getRemainingLockTime() <= 0
  }

  /**
   * 获取失败尝试次数
   */
  static getFailedAttempts() {
    return StorageManager.get(this.FAILED_ATTEMPTS_KEY, 0)
  }

  /**
   * 增加失败尝试次数
   */
  static incrementFailedAttempts() {
    const current = this.getFailedAttempts()
    StorageManager.set(this.FAILED_ATTEMPTS_KEY, current + 1)
    if (current + 1 >= 5) StorageManager.set('password_retry_after', Date.now() + 60_000)
  }

  /**
   * 重置失败尝试次数
   */
  static resetFailedAttempts() {
    StorageManager.remove(this.FAILED_ATTEMPTS_KEY)
    StorageManager.remove('password_retry_after')
  }

  /**
   * 清除所有安全相关数据
   */
  static clearSecurityData() {
    StorageManager.remove(this.PASSWORD_KEY)
    StorageManager.remove(this.LOCK_STATE_KEY)
    StorageManager.remove(this.FAILED_ATTEMPTS_KEY)
    StorageManager.remove(this.LAST_ACTIVITY_KEY)
    StorageManager.remove('password_retry_after')
    StorageManager.remove('platform_unlock_credential')
  }

  /**
   * 检查是否被临时锁定（防暴力破解）
   */
  static isTemporarilyLocked() {
    const failedAttempts = this.getFailedAttempts()
    if (failedAttempts < 5) return false
    const until = StorageManager.get('password_retry_after', 0)
    if (until > Date.now()) return true
    this.resetFailedAttempts()
    return false
  }

    /**
   * 清除所有应用数据（用于忘记密码重置）
   */
    static async clearAllAppData() {
      try {
        // 快照同样包含完整卡片资料，不能在重置密码后留下。
        const localDataKeys = [
          STORAGE_KEYS.CARD_DATA,
          STORAGE_KEYS.SYNC_RECORDS,
          STORAGE_KEYS.SYNC_PENDING,
          STORAGE_KEYS.SYNC_REVISION,
          STORAGE_KEYS.SYNC_LAST_SNAPSHOT,
          STORAGE_KEYS.SYNC_HISTORY
        ]
        const keysToRemove = [
          ...localDataKeys,
          'cardDataBackups',
          STORAGE_KEYS.WEBDAV_CONFIG,
          STORAGE_KEYS.TABLE_CUSTOM_COLUMNS,
          'platform_unlock_credential'
        ]
        
        for (const key of keysToRemove) {
          if (!StorageManager.remove(key)) throw new Error('本地数据未能清除，请重试。')
        }

        if (!localDataStore.initialized) {
          await localDataStore.initialize()
        }
        if (localDataStore.vaultMetadata) await localDataStore.clearVault()
        else await Promise.all(localDataKeys.map((key) => localDataStore.remove(key)))
        
        // 清除安全相关数据
        this.clearSecurityData()
        
        return true
      } catch (error) {
        console.error('清除数据失败:', error)
        return false
      }
    }
}
