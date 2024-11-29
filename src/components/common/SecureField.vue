<template>
  <div class="secure-container">
    <span class="secure-text">
      {{ formattedValue }}
    </span>
    <el-icon 
      class="secure-icon" 
      @click="toggleVisibility"
    >
      <component :is="isVisible ? 'Hide' : 'View'" />
    </el-icon>
  </div>
</template>

<script>
import { ref, computed, onUnmounted } from 'vue'
import { View, Hide } from '@element-plus/icons-vue'
import { ElNotification } from 'element-plus'

export default {
  name: 'SecureField',
  components: {
    View,
    Hide
  },
  props: {
    value: {
      type: String,
      required: true
    },
    type: {
      type: String,
      required: true,
      validator: (value) => ['cvv', 'cardNumber'].includes(value)
    },
    id: {
      type: String,
      required: true
    }
  },
  emits: ['visibility-change'],
  setup(props, { emit }) {
    const isVisible = ref(false)
    let timer = null

    const notic = (title, message, type, duration = 3000) => {
      ElNotification({
        title,
        message,
        type,
        duration
      })
    }

    const toggleVisibility = () => {
      if (timer) {
        clearTimeout(timer)
      }

      isVisible.value = !isVisible.value
      emit('visibility-change', { id: props.id, isVisible: isVisible.value })

      if (isVisible.value) {
        const fieldType = props.type === 'cvv' ? 'CVV' : '卡号'
        notic(`${fieldType}已显示`, `${fieldType}将在 30 秒后自动隐藏`, 'info')
        
        timer = setTimeout(() => {
          isVisible.value = false
          emit('visibility-change', { id: props.id, isVisible: false })
          notic(`${fieldType}已隐藏`, `${fieldType}已自动隐藏`, 'info', 2000)
        }, 30000)
      }
    }

    const formattedValue = computed(() => {
      if (!props.value) return ''

      if (props.type === 'cvv') {
        return isVisible.value ? props.value : '•••'
      } else {
        // 移除空格
        const number = props.value.replace(/\s/g, '')
        
        if (isVisible.value) {
          // 显示完整卡号，每4位加一个空格
          return number.replace(/(.{4})/g, '$1 ').trim()
        } else {
          // 遮蔽第4-12位，其他位正常显示，每4位加一个空格
          const masked = number.slice(0, 3) + '*********' + number.slice(12)
          return masked.replace(/(.{4})/g, '$1 ').trim()
        }
      }
    })

    onUnmounted(() => {
      if (timer) {
        clearTimeout(timer)
      }
    })

    return {
      isVisible,
      toggleVisibility,
      formattedValue
    }
  }
}
</script>

<style scoped>
.secure-container {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
}

.secure-icon {
  cursor: pointer;
  font-size: 16px;
  color: #409EFF;
  transition: color 0.3s;
}

.secure-icon:hover {
  color: #66b1ff;
}

.secure-text {
  font-family: monospace;
  letter-spacing: 1px;
}
</style>
