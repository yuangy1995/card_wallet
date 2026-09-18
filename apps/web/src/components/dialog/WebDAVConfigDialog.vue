<template>
  <el-dialog
    v-model="dialogVisible"
    title="云同步设置"
    width="500px"
    :close-on-click-modal="false"
    :append-to-body="true"
    :z-index="2001"
    draggable
  >
    <el-form
      ref="formRef"
      :model="form"
      :rules="rules"
      label-width="100px"
      class="webdav-form"
    >
      <el-form-item label="连接方式" prop="protocol">
        <el-radio-group v-model="form.protocol" @change="handleProtocolChange">
          <el-radio value="http">HTTP</el-radio>
          <el-radio value="https">HTTPS</el-radio>
        </el-radio-group>
      </el-form-item>
      
      <el-form-item label="云端地址" prop="host">
        <el-input
          v-model="form.host"
          placeholder="请输入域名或 IP 地址，如：example.com"
        />
      </el-form-item>
      
      <el-form-item label="端口" prop="port">
        <el-input-number
          v-model="form.port"
          :min="1"
          :max="65535"
          placeholder="端口号"
        />
      </el-form-item>
      
      <el-form-item label="存储路径" prop="path">
        <el-input
          v-model="form.path"
          placeholder="可选，如：/backup"
        >
          <template #prepend>/</template>
        </el-input>
      </el-form-item>

      <el-form-item label="账号" prop="username">
        <el-input
          v-model="form.username"
          placeholder="请输入账号"
        />
      </el-form-item>

      <el-form-item label="密码" prop="password">
        <el-input
          v-model="form.password"
          type="password"
          placeholder="请输入密码"
          show-password
        />
      </el-form-item>

      <el-form-item label="同步密钥" prop="syncPassword">
        <el-input
          v-model="form.syncPassword"
          type="password"
          placeholder="请输入云同步密钥"
          show-password
        />
        <div class="form-tip">
          三端必须使用同一个同步密钥。它用于加密 WebDAV 上的云同步文件，请单独妥善保存。
        </div>
      </el-form-item>


    </el-form>
    <template #footer>
      <span class="dialog-footer">
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="testConnection">测试连接</el-button>
        <el-button type="success" @click="saveConfig">保存设置</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, reactive, computed, inject, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { webdavClient } from '../../utils/webdav'
import { useAutoLock } from '@/composables/useAutoLock'

const dialogVisible = ref(false)
const formRef = ref(null)
const emit = defineEmits(['saved'])
const providedAutoLock = inject('autoLock', null)
const { isLocked } = providedAutoLock || useAutoLock()

const form = reactive({
  protocol: 'https',
  host: '',
  port: 443,
  path: '',
  username: '',
  password: '',
  syncPassword: '',
})

// 计算完整的URL
const fullUrl = computed(() => {
  let url = `${form.protocol}://${form.host}`
  if (form.port) {
    // 如果是默认端口，不添加端口号
    if (!(form.protocol === 'http' && form.port === 80) && 
        !(form.protocol === 'https' && form.port === 443)) {
      url += `:${form.port}`
    }
  }
  if (form.path) {
    // 确保路径以 / 开头
    url += form.path.startsWith('/') ? form.path : `/${form.path}`
  }
  return url
})

// 监听协议变化，自动切换默认端口
const handleProtocolChange = (protocol) => {
  if (form.port === 80 || form.port === 443) {
    form.port = protocol === 'https' ? 443 : 80
  }
  // 如果切换到 HTTP，关闭证书验证选项
  if (protocol === 'http') {
  }
}

const validateSyncPassword = (_rule, value, callback) => {
  const trimmedValue = String(value || '').trim()
  if (!trimmedValue) {
    callback(new Error('请输入云同步密钥'))
    return
  }
  if (trimmedValue.length < 10) {
    callback(new Error('同步密钥至少 10 位'))
    return
  }
  callback()
}

const rules = {
  protocol: [
    { required: true, message: '请选择连接方式', trigger: 'change' }
  ],
  host: [
    { required: true, message: '请输入云端地址', trigger: 'blur' },
    { pattern: /^[a-zA-Z0-9][-a-zA-Z0-9.]*[a-zA-Z0-9]$|^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/, message: '请输入有效的域名或IP地址', trigger: 'blur' }
  ],
  port: [
    { required: true, message: '请输入端口号', trigger: 'blur' },
    { type: 'number', min: 1, max: 65535, message: '端口号必须在1-65535之间', trigger: 'blur' }
  ],
  path: [
    { pattern: /^[/]?[a-zA-Z0-9/-_.]*$/, message: '路径格式不正确', trigger: 'blur' }
  ],
  username: [
    { required: true, message: '请输入账号', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' }
  ],
  syncPassword: [
    { validator: validateSyncPassword, trigger: 'blur' }
  ]
}

watch(isLocked, (locked) => {
  if (locked && dialogVisible.value) {
    dialogVisible.value = false
  }
})

// 加载已保存的配置
const loadSavedConfig = () => {
  const config = webdavClient.loadConfig()
  if (config) {
    try {
      // 解析已保存的URL
      const url = new URL(config.url)
      form.protocol = url.protocol.replace(':', '')
      form.host = url.hostname
      form.port = url.port ? parseInt(url.port) : (url.protocol === 'https:' ? 443 : 80)
      form.path = url.pathname
      form.username = config.username
      form.password = config.password
      form.syncPassword = config.syncPassword || ''
    } catch (error) {
      // 配置可能不完整或格式错误，忽略错误继续
    }
  }
}

// 测试连接
const testConnection = async () => {
  try {
    await formRef.value.validate()
    
    // 初始化客户端
    const initialized = await webdavClient.initialize({
      url: fullUrl.value,
      username: form.username,
      password: form.password,
      syncPassword: form.syncPassword.trim(),
    })

    if (!initialized) {
      ElMessage.error('初始化失败，请检查配置')
      return
    }

    // 测试连接
    const result = await webdavClient.testConnection()
    if (result.success) {
      ElMessage.success(result.message || '连接成功')
    } else {
      ElMessage.error(result.message || '连接失败，请检查服务器证书和跨域设置')
    }
  } catch (error) {
    ElMessage.error(error?.message ? `连接失败：${error.message}` : '表单验证失败，请检查输入')
  }
}

// 保存配置
const saveConfig = async () => {
  try {
    const valid = await formRef.value.validate()
    if (!valid) {
      return
    }

    const saved = await webdavClient.saveConfig({
      url: fullUrl.value,
      username: form.username,
      password: form.password,
      syncPassword: form.syncPassword.trim(),
    })

    if (saved) {
      ElMessage.success('云同步设置已保存')
      emit('saved')
      dialogVisible.value = false
    } else {
      ElMessage.error('保存配置失败，请检查浏览器本地存储权限')
      return false
    }
  } catch (error) {
    ElMessage.error('保存配置失败：' + error.message)
    return false
  }
}

// 显示对话框
const showDialog = () => {
  dialogVisible.value = true
  loadSavedConfig()
}

const closeDialog = () => {
  dialogVisible.value = false
}

defineExpose({
  showDialog,
  closeDialog
})
</script>

<style lang="scss" scoped>
.webdav-form {
  padding: 20px;
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

.form-tip {
  margin-top: 6px;
  color: var(--el-text-color-secondary);
  font-size: 12px;
  line-height: 1.5;
}

:deep(.el-input-number) {
  width: 100%;
}
</style>
