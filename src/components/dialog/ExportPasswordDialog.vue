<template>
  <el-dialog
    v-model="dialogVisible"
    title="设置导出密码"
    width="30%"
    :close-on-click-modal="false"
    :close-on-press-escape="false"
    :show-close="false"
  >
    <div class="password-content">
      <el-alert
        type="info"
        :closable="false"
        show-icon
      >
        <p>为了保护您的数据安全，建议设置导出密码</p>
        <p>如果不需要设置密码，可以点击"跳过加密"</p>
      </el-alert>
      
      <el-form 
        ref="formRef"
        :model="form"
        :rules="rules"
        label-position="top"
      >
        <el-form-item 
          label="密码" 
          prop="password"
        >
          <el-input
            v-model="form.password"
            type="password"
            show-password
            placeholder="请输入密码（至少6个字符）"
          />
        </el-form-item>
        
        <el-form-item 
          label="确认密码" 
          prop="confirmPassword"
        >
          <el-input
            v-model="form.confirmPassword"
            type="password"
            show-password
            placeholder="请再次输入密码"
          />
        </el-form-item>
      </el-form>
    </div>

    <template #footer>
      <div class="dialog-footer">
        <el-button @click="handleSkip">跳过加密</el-button>
        <el-button type="primary" @click="handleConfirm">确认</el-button>
      </div>
    </template>
  </el-dialog>
</template>

<script>
import { ref, computed } from 'vue'

export default {
  name: 'ExportPasswordDialog',
  props: {
    visible: {
      type: Boolean,
      required: true
    }
  },
  emits: ['update:visible', 'confirm', 'skip'],
  setup(props, { emit }) {
    const formRef = ref(null)
    const form = ref({
      password: '',
      confirmPassword: ''
    })

    const dialogVisible = computed({
      get: () => props.visible,
      set: (value) => emit('update:visible', value)
    })

    const validateConfirmPassword = (rule, value, callback) => {
      if (value !== form.value.password) {
        callback(new Error('两次输入的密码不一致'))
      } else {
        callback()
      }
    }

    const rules = {
      password: [
        { required: true, message: '请输入密码', trigger: 'blur' },
        { min: 6, message: '密码长度不能小于6个字符', trigger: 'blur' }
      ],
      confirmPassword: [
        { required: true, message: '请再次输入密码', trigger: 'blur' },
        { validator: validateConfirmPassword, trigger: 'blur' }
      ]
    }

    const handleConfirm = () => {
      formRef.value.validate((valid) => {
        if (valid) {
          emit('confirm', form.value.password)
          dialogVisible.value = false
          form.value = {
            password: '',
            confirmPassword: ''
          }
        }
      })
    }

    const handleSkip = () => {
      emit('skip')
      dialogVisible.value = false
      form.value = {
        password: '',
        confirmPassword: ''
      }
    }

    return {
      dialogVisible,
      formRef,
      form,
      rules,
      validateConfirmPassword,
      handleConfirm,
      handleSkip
    }
  }
}
</script>

<style scoped>
.password-content {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

:deep(.el-alert) {
  margin-bottom: 8px;
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}
</style>
