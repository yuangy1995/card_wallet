<template>
  <el-dialog
    v-model="visible"
    :title="dialogTitle"
    width="400px"
    :close-on-click-modal="false"
    :close-on-press-escape="false"
    :show-close="canClose"
    center
    @close="handleClose"
  >
    <div class="password-setup">
      <el-alert
        :title="alertMessage"
        type="info"
        :closable="false"
        show-icon
        style="margin-bottom: 20px"
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
      
      <div class="button-group">
        <el-button 
          type="primary" 
          @click="handleSetPassword"
          :loading="loading"
          style="width: 100%"
        >
          {{ buttonText }}
        </el-button>
        
        <el-button 
          v-if="canClose"
          @click="handleClose"
          style="width: 100%; margin-top: 10px"
        >
          取消
        </el-button>
      </div>
    </div>
  </el-dialog>
</template>

<script setup>
import { ref, reactive, computed, watch, inject } from 'vue'
import { ElMessage } from 'element-plus'
import { PasswordManager } from '@/utils/passwordManager'
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

// 设置密码
const handleSetPassword = async () => {
  try {
    const valid = await formRef.value.validate()
    if (!valid) return

    loading.value = true
    
    // 设置密码
    PasswordManager.setAppPassword(form.password)
    
    ElMessage.success(hasPassword.value ? '密码更新成功' : '密码设置成功')
    
    // 清空表单
    form.password = ''
    form.confirmPassword = ''
    
    // 通知父组件
    emit('password-set')
    resetLockTimer()
    visible.value = false
    
  } catch (error) {
    ElMessage.error(error.message || '密码设置失败')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.password-setup {
  padding: 10px 0;
}

.button-group {
  margin-top: 20px;
}

:deep(.el-dialog__header) {
  text-align: center;
  border-bottom: 1px solid #eee;
  padding-bottom: 15px;
}

:deep(.el-dialog__body) {
  padding-top: 20px;
}
</style>
