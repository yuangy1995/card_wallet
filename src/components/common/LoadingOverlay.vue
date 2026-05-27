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
            color="var(--app-loading-spinner-color, #409eff)"
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
  background: var(--app-loading-mask-bg, rgba(248, 250, 252, 0.72));
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  backdrop-filter: blur(8px) saturate(110%);
  -webkit-backdrop-filter: blur(8px) saturate(110%);
  
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
    background: var(--app-loading-card-bg, var(--el-bg-color-overlay, #ffffff));
    border: 1px solid var(--app-loading-card-border, var(--el-border-color-lighter));
    border-radius: 12px;
    box-shadow: var(--app-loading-card-shadow, 0 14px 36px rgba(15, 23, 42, 0.14));
    
    @media (max-width: 480px) {
      padding: 1.5rem;
      margin: 1rem;
    }
    
    .loading-spinner {
      color: var(--app-loading-spinner-color, #409eff);
      animation: spin 1s linear infinite;
    }
    
    .loading-text {
      margin: 1rem 0 0 0;
      color: var(--app-loading-text-color, var(--el-text-color-regular));
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
        color: var(--app-loading-text-color, var(--el-text-color-secondary));
      }
    }
  }
}

:global(html.dark) .loading-overlay {
  background: var(--app-loading-mask-bg, rgba(3, 7, 18, 0.78));

  .loading-content {
    background: var(--app-loading-card-bg, rgba(15, 23, 42, 0.96));
    border-color: var(--app-loading-card-border, rgba(0, 242, 254, 0.22));
    box-shadow: var(--app-loading-card-shadow, 0 20px 54px rgba(0, 0, 0, 0.55));
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
