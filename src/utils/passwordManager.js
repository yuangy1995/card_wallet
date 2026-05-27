import CryptoJS from 'crypto-js'
import { StorageManager } from './storage'

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

  /**
   * 生成密码哈希
   */
  static hashPassword(password) {
    return CryptoJS.SHA256(password + 'app_salt_2024').toString()
  }

  /**
   * 设置应用密码
   */
  static setAppPassword(password) {
    if (!password || password.length < 6) {
      throw new Error('密码至少需要6位数')
    }
    
    const hashedPassword = this.hashPassword(password)
    const encryptedHash = CryptoJS.AES.encrypt(hashedPassword, 'password_encryption_key').toString()
    
    StorageManager.set(this.PASSWORD_KEY, encryptedHash)
    this.resetFailedAttempts()
    return true
  }

  /**
   * 验证密码
   */
  static verifyPassword(password) {
    try {
      const encryptedHash = StorageManager.get(this.PASSWORD_KEY)
      if (!encryptedHash) {
        return false
      }

      const decryptedHash = CryptoJS.AES.decrypt(encryptedHash, 'password_encryption_key').toString(CryptoJS.enc.Utf8)
      const inputHash = this.hashPassword(password)
      
      const isValid = decryptedHash === inputHash
      
      if (isValid) {
        this.resetFailedAttempts()
      } else {
        this.incrementFailedAttempts()
      }
      
      return isValid
    } catch (error) {
      console.error('密码验证失败:', error)
      return false
    }
  }

  /**
   * 检查是否已设置密码
   */
  static hasPassword() {
    return StorageManager.has(this.PASSWORD_KEY)
  }

  /**
   * 锁定应用
   */
  static lockApp() {
    StorageManager.set(this.LOCK_STATE_KEY, {
      isLocked: true,
      lockTime: Date.now()
    })
  }

  /**
   * 解锁应用
   */
  static unlockApp() {
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
    return lockState?.isLocked || false
  }

  /**
   * 更新最后活动时间
   */
  static updateLastActivity() {
    StorageManager.set(this.LAST_ACTIVITY_KEY, Date.now())
  }

  /**
   * 检查是否应该自动锁定
   */
  static shouldAutoLock() {
    if (!this.hasPassword()) return false
    
    const lastActivity = StorageManager.get(this.LAST_ACTIVITY_KEY, Date.now())
    const timeSinceLastActivity = Date.now() - lastActivity
    
    return timeSinceLastActivity > this.AUTO_LOCK_TIMEOUT
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
  }

  /**
   * 重置失败尝试次数
   */
  static resetFailedAttempts() {
    StorageManager.remove(this.FAILED_ATTEMPTS_KEY)
  }

  /**
   * 清除所有安全相关数据
   */
  static clearSecurityData() {
    StorageManager.remove(this.PASSWORD_KEY)
    StorageManager.remove(this.LOCK_STATE_KEY)
    StorageManager.remove(this.FAILED_ATTEMPTS_KEY)
    StorageManager.remove(this.LAST_ACTIVITY_KEY)
    StorageManager.remove('platform_unlock_credential')
  }

  /**
   * 检查是否被临时锁定（防暴力破解）
   */
  static isTemporarilyLocked() {
    const failedAttempts = this.getFailedAttempts()
    return failedAttempts >= 5 // 5次失败后临时锁定
  }

    /**
   * 清除所有应用数据（用于忘记密码重置）
   */
    static clearAllAppData() {
      try {
        // 清除所有业务数据
        const keysToRemove = [
          'cardData',
          'cardDataBackups', 
          'webdav_config',
          'tableCustomColumns',
          'platform_unlock_credential'
        ]
        
        keysToRemove.forEach(key => {
          StorageManager.remove(key)
        })
        
        // 清除安全相关数据
        this.clearSecurityData()
        
        return true
      } catch (error) {
        console.error('清除数据失败:', error)
        return false
      }
    }
}
