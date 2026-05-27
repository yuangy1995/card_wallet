<template>
  <el-dialog
    v-model="visible"
    :title="dialogTitle"
    width="400px"
    :close-on-click-modal="false"
    :close-on-press-escape="false"
    :show-close="canClose"
    :z-index="200003"
    center
    @close="handleClose"
  >
    <div class="password-setup">
      <el-alert
        class="password-setup-alert"
        :title="alertMessage"
        type="info"
        :closable="false"
        show-icon
      />
      
      <el-form ref="formRef" :model="form" :rules="rules" label-width="80px">
        <el-form-item label="新密码" prop="password">
          <el-input
            v-model="form.password"
            type="password"
            placeholder="请输入至少6位数密码"
            show-password
            autocomplete="new-password"
          />
        </el-form-item>
        
        <el-form-item label="确认密码" prop="confirmPassword">
          <el-input
            v-model="form.confirmPassword"
            type="password"
            placeholder="请再次输入密码"
            show-password
            autocomplete="new-password"
          />
        </el-form-item>
      </el-form>

      <div v-if="hasPassword" class="platform-unlock-section">
        <div class="platform-unlock-copy">
          <div class="platform-unlock-title">系统解锁</div>
          <div class="platform-unlock-desc">
            可使用本机指纹、人脸、PIN 或 Windows Hello 解锁。此设置只在当前浏览器和当前设备生效。
          </div>
          <div v-if="!platformUnlockAvailable" class="platform-unlock-status">
            当前浏览器或设备暂不支持
          </div>
        </div>
        <el-switch
          v-model="platformUnlockEnabled"
          :disabled="!platformUnlockAvailable || platformUnlockBusy"
          :loading="platformUnlockBusy"
          @change="handlePlatformUnlockChange"
        />
      </div>
      
      <div class="button-group" :class="{ 'single-action': !canClose }">
        <el-button 
          class="password-action-btn"
          type="primary" 
          @click="handleSetPassword"
          :loading="loading"
        >
          {{ buttonText }}
        </el-button>
        
        <el-button 
          v-if="canClose"
          class="password-action-btn"
          @click="handleClose"
        >
          取消
        </el-button>
      </div>
    </div>
  </el-dialog>
</template>

<script setup>
import { ref, reactive, computed, watch, inject, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { PasswordManager } from '@/utils/passwordManager'
import { PlatformAuthenticator } from '@/utils/platformAuthenticator'
import { useAutoLock } from '@/composables/useAutoLock'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['update:modelValue', 'password-set'])

const providedAutoLock = inject('autoLock', null)
const { isLocked, resetLockTimer } = providedAutoLock || useAutoLock()
const formRef = ref(null)
const loading = ref(false)
const platformUnlockAvailable = ref(false)
const platformUnlockEnabled = ref(false)
const platformUnlockBusy = ref(false)

const form = reactive({
  password: '',
  confirmPassword: ''
})

// 检查是否已有密码
const hasPassword = computed(() => PasswordManager.hasPassword())

// 是否可以关闭对话框
const canClose = computed(() => hasPassword.value)

// 动态标题
const dialogTitle = computed(() => 
  hasPassword.value ? '重新设置应用密码' : '设置应用密码'
)

// 动态提示信息
const alertMessage = computed(() => 
  hasPassword.value 
    ? '重新设置新的应用密码以增强安全性' 
    : '为了保护您的信用卡数据安全，请设置应用密码'
)

// 动态按钮文本
const buttonText = computed(() => 
  hasPassword.value ? '更新密码' : '设置密码'
)

// 验证规则
const rules = {
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码至少需要6位数', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请确认密码', trigger: 'blur' },
    {
      validator: (rule, value, callback) => {
        if (value !== form.password) {
          callback(new Error('两次输入的密码不一致'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ]
}

const visible = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value)
})

const refreshPlatformUnlockState = async () => {
  platformUnlockEnabled.value = PlatformAuthenticator.isStored()
  platformUnlockAvailable.value = await PlatformAuthenticator.isAvailable()
}

const getPlatformUnlockErrorMessage = (error) => {
  if (error?.name === 'NotAllowedError') {
    return '未完成本机身份验证，已取消开启'
  }
  if (error?.name === 'SecurityError') {
    return '当前页面环境不支持系统解锁，请使用 HTTPS 访问'
  }
  return error?.message || '系统解锁设置失败'
}

// 监听自动锁定状态，如果锁定则关闭对话框
watch(isLocked, (locked) => {
  if (locked && visible.value) {
    visible.value = false
  }
})

// 关闭对话框
const handleClose = () => {
  if (canClose.value) {
    form.password = ''
    form.confirmPassword = ''
    visible.value = false
  }
}

const handlePlatformUnlockChange = async (enabled) => {
  platformUnlockBusy.value = true
  try {
    if (enabled) {
      await PlatformAuthenticator.register()
      platformUnlockEnabled.value = true
      ElMessage.success({ message: '系统解锁已开启', zIndex: 200010 })
    } else {
      PlatformAuthenticator.disable()
      platformUnlockEnabled.value = false
      ElMessage.success({ message: '系统解锁已关闭', zIndex: 200010 })
    }
  } catch (error) {
    platformUnlockEnabled.value = PlatformAuthenticator.isStored()
    ElMessage.error({ message: getPlatformUnlockErrorMessage(error), zIndex: 200010 })
  } finally {
    platformUnlockBusy.value = false
  }
}

// 设置密码
const handleSetPassword = async () => {
  try {
    const valid = await formRef.value.validate()
    if (!valid) return

    loading.value = true
    
    const wasExistingPassword = hasPassword.value
    PasswordManager.setAppPassword(form.password)
    
    ElMessage.success({ message: wasExistingPassword ? '密码更新成功' : '密码设置成功', zIndex: 200010 })
    
    // 清空表单
    form.password = ''
    form.confirmPassword = ''
    
    // 通知父组件
    emit('password-set')
    resetLockTimer()
    visible.value = false
    
  } catch (error) {
    ElMessage.error({ message: error.message || '密码设置失败', zIndex: 200010 })
  } finally {
    loading.value = false
  }
}

watch(visible, (opened) => {
  if (opened) {
    refreshPlatformUnlockState()
  }
})

onMounted(() => {
  refreshPlatformUnlockState()
})
</script>

<style scoped>
.password-setup {
  padding: 10px 0;
}

.password-setup-alert {
  margin-bottom: 20px;
}

.password-setup :deep(.password-setup-alert.el-alert) {
  background: rgba(86, 114, 190, 0.08);
  border: 1px solid rgba(86, 114, 190, 0.18);
  color: #334155;
  border-radius: 8px;
}

.password-setup :deep(.password-setup-alert .el-alert__title) {
  color: #334155;
  line-height: 1.5;
}

.password-setup :deep(.password-setup-alert .el-alert__icon) {
  color: #007780;
}

.platform-unlock-section {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-top: 18px;
  padding: 14px 16px;
  border: 1px solid rgba(86, 114, 190, 0.18);
  border-radius: 10px;
  background: rgba(86, 114, 190, 0.06);
}

.platform-unlock-copy {
  min-width: 0;
}

.platform-unlock-title {
  color: #1e293b;
  font-weight: 700;
  margin-bottom: 4px;
}

.platform-unlock-desc {
  color: #64748b;
  font-size: 12px;
  line-height: 1.5;
}

.platform-unlock-status {
  color: #d97706;
  font-size: 12px;
  margin-top: 6px;
}

.button-group {
  margin-top: 20px;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
}

.button-group.single-action {
  justify-content: stretch;
}

.password-action-btn {
  flex: 1 1 0;
  margin-left: 0 !important;
}

.button-group.single-action .password-action-btn {
  width: 100%;
}

:deep(.el-dialog__header) {
  text-align: center;
  border-bottom: 1px solid #eee;
  padding-bottom: 15px;
}

:deep(.el-dialog__body) {
  padding-top: 20px;
}

:global(.dark) .password-setup :deep(.password-setup-alert.el-alert) {
  background: rgba(15, 23, 42, 0.72);
  border-color: rgba(0, 242, 254, 0.20);
}

:global(.dark) .password-setup :deep(.password-setup-alert .el-alert__title) {
  color: rgba(226, 232, 240, 0.84);
}

:global(.dark) .password-setup :deep(.password-setup-alert .el-alert__icon) {
  color: rgba(0, 242, 254, 0.78);
}

:global(.dark) .platform-unlock-section {
  background: rgba(15, 23, 42, 0.54);
  border-color: rgba(0, 242, 254, 0.18);
}

:global(.dark) .platform-unlock-title {
  color: rgba(241, 245, 249, 0.92);
}

:global(.dark) .platform-unlock-desc {
  color: rgba(203, 213, 225, 0.70);
}

:global(.dark) .platform-unlock-status {
  color: rgba(248, 217, 138, 0.92);
}

@media (max-width: 520px) {
  .button-group {
    flex-direction: column;
  }

  .password-action-btn {
    width: 100%;
  }
}
</style>
