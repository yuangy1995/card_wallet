<template>
  <span class="auto-lock-countdown" v-if="shouldShowCountdown">
    <el-icon class="countdown-icon"><Clock /></el-icon>
    <span class="countdown-text">
      系统将在 <span class="time-highlight">{{ formatTime(remainingTime) }}</span> 后自动锁定
    </span>
  </span>
</template>

<script setup>
import { computed, inject } from 'vue'
import { Clock } from '@element-plus/icons-vue'
import { useAutoLock } from '@/composables/useAutoLock'
import { PasswordManager } from '@/utils/passwordManager'

const providedAutoLock = inject('autoLock', null)
const { isLocked, remainingTime, hasPassword } = providedAutoLock || useAutoLock()

// 是否显示倒计时
const shouldShowCountdown = computed(() => {
  return hasPassword.value && 
         !isLocked.value && 
         remainingTime.value > 0
})

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
.auto-lock-countdown {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 5px 14px;
  border-radius: 30px;
  font-size: 12px; /* 适度放大字号，提升可读性 */
  white-space: nowrap;
  position: relative;
  overflow: hidden;
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
  user-select: none;
  
  /* ----------------------------------------------------
     🔒 极致除颤：锁定物理宽度并启用等宽排版设计
     ---------------------------------------------------- */
  width: 194px; /* 固化物理总宽度，彻底消灭字符伸缩引起的抖动 */
  justify-content: center; /* 内容在固定宽度下精美居中 */
  
  /* ----------------------------------------------------
     💡 基于 CSS 变量的现代双主题设计系统（从根本上消灭优先级覆盖混乱）
     ---------------------------------------------------- */
  /* 默认亮色太空舱极客蓝小胶囊变量 */
  --countdown-bg: rgba(0, 168, 180, 0.06);
  --countdown-border: 1px solid rgba(0, 168, 180, 0.35);
  --countdown-shadow: 0 4px 15px rgba(86, 114, 190, 0.08), inset 0 1px 0 rgba(255, 255, 255, 0.6);
  --countdown-text-color: #1e293b; /* 亮色下清爽深灰色，绝对醒目 */
  --countdown-time-color: #d76a00; /* 高对比度暖橘色 */
  --countdown-icon-color: #00a8b4;
  --countdown-text-shadow: none; /* 亮色下无阴影，保持极度干净 */

  background: var(--countdown-bg) !important;
  border: var(--countdown-border) !important;
  box-shadow: var(--countdown-shadow) !important;
  color: var(--countdown-text-color) !important;
  animation: autoLockPulseLight 3.5s infinite ease-in-out;

  .countdown-icon {
    font-size: 14px;
    color: var(--countdown-icon-color) !important;
    animation: rotateClock 12s linear infinite;
    flex-shrink: 0;
  }

  .countdown-text {
    font-weight: 700; /* 强力加粗，解决字体纤细模糊问题 */
    color: var(--countdown-text-color) !important;
    text-shadow: var(--countdown-text-shadow) !important;
  }

  .time-highlight {
    font-weight: 850;
    color: var(--countdown-time-color) !important;
    padding: 0 2px;
    font-family: 'Outfit', 'Inter', monospace;
    font-size: 13px;
    text-shadow: var(--countdown-text-shadow) !important;

    /* 启用现代等宽数字排版，规避比例数字颤动 */
    font-variant-numeric: tabular-nums !important;
    font-feature-settings: "tnum" 1 !important;
    display: inline-block;
    min-width: 5.6em; /* 固化高亮区域的底层物理空间 */
    text-align: center;
  }

  /* 扫光炫酷光效 (Sweep Scan Light) */
  &::after {
    content: '';
    position: absolute;
    top: 0;
    left: -150%;
    width: 60%;
    height: 100%;
    background: linear-gradient(
      90deg,
      transparent,
      rgba(255, 255, 255, 0.45),
      transparent
    );
    transform: skewX(-20deg);
    animation: autoLockSweep 5.5s infinite ease-in-out;
  }
}

/* ==========================================================================
   🌌 暗黑太空舱高清晰极光霓虹变量覆写（100% 纯白亮色除噪）
   ========================================================================== */
:global(.dark) .auto-lock-countdown {
  --countdown-bg: rgba(13, 20, 41, 0.85);
  --countdown-border: 1px solid rgba(0, 242, 254, 0.35);
  --countdown-shadow: 0 4px 16px rgba(0, 242, 254, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.04);
  --countdown-text-color: #ffffff; /* 强行覆写为 100% 极纯净高亮白，杜绝灰色透底 */
  --countdown-time-color: #ffc400; /* 极致醒目的电光暖金黄 */
  --countdown-icon-color: #00f2fe;
  /* 彻底消灭 8px 模糊导致发虚的重影阴影，改用超薄高对比深黑底衬投影，强化字体边缘清晰度 */
  --countdown-text-shadow: 0 1px 2px rgba(0, 4, 15, 0.95);

  animation: autoLockPulseDark 3.5s infinite ease-in-out;

  &::after {
    background: linear-gradient(
      90deg,
      transparent,
      rgba(0, 242, 254, 0.25),
      rgba(255, 255, 255, 0.15),
      transparent
    ) !important;
  }
}

/* ==========================================================================
   ⚡ 动画特效定义 (已彻底剥离 transform: scale 以保证 100% 的除颤稳定性)
   ========================================================================== */
@keyframes autoLockSweep {
  0% {
    left: -150%;
  }
  35% {
    left: 150%;
  }
  100% {
    left: 150%;
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

@keyframes autoLockPulseLight {
  0%, 100% {
    border-color: rgba(0, 168, 180, 0.35);
    box-shadow: 0 4px 15px rgba(86, 114, 190, 0.08), inset 0 1px 0 rgba(255, 255, 255, 0.6);
  }
  50% {
    border-color: rgba(0, 168, 180, 0.65);
    box-shadow: 0 4px 20px rgba(86, 114, 190, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.6);
  }
}

@keyframes autoLockPulseDark {
  0%, 100% {
    border-color: rgba(0, 242, 254, 0.35);
    box-shadow: 0 4px 16px rgba(0, 242, 254, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.04);
  }
  50% {
    border-color: rgba(0, 242, 254, 0.65);
    box-shadow: 0 4px 22px rgba(0, 242, 254, 0.35), inset 0 1px 0 rgba(255, 255, 255, 0.04);
  }
}
</style>
