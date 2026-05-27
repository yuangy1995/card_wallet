<template>
  <div class="security-lock-controls" v-if="showButtons">
    <el-button
      class="control-btn lock-btn"
      type="warning"
      :icon="Lock"
      circle
      aria-label="锁定应用"
      @click="lockApp"
    />

    <el-button
      class="control-btn settings-btn"
      type="primary"
      :icon="Setting"
      circle
      aria-label="密码设置"
      @click="showPasswordSettings"
    />
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { Lock, Setting } from '@element-plus/icons-vue'
import { PasswordManager } from '@/utils/passwordManager'

const emit = defineEmits(['lock-app', 'show-password-settings'])

const showButtons = computed(() => PasswordManager.hasPassword())

const lockApp = () => {
  emit('lock-app')
}

const showPasswordSettings = () => {
  emit('show-password-settings')
}
</script>

<style scoped lang="scss">
.security-lock-controls {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin-right: 8px; /* 与后面的主题切换按钮拉开精致间距 */
  
  @media (max-width: 768px) {
    margin-right: 0;
    margin-bottom: 0;
  }
}

.control-btn {
  width: 32px !important;
  height: 32px !important;
  padding: 0 !important;
  display: inline-flex !important;
  align-items: center !important;
  justify-content: center !important;
  transition: all 0.25s cubic-bezier(0.25, 0.8, 0.25, 1) !important;
  border: none !important;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.08) !important;
  cursor: pointer !important;
  
  :deep(.el-icon) {
    font-size: 14px !important;
  }

  &:hover {
    transform: translateY(-1px) scale(1.05) !important;
  }
}

/* 亮色模式下的精细按钮着色 */
.lock-btn {
  background-color: rgba(230, 162, 60, 0.15) !important;
  color: #e6a23c !important;
  
  &:hover {
    background-color: #e6a23c !important;
    color: #ffffff !important;
    box-shadow: 0 4px 12px rgba(230, 162, 60, 0.3) !important;
  }
}

.settings-btn {
  background-color: rgba(0, 168, 180, 0.12) !important;
  color: #007780 !important;
  
  &:hover {
    background-color: #007780 !important;
    color: #ffffff !important;
    box-shadow: 0 4px 12px rgba(0, 168, 180, 0.3) !important;
  }
}


@media (max-width: 768px) {
  .control-btn {
    width: 28px !important;
    height: 28px !important;
    
    :deep(.el-icon) {
      font-size: 12px !important;
    }
  }
}
</style>
