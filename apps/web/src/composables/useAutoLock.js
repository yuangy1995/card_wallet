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
  const hasPassword = ref(PasswordManager.hasPassword())
  const ACTIVITY_THROTTLE_INTERVAL = 1000
  let lastActivityUpdateTime = -Infinity
  let activityListenersActive = false
  let visibilityChangeHandler = null
  let storageChangeHandler = null

  // 高频事件先节流，再读取同步 localStorage。
  const updateActivity = (eventOrForce = false) => {
    const now = Date.now()
    if (eventOrForce !== true && now - lastActivityUpdateTime < ACTIVITY_THROTTLE_INTERVAL) return
    lastActivityUpdateTime = now
    if (!PasswordManager.hasPassword()) return
    // 后台计时器可能延迟，不能让恢复后的第一个事件延长已过期的会话。
    if (PasswordManager.isAppLocked() || PasswordManager.shouldAutoLock()) {
      lockApp()
      return
    }
    PasswordManager.updateLastActivity()
    resetLockTimer()
  }

  const startCountdown = (remainingMs) => {
    const deadline = Date.now() + remainingMs
    remainingTime.value = Math.ceil(remainingMs / 1000)
    countdownTimer.value = setInterval(() => {
      remainingTime.value = Math.max(0, Math.ceil((deadline - Date.now()) / 1000))
      if (remainingTime.value === 0) {
        clearInterval(countdownTimer.value)
        countdownTimer.value = null
      }
    }, 1000)
  }

  const resetLockTimer = () => {
    clearLockTimer()
    if (!PasswordManager.hasPassword() || PasswordManager.isAppLocked()) return
    const remainingMs = PasswordManager.getRemainingLockTime()
    if (remainingMs <= 0) {
      lockApp()
      return
    }
    // 到期后重新核对共享活动时间，避免闲置标签页锁住正在使用的另一页。
    lockTimer.value = setTimeout(checkLockStatus, remainingMs)
    startCountdown(remainingMs)
  }

  const lockApp = (broadcast = true) => {
    PasswordManager.lockApp(broadcast)
    isLocked.value = true
    clearLockTimer()
  }

  const unlockApp = () => {
    PasswordManager.unlockApp()
    isLocked.value = false
    lastActivityUpdateTime = -Infinity
    resetLockTimer()
  }

  const clearLockTimer = () => {
    if (lockTimer.value !== null) {
      clearTimeout(lockTimer.value)
      lockTimer.value = null
    }
    if (countdownTimer.value !== null) {
      clearInterval(countdownTimer.value)
      countdownTimer.value = null
    }
    remainingTime.value = 0
  }

  const checkLockStatus = () => {
    hasPassword.value = PasswordManager.hasPassword()
    if (!hasPassword.value) {
      isLocked.value = false
      clearLockTimer()
      removeActivityListeners()
      return
    }
    addActivityListeners()
    const locked = PasswordManager.isAppLocked() || PasswordManager.shouldAutoLock()
    if (locked) {
      if (!isLocked.value) lockApp()
      else clearLockTimer()
    } else {
      isLocked.value = false
      resetLockTimer()
    }
  }

  const addActivityListeners = () => {
    if (activityListenersActive) return
    activityListenersActive = true
    activityEvents.forEach(event => {
      document.addEventListener(event, updateActivity, { capture: true, passive: true })
    })
  }

  const removeActivityListeners = () => {
    if (!activityListenersActive) return
    activityListenersActive = false
    activityEvents.forEach(event => {
      document.removeEventListener(event, updateActivity, true)
    })
  }

  const destroy = () => {
    removeActivityListeners()
    if (visibilityChangeHandler) {
      document.removeEventListener('visibilitychange', visibilityChangeHandler)
      visibilityChangeHandler = null
    }
    if (storageChangeHandler) {
      window.removeEventListener('storage', storageChangeHandler)
      storageChangeHandler = null
    }
    clearLockTimer()
    hasPassword.value = false
  }

  const manualLock = () => {
    if (PasswordManager.hasPassword()) lockApp()
  }

  const initAfterPasswordSet = () => {
    hasPassword.value = PasswordManager.hasPassword()
    addActivityListeners()
    unlockApp()
  }

  onMounted(() => {
    checkLockStatus()
    visibilityChangeHandler = () => {
      if (document.visibilityState === 'visible') checkLockStatus()
    }
    document.addEventListener('visibilitychange', visibilityChangeHandler)
    storageChangeHandler = (e) => {
      if (e.key === PasswordManager.LOCK_STATE_KEY && e.newValue) {
        try {
          if (JSON.parse(e.newValue)?.isLocked) {
            lockApp(false) // 接收到的锁定不再回广播，避免标签页互相重复锁定。
            return
          }
        } catch { /* 无效的外部值不改变当前会话。 */ }
      }
      if (e.key === null || [
        PasswordManager.LOCK_STATE_KEY,
        PasswordManager.LAST_ACTIVITY_KEY,
        PasswordManager.PASSWORD_KEY
      ].includes(e.key)) checkLockStatus()
    }
    window.addEventListener('storage', storageChangeHandler)
  })

  onUnmounted(destroy)

  return {
    isLocked,
    remainingTime,
    hasPassword,
    lockApp: manualLock,
    unlockApp,
    checkLockStatus,
    initAfterPasswordSet,
    updateActivity,
    resetLockTimer
  }
}
