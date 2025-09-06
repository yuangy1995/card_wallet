<template>
    <div 
      ref="floatingButtons"
      class="floating-buttons" 
      v-if="showButtons"
      :style="{ left: position.x + 'px', top: position.y + 'px' }"
      @mousedown="startDrag"
    >
      <div class="drag-handle">
        <el-icon><Expand /></el-icon>
      </div>
      <div class="buttons-container">
        <el-tooltip content="锁定应用" placement="bottom">
          <el-button 
            class="floating-btn lock-btn"
            type="warning" 
            :icon="Lock" 
            circle 
            @click="lockApp"
          />
        </el-tooltip>
        
        <el-tooltip content="密码设置" placement="bottom">
          <el-button 
            class="floating-btn settings-btn"
            type="primary" 
            :icon="Setting" 
            circle 
            @click="showPasswordSettings"
          />
        </el-tooltip>
      </div>
    </div>
  </template>
  
  <script setup>
  import { computed, ref, onMounted, onUnmounted, watch, nextTick } from 'vue'
  import { Lock, Setting, Expand } from '@element-plus/icons-vue'
  import { PasswordManager } from '@/utils/passwordManager'
  
  const emit = defineEmits(['lock-app', 'show-password-settings'])
  
  const showButtons = computed(() => PasswordManager.hasPassword())
  
  // 拖拽相关状态
  const floatingButtons = ref(null)
  const position = ref({ x: 0, y: 20 }) // 默认顶部居中
  const isDragging = ref(false)
  const dragOffset = ref({ x: 0, y: 0 })
  
  // 初始化位置（顶部居中）
  const initPosition = () => {
    nextTick(() => {
      if (floatingButtons.value) {
        const rect = floatingButtons.value.getBoundingClientRect()
        position.value.x = (window.innerWidth - rect.width) / 2
      }
    })
  }
  
  // 开始拖拽
  const startDrag = (e) => {
    e.preventDefault()
    isDragging.value = true
    const rect = floatingButtons.value.getBoundingClientRect()
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
    const maxX = window.innerWidth - floatingButtons.value.offsetWidth
    const maxY = window.innerHeight - floatingButtons.value.offsetHeight
    
    position.value.x = Math.max(0, Math.min(newX, maxX))
    position.value.y = Math.max(0, Math.min(newY, maxY))
  }
  
  // 停止拖拽
  const stopDrag = () => {
    isDragging.value = false
    document.removeEventListener('mousemove', handleDrag)
    document.removeEventListener('mouseup', stopDrag)
  }
  
  // 监听窗口大小变化
  const handleResize = () => {
    if (floatingButtons.value) {
      const maxX = window.innerWidth - floatingButtons.value.offsetWidth
      const maxY = window.innerHeight - floatingButtons.value.offsetHeight
      
      position.value.x = Math.max(0, Math.min(position.value.x, maxX))
      position.value.y = Math.max(0, Math.min(position.value.y, maxY))
    }
  }
  
  // 监听showButtons变化，当显示时重新初始化位置
  watch(showButtons, (newValue) => {
    if (newValue) {
      nextTick(() => {
        initPosition()
      })
    }
  })
  
  onMounted(() => {
    window.addEventListener('resize', handleResize)
    initPosition()
  })
  
  onUnmounted(() => {
    window.removeEventListener('resize', handleResize)
    document.removeEventListener('mousemove', handleDrag)
    document.removeEventListener('mouseup', stopDrag)
  })
  
  const lockApp = () => {
    emit('lock-app')
  }
  
  const showPasswordSettings = () => {
    emit('show-password-settings')
  }
  </script>
  
  <style scoped>
  .floating-buttons {
    position: fixed;
    z-index: 50;
    background: rgba(255, 255, 255, 0.95);
    border-radius: 25px;
    padding: 8px 12px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255, 255, 255, 0.2);
    cursor: move;
    user-select: none;
  }
  
  .drag-handle {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 20px;
    color: #999;
    cursor: grab;
    margin-bottom: 5px;
  }
  
  .drag-handle:active {
    cursor: grabbing;
  }
  
  .buttons-container {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  
  .floating-btn {
    width: 40px;
    height: 40px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    transition: all 0.3s ease;
    cursor: pointer;
  }
  
  .floating-btn:hover {
    transform: translateY(-2px) scale(1.05);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
  }
  
  .lock-btn {
    background-color: #e6a23c;
    border-color: #e6a23c;
  }
  
  .lock-btn:hover {
    background-color: #d4931f;
    border-color: #d4931f;
  }
  
  .settings-btn {
    background-color: #409eff;
    border-color: #409eff;
  }
  
  .settings-btn:hover {
    background-color: #3a8ee6;
    border-color: #3a8ee6;
  }
  
  @media (max-width: 768px) {
    .floating-buttons {
      padding: 6px 10px;
    }
    
    .floating-btn {
      width: 36px;
      height: 36px;
    }
    
    .buttons-container {
      gap: 10px;
    }
  }
  </style>