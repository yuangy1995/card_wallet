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
    },
    // 字段类型
    type: {
      type: String,
      required: true
    },
    // 记录ID
    id: {
      type: [String, Number],
      required: true
    }
  },
  emits: ['visibility-change'],
  setup(props, { emit }) {
    const visible = ref(false)
    let timer = null

    // 显示值的计算属性
    const displayValue = computed(() => {
      if (!props.value) return ''
      
      // 移除所有非数字字符
      const cleanValue = props.value.replace(/\D/g, '')
      
      if (!visible.value) {
        if (props.maskAll) {
          return '*'.repeat(cleanValue.length)
        }
        
        const start = props.maskStart
        const end = props.maskEnd || cleanValue.length
        
        // 对卡号进行分组显示
        if (props.type === 'cardNumber') {
          const visibleStart = cleanValue.slice(0, start)
          const masked = '*'.repeat(end - start)
          const visibleEnd = cleanValue.slice(end)
          
          // 将数字分成4个一组
          return (visibleStart + masked + visibleEnd).replace(/(.{4})/g, '$1 ').trim()
        }
        
        return cleanValue.slice(0, start) + 
               '*'.repeat(end - start) + 
               cleanValue.slice(end)
      }
      
      // 显示完整卡号时的格式化
      if (props.type === 'cardNumber') {
        return cleanValue.replace(/(.{4})/g, '$1 ').trim()
      }
      
      return props.value
    })

    // 切换可见性
    const toggleVisibility = () => {
      visible.value = !visible.value
      emit('visibility-change', { 
        id: props.id,
        type: props.type,
        isVisible: visible.value 
      })

      if (visible.value) {
        // 30秒后自动隐藏
        timer = setTimeout(() => {
          visible.value = false
          emit('visibility-change', { 
            id: props.id,
            type: props.type,
            isVisible: false 
          })
        }, 30000)
      } else if (timer) {
        clearTimeout(timer)
        timer = null
      }
    }

    // 组件销毁时清除定时器
    onUnmounted(() => {
      if (timer) {
        clearTimeout(timer)
        timer = null
      }
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
