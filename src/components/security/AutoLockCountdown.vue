<template>
  <div 
    ref="countdownEl"
    class="auto-lock-countdown" 
    v-if="shouldShowCountdown"
    :style="{ left: position.x + 'px', top: position.y + 'px' }"
    @mousedown="startDrag"
  >
    <div class="drag-handle">
      <el-icon><Expand /></el-icon>
    </div>
    <div class="countdown-content">
      <el-icon class="countdown-icon"><Clock /></el-icon>
      <span class="countdown-text">
        系统将在 {{ formatTime(remainingTime) }} 后自动锁定
      </span>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, onMounted, onUnmounted, nextTick } from 'vue'
import { Clock, Expand } from '@element-plus/icons-vue'
import { useAutoLock } from '@/composables/useAutoLock'
import { PasswordManager } from '@/utils/passwordManager'

const { isLocked, remainingTime } = useAutoLock()

// 拖拽相关状态
const countdownEl = ref(null)
const position = ref({ x: 20, y: 20 }) // 默认左上角
const isDragging = ref(false)
const dragOffset = ref({ x: 0, y: 0 })

// 开始拖拽
const startDrag = (e) => {
  e.preventDefault()
  isDragging.value = true
  const rect = countdownEl.value.getBoundingClientRect()
  dragOffset.value = {
    x: e.clientX - rect.left,
    y: e.clientY - rect.top
  }
  document.addEventListener('mousemove', handleDrag)
  document.addEventListener('mouseup', stopDrag)
}

// 拖拽中
const handleDrag = (e) => {
  if (!isDragging.value) return
  
  const newX = e.clientX - dragOffset.value.x
  const newY = e.clientY - dragOffset.value.y
  
  // 限制在窗口范围内
  const maxX = window.innerWidth - countdownEl.value.offsetWidth
  const maxY = window.innerHeight - countdownEl.value.offsetHeight
  
  position.value.x = Math.max(0, Math.min(newX, maxX))
  position.value.y = Math.max(0, Math.min(newY, maxY))
}

// 停止拖拽
const stopDrag = () => {
  isDragging.value = false
  document.removeEventListener('mousemove', handleDrag)
  document.removeEventListener('mouseup', stopDrag)
}

onMounted(() => {
  // 监听窗口大小变化，调整位置
  const handleResize = () => {
    if (countdownEl.value) {
      const maxX = window.innerWidth - countdownEl.value.offsetWidth
      const maxY = window.innerHeight - countdownEl.value.offsetHeight
      
      position.value.x = Math.max(0, Math.min(position.value.x, maxX))
      position.value.y = Math.max(0, Math.min(position.value.y, maxY))
    }
  }
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  document.removeEventListener('mousemove', handleDrag)
  document.removeEventListener('mouseup', stopDrag)
  window.removeEventListener('resize', handleResize)
})

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
  position: fixed;
  z-index: 1001;
  background: rgba(230, 162, 60, 0.1);
  border: 1px solid rgba(230, 162, 60, 0.3);
  border-radius: 16px;
  color: #e6a23c;
  font-size: 12px;
  white-space: nowrap;
  backdrop-filter: blur(4px);
  transition: all 0.3s ease;
  cursor: move;
  user-select: none;
  padding: 4px;
}

.auto-lock-countdown:hover {
  background: rgba(230, 162, 60, 0.15);
  border-color: rgba(230, 162, 60, 0.4);
}

.drag-handle {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 16px;
  color: #e6a23c;
  cursor: grab;
  margin-bottom: 2px;
}

.drag-handle:active {
  cursor: grabbing;
}

.countdown-content {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
}

.countdown-icon {
  font-size: 14px;
  color: #e6a23c;
}

.countdown-text {
  font-weight: 500;
  color: #e6a23c;
}

@media (max-width: 768px) {
  .auto-lock-countdown {
    font-size: 11px;
  }
  
  .countdown-content {
    padding: 4px 8px;
  }
  
  .countdown-icon {
    font-size: 12px;
  }
}
</style>
