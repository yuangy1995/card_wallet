<template>
  <div class="theme-toggle">
    <el-switch
      v-model="isDarkMode"
      :active-icon="Moon"
      :inactive-icon="Sunny"
      active-text="深色"
      inactive-text="浅色"
      @change="handleThemeChange"
      size="large"
      inline-prompt
    />
  </div>
</template>

<script>
import { computed } from 'vue'
import { Moon, Sunny } from '@element-plus/icons-vue'
import { useGlobalTheme } from '@/composables/useTheme'

export default {
  name: 'ThemeToggle',
  components: {
    Moon,
    Sunny
  },
  setup() {
    try {
      const { isDarkMode, toggleTheme } = useGlobalTheme()

      const handleThemeChange = () => {
        if (toggleTheme) {
          toggleTheme()
        } else {
          console.error('toggleTheme is not available')
        }
      }

      return {
        isDarkMode,
        handleThemeChange,
        Moon,
        Sunny
      }
    } catch (error) {
      console.warn('Theme initialization failed:', error)
      return {
        isDarkMode: false,
        handleThemeChange: () => {},
        Moon,
        Sunny
      }
    }
  }
}
</script>

<style lang="scss" scoped>
.theme-toggle {
  display: flex;
  align-items: center;
  
  :deep(.el-switch) {
    --el-switch-on-color: #409eff;
    --el-switch-off-color: #dcdfe6;
  }

  // 深色模式下的样式调整
  :global(.dark) & {
    :deep(.el-switch) {
      --el-switch-off-color: #4c4d4f;
    }
  }
}
</style>
