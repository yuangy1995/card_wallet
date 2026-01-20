<template>
  <span class="auto-lock-countdown" v-if="shouldShowCountdown">
    <el-icon class="countdown-icon"><Clock /></el-icon>
    <span class="countdown-text">系统将在 {{ formatTime(remainingTime) }} 后自动锁定</span>
  </span>
</template>

<script setup>
import { computed, inject } from 'vue'
import { Clock } from '@element-plus/icons-vue'
import { useAutoLock } from '@/composables/useAutoLock'
import { PasswordManager } from '@/utils/passwordManager'

const providedAutoLock = inject('autoLock', null)
const { isLocked, remainingTime } = providedAutoLock || useAutoLock()

// 是否显示倒计时
const shouldShowCountdown = computed(() => {
  return PasswordManager.hasPassword() && 
         !isLocked.value && 
         remainingTime.value > 0
})

// 格式化时间显示
const formatTime = (seconds) => {
  if (seconds <= 0) return '0分0秒'
  
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = seconds % 60
  
  if (minutes > 0) {
    return `${minutes}分${remainingSeconds}秒`
  } else {
    return `${remainingSeconds}秒`
  }
}
</script>

<style scoped>
.auto-lock-countdown {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: #c47a1c;
  font-size: 12px;
  white-space: nowrap;
}

.countdown-icon {
  font-size: 15px;
  color: #c47a1c;
}

.countdown-text {
  font-weight: 500;
  color: #c47a1c;
}
</style>
