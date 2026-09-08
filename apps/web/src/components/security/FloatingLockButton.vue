<template>
  <div class="security-lock-flat-container" v-if="showButtons">
    <!-- 倒计时时间显示（仅在未锁定且有剩余时间时显示） -->
    <span class="lock-countdown" v-if="shouldShowCountdown">
      <el-icon class="clock-icon"><Clock /></el-icon>
      <span class="countdown-time">{{ formatTime(remainingTime) }}</span>
    </span>
    
    <div class="divider-line" v-if="shouldShowCountdown"></div>
    
    <!-- 立即锁定纯Icon触发按钮（无边框无背景圆圈，彻底扁平化） -->
    <el-button
      class="lock-btn-flat"
      :icon="Lock"
      aria-label="锁定应用"
      title="立即锁定应用"
      @click="lockApp"
    />
  </div>
</template>

<script setup>
import { computed, inject } from 'vue'
import { Lock, Clock } from '@element-plus/icons-vue'
import { PasswordManager } from '@/utils/passwordManager'
import { useAutoLock } from '@/composables/useAutoLock'

const emit = defineEmits(['lock-app'])

const providedAutoLock = inject('autoLock', null)
const { hasPassword, isLocked, remainingTime } = providedAutoLock || useAutoLock()

const showButtons = computed(() => hasPassword.value)

// 是否显示倒计时文字
const shouldShowCountdown = computed(() => {
  return hasPassword.value && !isLocked.value && remainingTime.value > 0
})

// 手动锁定
const lockApp = () => {
  emit('lock-app')
}

// 格式化时间显示（统一补零以保证文字等宽等长，从根本上防止颤抖抖动）
const formatTime = (seconds) => {
  if (seconds <= 0) return '00分00秒'
  
  const minutes = Math.floor(seconds / 60)
  const remainingSeconds = seconds % 60
  
  const mStr = String(minutes).padStart(2, '0')
  const sStr = String(remainingSeconds).padStart(2, '0')
  
  return `${mStr}分${sStr}秒`
}
</script>

<style scoped lang="scss">
.security-lock-flat-container {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  box-sizing: border-box;

  .lock-countdown {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 11px;
    font-weight: 700;
    color: #d97706; /* 统一沿用优雅琥珀黄 */
    user-select: none;
    
    .clock-icon {
      font-size: 12px;
      animation: rotateClock 12s linear infinite;
      color: #00a8b4;
    }
    
    .countdown-time {
      font-family: 'Outfit', 'Inter', monospace;
      font-variant-numeric: tabular-nums;
      font-feature-settings: "tnum" 1;
      display: inline-block;
      min-width: 4.8em;
      text-align: center;
    }
  }

  .divider-line {
    width: 1px;
    height: 12px;
    background-color: rgba(230, 162, 60, 0.2);
    flex-shrink: 0;
  }

  .lock-btn-flat {
    background: transparent !important;
    border: none !important;
    padding: 0 !important;
    width: 24px !important;
    height: 24px !important;
    min-height: auto !important;
    cursor: pointer !important;
    color: #64748b !important;
    transition: all 0.2s cubic-bezier(0.25, 0.8, 0.25, 1) !important;
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
    box-shadow: none !important;
    flex-shrink: 0;
    
    :deep(.el-icon) {
      font-size: 15px !important;
    }

    &:hover {
      transform: scale(1.15) !important;
      color: #e6a23c !important; /* 悬浮时变黄色，极致高对比度 */
    }
  }
}

/* ==========================================
   🌌 暗色太空舱安全锁覆写
   ========================================== */
:global(.dark) .security-lock-flat-container {
  .lock-countdown {
    color: #ffc400 !important;
    
    .clock-icon {
      color: #00f2fe !important;
    }
  }
  
  .divider-line {
    background-color: rgba(255, 196, 0, 0.15) !important;
  }
  
  .lock-btn-flat {
    color: rgba(255, 255, 255, 0.75) !important;
    
    &:hover {
      color: #ffc400 !important;
    }
  }
}

@keyframes rotateClock {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
