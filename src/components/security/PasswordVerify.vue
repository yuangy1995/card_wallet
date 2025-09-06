<template>
  <div class="password-overlay" v-if="show">
    <div class="password-container">
      <div class="password-form">
        <h2>应用已锁定</h2>
        <p>请输入密码解锁</p>
        
        <el-form @submit.prevent="handleVerify">
          <el-form-item>
            <el-input
              v-model="password"
              type="password"
              placeholder="请输入密码"
              show-password
              size="large"
              @keyup.enter="handleVerify"
              ref="passwordInput"
            />
          </el-form-item>
          
          <el-form-item>
            <el-button 
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
</template>

<script setup>
import { ref, computed, nextTick, onMounted } from 'vue'
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

onMounted(() => {
  if (show.value) {
    nextTick(() => {
      passwordInput.value?.focus()
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
  background: rgba(0, 0, 0, 0.8);
  backdrop-filter: blur(10px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.password-container {
  background: white;
  border-radius: 12px;
  padding: 40px;
  min-width: 350px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
}

.password-form h2 {
  text-align: center;
  margin-bottom: 10px;
  color: #303133;
}

.password-form p {
  text-align: center;
  color: #909399;
  margin-bottom: 30px;
}

.links {
  text-align: center;
  margin-top: 20px;
}

.error-info {
  margin-top: 15px;
}
</style>