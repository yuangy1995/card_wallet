import { ref, onMounted, onUnmounted } from 'vue'
import { PasswordManager } from '@/utils/passwordManager'

/**
 * 自动锁定功能组合式函数
 */
export function useAutoLock() {
  const isLocked = ref(false)
  const lockTimer = ref(null)
  const remainingTime = ref(0) // 剩余时间（秒）
  const countdownTimer = ref(null)
  const activityEvents = ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart', 'click']
  
  // 更新活动时间并重置定时器
  const updateActivity = () => {
    if (PasswordManager.hasPassword() && !PasswordManager.isAppLocked()) {
      PasswordManager.updateLastActivity()
      resetLockTimer()
    }
  }

  // 开始倒计时
  const startCountdown = () => {
    if (countdownTimer.value) {
      clearInterval(countdownTimer.value)
    }
    
    remainingTime.value = Math.floor(PasswordManager.AUTO_LOCK_TIMEOUT / 1000)
    
    countdownTimer.value = setInterval(() => {
      remainingTime.value -= 1
      if (remainingTime.value <= 0) {
        clearInterval(countdownTimer.value)
        countdownTimer.value = null
      }
    }, 1000)
  }

  // 重置锁定定时器
  const resetLockTimer = () => {
    if (lockTimer.value) {
      clearTimeout(lockTimer.value)
    }
    
    if (countdownTimer.value) {
      clearInterval(countdownTimer.value)
    }
    
    if (PasswordManager.hasPassword() && !PasswordManager.isAppLocked()) {
      lockTimer.value = setTimeout(() => {
        lockApp()
      }, PasswordManager.AUTO_LOCK_TIMEOUT)
      
      // 开始倒计时
      startCountdown()
    }
  }

  // 锁定应用
  const lockApp = () => {
    PasswordManager.lockApp()
    isLocked.value = true
    clearLockTimer()
    console.log('应用已自动锁定')
  }

  // 解锁应用
  const unlockApp = () => {
    PasswordManager.unlockApp()
    isLocked.value = false
    resetLockTimer()
    console.log('应用已解锁')
  }

  // 清除定时器
  const clearLockTimer = () => {
    if (lockTimer.value) {
      clearTimeout(lockTimer.value)
      lockTimer.value = null
    }
    if (countdownTimer.value) {
      clearInterval(countdownTimer.value)
      countdownTimer.value = null
    }
    remainingTime.value = 0
  }

  // 检查锁定状态
  const checkLockStatus = () => {
    if (PasswordManager.hasPassword()) {
      const locked = PasswordManager.isAppLocked() || PasswordManager.shouldAutoLock()
      if (locked && !isLocked.value) {
        lockApp()
      }
      isLocked.value = locked
    }
  }

  // 添加活动监听器
  const addActivityListeners = () => {
    activityEvents.forEach(event => {
      document.addEventListener(event, updateActivity, true)
    })
  }

  // 移除活动监听器
  const removeActivityListeners = () => {
    activityEvents.forEach(event => {
      document.removeEventListener(event, updateActivity, true)
    })
  }

  // 初始化
  const init = () => {
    checkLockStatus()
    if (PasswordManager.hasPassword()) {
      addActivityListeners()
      if (!isLocked.value) {
        resetLockTimer()
      }
    }
  }

  // 销毁
  const destroy = () => {
    removeActivityListeners()
    clearLockTimer()
  }

  // 手动锁定
  const manualLock = () => {
    if (PasswordManager.hasPassword()) {
      lockApp()
    }
  }

  // 设置密码后初始化
  const initAfterPasswordSet = () => {
    addActivityListeners()
    resetLockTimer()
    isLocked.value = false
  }

  onMounted(() => {
    init()
    
    // 监听页面可见性变化
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        checkLockStatus()
      }
    })

    // 监听存储变化（多标签页同步）
    window.addEventListener('storage', (e) => {
      if (e.key === PasswordManager.LOCK_STATE_KEY) {
        checkLockStatus()
      }
    })
  })

  onUnmounted(() => {
    destroy()
  })

  return {
    isLocked,
    remainingTime,
    lockApp: manualLock,
    unlockApp,
    checkLockStatus,
    initAfterPasswordSet,
    updateActivity
  }
}
