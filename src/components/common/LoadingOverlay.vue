<template>
  <Transition name="loading-fade">
    <div v-if="visible" class="loading-overlay" :class="{ 'full-screen': fullScreen }">
      <div class="loading-content">
        <el-icon class="loading-spinner" :size="size">
          <Loading />
        </el-icon>
        <p v-if="text" class="loading-text">{{ text }}</p>
        <div v-if="progress !== null" class="loading-progress">
          <el-progress 
            :percentage="progress" 
            :stroke-width="6"
            :show-text="false"
            color="#409eff"
          />
          <span class="progress-text">{{ progress }}%</span>
        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { Loading } from '@element-plus/icons-vue'

defineProps({
  visible: {
    type: Boolean,
    default: false
  },
  text: {
    type: String,
    default: '加载中...'
  },
  fullScreen: {
    type: Boolean,
    default: false
  },
  size: {
    type: Number,
    default: 40
  },
  progress: {
    type: Number,
    default: null
  }
})
</script>

<style lang="scss" scoped>
.loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(255, 255, 255, 0.9);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  backdrop-filter: blur(2px);
  
  &.full-screen {
    position: fixed;
    z-index: 2000;
  }
  
  .loading-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    padding: 2rem;
    background: white;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    
    @media (max-width: 480px) {
      padding: 1.5rem;
      margin: 1rem;
    }
    
    .loading-spinner {
      color: #409eff;
      animation: spin 1s linear infinite;
    }
    
    .loading-text {
      margin: 1rem 0 0 0;
      color: #606266;
      font-size: 14px;
      
      @media (max-width: 480px) {
        font-size: 13px;
      }
    }
    
    .loading-progress {
      margin-top: 1rem;
      width: 200px;
      
      @media (max-width: 480px) {
        width: 150px;
      }
      
      .progress-text {
        display: block;
        margin-top: 0.5rem;
        font-size: 12px;
        color: #909399;
      }
    }
  }
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.loading-fade-enter-active,
.loading-fade-leave-active {
  transition: opacity 0.3s ease;
}

.loading-fade-enter-from,
.loading-fade-leave-to {
  opacity: 0;
}
</style>
