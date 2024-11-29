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
      
      if (!visible.value) {
        if (props.maskAll) {
          return '*'.repeat(props.value.length)
        }
        
        const start = props.maskStart
        const end = props.maskEnd || props.value.length
        return props.value.slice(0, start) + 
               '*'.repeat(end - start) + 
               props.value.slice(end)
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
