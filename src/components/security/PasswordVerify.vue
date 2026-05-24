<template>
  <Teleport to="body">
  <div class="password-overlay" v-if="show">
    <div class="password-container">
      <div class="password-form">
        <h2>应用已锁定</h2>
        <p>请输入密码解锁</p>
        
        <el-form @submit.prevent="handleVerify">
          <!-- 伪装的输入框，用于欺骗和引诱浏览器的自动填充密码行为 -->
          <input type="text" name="prevent_autofill_username" style="position: absolute; opacity: 0; pointer-events: none; width: 0; height: 0;" tabindex="-1" />
          <input type="password" name="prevent_autofill_password" style="position: absolute; opacity: 0; pointer-events: none; width: 0; height: 0;" tabindex="-1" autocomplete="new-password" />
          
          <el-form-item>
            <el-input
              v-model="password"
              type="password"
              placeholder="请输入密码"
              show-password
              size="large"
              autocomplete="new-password"
              @keyup.enter="handleVerify"
              ref="passwordInput"
            />
          </el-form-item>
          
          <el-form-item>
            <el-button 
              class="unlock-btn"
              type="primary" 
              @click="handleVerify"
              :loading="loading"
              size="large"
              style="width: 100%"
            >
              解锁
            </el-button>
          </el-form-item>
        </el-form>
        
        <div class="links">
          <el-button text type="primary" @click="showForgotPassword">
            忘记密码？
          </el-button>
        </div>
        
        <div v-if="failedAttempts > 0" class="error-info">
          <el-alert
            :title="`密码错误 ${failedAttempts} 次${failedAttempts >= 5 ? '，请稍后再试' : ''}`"
            type="warning"
            :closable="false"
          />
        </div>
      </div>
    </div>
  </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, nextTick, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { PasswordManager } from '@/utils/passwordManager'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['update:modelValue', 'verified', 'forgot-password'])

const password = ref('')
const loading = ref(false)
const passwordInput = ref(null)

const show = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value)
})

const failedAttempts = computed(() => PasswordManager.getFailedAttempts())

const handleVerify = async () => {
  if (!password.value.trim()) {
    ElMessage.warning({
      message: '请输入密码',
      zIndex: 100000
    })
    return
  }

  if (PasswordManager.isTemporarilyLocked()) {
    ElMessage.error({
      message: '尝试次数过多，请稍后再试',
      zIndex: 100000
    })
    return
  }

  loading.value = true
  
  try {
    const isValid = PasswordManager.verifyPassword(password.value)
    
    if (isValid) {
      ElMessage.success({
        message: '解锁成功',
        zIndex: 100000
      })
      password.value = ''
      emit('verified')
    } else {
      ElMessage.error({
        message: '密码错误',
        zIndex: 100000
      })
      password.value = ''
      
      nextTick(() => {
        passwordInput.value?.focus()
      })
    }
  } catch (error) {
    ElMessage.error({
      message: '验证失败',
      zIndex: 100000
    })
    console.error('密码验证错误:', error)
  } finally {
    loading.value = false
  }
}

const showForgotPassword = () => {
  emit('forgot-password')
}

watch(show, (val) => {
  if (val) {
    password.value = ''
    nextTick(() => {
      passwordInput.value?.focus()
      setTimeout(() => {
        password.value = ''
        passwordInput.value?.focus()
      }, 50)
    })
  }
})
</script>

<style scoped>
.password-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(86, 114, 190, 0.4); /* 完美融入亮色温和靛蓝科技底色 #5672be 的半透明 */
  backdrop-filter: blur(12px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 200000;
  transition: all 0.3s ease;
}

.password-container {
  background: #ffffff; /* 完美融合亮色 100% 不透明纯白色卡片 */
  border-radius: 16px;
  padding: 40px;
  min-width: 380px;
  border: 1px solid rgba(226, 232, 240, 0.8);
  box-shadow: 0 20px 40px rgba(15, 23, 42, 0.06);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.password-form h2 {
  text-align: center;
  margin-bottom: 10px;
  color: #1e293b; /* 亮色优雅字 */
  font-weight: 700;
  font-size: 22px;
  letter-spacing: 0.05em;
  transition: all 0.3s ease;
}

.password-form p {
  text-align: center;
  color: #64748b;
  margin-bottom: 30px;
  font-size: 14px;
  transition: all 0.3s ease;
}

/* 亮色模式表单表项细节 */
.password-form :deep(.el-input__wrapper) {
  background-color: #f8fafc !important;
  border: 1px solid #cbd5e1 !important;
  box-shadow: none !important;
  border-radius: 6px !important;
  transition: background-color 0.25s ease, border-color 0.25s ease, box-shadow 0.25s ease !important;
}

.password-form :deep(.el-input__wrapper.is-focus) {
  border-color: #00a8b4 !important; /* 100% 对应亮色极客蓝 primary 色值 */
  box-shadow: 0 0 8px rgba(0, 168, 180, 0.25) !important;
  background-color: #ffffff !important;
}

.password-form :deep(.unlock-btn) {
  background: #00a8b4 !important; /* 100% 对应亮色极客蓝 */
  border: none !important;
  box-shadow: 0 4px 10px rgba(0, 168, 180, 0.2) !important;
  color: #ffffff !important;
  font-weight: 600;
  border-radius: 6px !important;
  transition: all 0.25s cubic-bezier(0.25, 0.8, 0.25, 1) !important;
}

.password-form :deep(.unlock-btn:hover) {
  background: #008f99 !important;
  box-shadow: 0 4px 14px rgba(0, 168, 180, 0.3) !important;
  transform: translateY(-1px);
}

.links {
  text-align: center;
  margin-top: 20px;
}

.links :deep(.el-button) {
  font-weight: 500;
  color: #00a8b4 !important;
  background: transparent !important;
  border: none !important;
  box-shadow: none !important;
  transition: all 0.3s ease;
}

.links :deep(.el-button:hover) {
  color: #008f99 !important;
  background: transparent !important;
}

.error-info {
  margin-top: 15px;
}

/* ==========================================
   🌌 极客霓虹暗黑科技风锁屏样式映射
   100% 忠实复刻项目原生暗色配色系统与组件定义
   ========================================== */
:global(.dark) {
  .password-overlay {
    background: rgba(7, 11, 25, 0.7) !important; /* 对应太空舱无垠深空蓝黑 #070b19 */
    backdrop-filter: blur(15px) !important;
  }

  .password-container {
    background: rgba(10, 15, 32, 0.85) !important; /* 完美复刻项目暗色 .el-dialog 背景色 */
    border: 1px solid rgba(0, 242, 254, 0.25) !important; /* 完美复刻项目暗色 .el-dialog 极光青边框 */
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6), 0 0 1px 1px rgba(0, 242, 254, 0.2) !important; /* 复刻项目暗色对话框极光青发光阴影 */
    backdrop-filter: blur(25px) saturate(180%) !important;
  }

  .password-form h2 {
    color: #00f2fe !important; /* 对应暗色极客霓虹主色（极光青） */
    text-shadow: 0 0 10px rgba(0, 242, 254, 0.4) !important;
  }

  .password-form p {
    color: var(--el-text-color-regular) !important; /* 对应常规文字色彩 #cbd2d9 */
  }

  /* 暗色模式表单表项细节 */
  .password-form :deep(.el-input__wrapper) {
    background-color: rgba(19, 25, 48, 0.5) !important; /* 完美对应 .el-form 输入框深色底 */
    border: 1px solid rgba(255, 255, 255, 0.08) !important;
    box-shadow: none !important;
  }

  .password-form :deep(.el-input__wrapper:hover) {
    border-color: rgba(0, 242, 254, 0.4) !important;
    background-color: rgba(19, 25, 48, 0.7) !important;
  }

  .password-form :deep(.el-input__wrapper.is-focus) {
    border-color: #00f2fe !important;
    box-shadow: 0 0 8px rgba(0, 242, 254, 0.25) !important;
    background-color: rgba(19, 25, 48, 0.85) !important;
  }

  /* 完美复刻 primary 按钮极客渐变色 */
  .password-form :deep(.unlock-btn) {
    border-color: rgba(0, 242, 254, 0.45) !important;
    background: linear-gradient(135deg, rgba(0, 242, 254, 0.25) 0%, rgba(218, 34, 255, 0.1) 100%) !important;
    box-shadow: none !important;
    color: var(--el-text-color-primary) !important; /* #f1f2f6 */
    font-weight: 600;
  }

  .password-form :deep(.unlock-btn:hover) {
    border-color: var(--el-color-primary) !important; /* #00f2fe */
    background: linear-gradient(135deg, rgba(0, 242, 254, 0.4) 0%, rgba(218, 34, 255, 0.2) 100%) !important;
    box-shadow: 0 0 15px rgba(0, 242, 254, 0.4), 0 0 30px rgba(218, 34, 255, 0.15) !important;
    transform: translateY(-2px);
  }

  .links :deep(.el-button) {
    color: #00f2fe !important;
    background: transparent !important;
    border: none !important;
    box-shadow: none !important;
  }

  .links :deep(.el-button:hover) {
    color: #33f5ff !important;
    background: transparent !important;
  }
}
</style>
