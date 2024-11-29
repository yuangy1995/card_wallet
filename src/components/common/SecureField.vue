<template>
  <div class="secure-field">
    <span class="secure-text">{{ displayValue }}</span>
    <el-icon class="secure-icon" @click="toggleVisibility">
      <component :is="visible ? Hide : View" />
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
    // 要显示的值
    value: {
      type: String,
      required: true
    },
    // 掩码起始位置
    maskStart: {
      type: Number,
      default: 0
    },
    // 掩码结束位置
    maskEnd: {
      type: Number,
      default: 0
    },
    // 是否全部掩码
    maskAll: {
      type: Boolean,
      default: false
    }
  },
  emits: ['visibility-change'],
  setup(props, { emit }) {
    const visible = ref(false)
    let timer = null

    // 显示值的计算属性
    const displayValue = computed(() => {
      if (!props.value) return ''
      
      if (visible.value) {
        return props.value
      }
      
      if (props.maskAll) {
        return '*'.repeat(props.value.length)
      }
      
      const valueArray = props.value.split('')
      for (let i = props.maskStart; i < props.maskEnd && i < valueArray.length; i++) {
        valueArray[i] = '*'
      }
      return valueArray.join('')
    })

    // 切换可见性
    const toggleVisibility = () => {
      visible.value = !visible.value
      emit('visibility-change', visible.value)
      
      // 显示提示
      ElNotification({
        title: visible.value ? '已显示' : '已隐藏',
        message: visible.value ? '30秒后将自动隐藏' : '',
        type: 'info',
        duration: 3000
      })
      
      // 如果显示，30秒后自动隐藏
      if (visible.value) {
        clearTimeout(timer)
        timer = setTimeout(() => {
          visible.value = false
          emit('visibility-change', false)
          ElNotification({
            title: '已自动隐藏',
            type: 'info',
            duration: 3000
          })
        }, 30000)
      } else {
        clearTimeout(timer)
      }
    }

    // 组件卸载时清除定时器
    onUnmounted(() => {
      clearTimeout(timer)
    })

    return {
      visible,
      displayValue,
      toggleVisibility,
      View,
      Hide
    }
  }
}
</script>

<style scoped>
.secure-field {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.secure-text {
  font-family: monospace;
}

.secure-icon {
  cursor: pointer;
  color: var(--el-text-color-secondary);
  transition: color 0.2s;
  font-size: 16px;
}

.secure-icon:hover {
  color: var(--el-text-color-primary);
}
</style>
