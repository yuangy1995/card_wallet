<template>
  <el-dialog
    v-model="visible"
    title="webdav云备份管理"
    width="600px"
    :close-on-click-modal="false"
    :append-to-body="true"
    :z-index="2000"
    draggable
    @closed="handleClosed"
  >
    <div class="backup-dialog">
      <div class="backup-header" v-if="!progressVisible">
        <el-button
          type="primary"
          @click="showBackupDialog"
          :disabled="!isConnected || loading"
        >
          创建备份
        </el-button>
        <div class="connection-status">
          <el-tag :type="isConnected ? 'success' : 'danger'" size="small">
            {{ isConnected ? '已连接' : '未连接' }}
          </el-tag>
        </div>
      </div>

      <div v-if="progressVisible" class="progress-container">
        <el-progress
          :percentage="progress"
          :status="progress === 100 ? 'success' : ''"
        />
        <div class="progress-text">{{ progressText }}</div>
      </div>

      <el-scrollbar height="400px" class="backup-list-container">
        <div v-loading="loading" class="backup-list">
          <template v-if="backupList.length > 0">
            <div
              v-for="backup in backupList"
              :key="backup.filename"
              class="backup-item"
            >
              <div class="backup-info">
                <div class="backup-name">{{ backup.filename }}</div>
                <div class="backup-meta">
                  <el-tag type="success" size="small">{{ formatDate(backup.lastmod) }}</el-tag>
                  <el-tag type="info" size="small">{{ formatSize(backup.size) }}</el-tag>
                </div>
              </div>
              <div class="backup-actions">
                <el-button
                  type="success"
                  size="small"
                  @click="handleRestore(backup)"
                  :loading="backup.restoring"
                  :disabled="!isConnected"
                >
                  恢复
                </el-button>
                <el-button
                  type="danger"
                  size="small"
                  @click="handleDelete(backup)"
                  :loading="backup.deleting"
                  :disabled="!isConnected"
                >
                  删除
                </el-button>
              </div>
            </div>
          </template>
          <el-empty v-else description="暂无备份" />
        </div>
      </el-scrollbar>
    </div>

    <template #footer>
      <span class="dialog-footer">
        <el-button @click="visible = false">关闭</el-button>
      </span>
    </template>
  </el-dialog>

  <!-- 创建备份对话框 -->
  <el-dialog
    v-model="backupDialogVisible"
    title="创建备份"
    width="400px"
    draggable
    append-to-body
  >
    <el-form :model="backupForm" label-width="80px" ref="backupFormRef">
      <el-form-item label="加密方式">
        <el-radio-group v-model="backupForm.useCustomPassword">
          <el-radio :label="false">默认加密</el-radio>
          <el-radio :label="true">自定义密码</el-radio>
        </el-radio-group>
      </el-form-item>
      <template v-if="backupForm.useCustomPassword">
        <el-form-item
          label="密码"
          prop="password"
          :rules="[
            { required: true, message: '请输入密码', trigger: 'blur' },
            { min: 6, message: '密码长度不能小于6位', trigger: 'blur' }
          ]"
        >
          <el-input
            v-model="backupForm.password"
            type="password"
            show-password
            placeholder="请输入密码"
          />
        </el-form-item>
        <el-form-item
          label="确认密码"
          prop="confirmPassword"
          :rules="[
            { required: true, message: '请再次输入密码', trigger: 'blur' },
            { validator: validatePassword, trigger: 'blur' }
          ]"
        >
          <el-input
            v-model="backupForm.confirmPassword"
            type="password"
            show-password
            placeholder="请再次输入密码"
          />
        </el-form-item>
      </template>
    </el-form>
    <template #footer>
      <span class="dialog-footer">
        <el-button @click="backupDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleBackupConfirm">确定</el-button>
      </span>
    </template>
  </el-dialog>

  <!-- 恢复备份密码输入对话框 -->
  <el-dialog
    v-model="restoreDialogVisible"
    title="输入密码"
    width="400px"
    draggable
    append-to-body
  >
    <el-form :model="restoreForm" label-width="80px">
      <el-form-item
        label="密码"
        prop="password"
        :rules="[{ required: true, message: '请输入密码', trigger: 'blur' }]"
      >
        <el-input
          v-model="restoreForm.password"
          type="password"
          show-password
          placeholder="请输入密码"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <span class="dialog-footer">
        <el-button @click="restoreDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleRestoreConfirm">确定</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { webdavClient } from '@/utils/webdav'
import { encryptData, decryptData } from '@/utils/encryption'
import { Delete, Download } from '@element-plus/icons-vue'

const emit = defineEmits(['update', 'showConfig'])
const visible = ref(false)
const loading = ref(false)
const backingUp = ref(false)
const backupList = ref([])
const cardData = ref([])
const isConnected = ref(false)  // 添加连接状态

// 备份表单相关
const backupDialogVisible = ref(false)
const backupFormRef = ref(null)
const backupForm = ref({
  useCustomPassword: false,
  password: '',
  confirmPassword: ''
})

// 恢复表单相关
const restoreDialogVisible = ref(false)
const restoreForm = ref({
  password: ''
})
const currentBackup = ref(null)

// 进度相关
const progressVisible = ref(false)
const progress = ref(0)
const progressStatus = ref('')
const currentOperation = ref('') // 新增：当前操作类型（'backup' 或 'restore'）

// 进度文本（computed）
const progressText = computed(() => {
  return currentOperation.value === 'backup' 
    ? `正在备份... ${progress.value}%`
    : `正在恢复... ${progress.value}%`
})

// 验证密码一致性
const validatePassword = (rule, value, callback) => {
  if (value !== backupForm.value.password) {
    callback(new Error('两次输入的密码不一致'))
  } else {
    callback()
  }
}

// 格式化日期
const formatDate = (date) => {
  if (!date) return '未知时间';
  const d = new Date(date);
  if (isNaN(d.getTime())) return '未知时间';
  return d.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
}

// 格式化文件大小
const formatSize = (bytes) => {
  if (bytes < 1024) return bytes + ' B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return (bytes / Math.pow(k, i)).toFixed(2) + ' ' + sizes[i]
}

// 加载备份列表
const loadBackupList = async () => {
  loading.value = true
  try {
    const result = await webdavClient.getBackupList()
    if (result.success) {
      backupList.value = result.data.map(item => ({
        ...item,
        restoring: false,
        deleting: false
      }))
      console.log(backupList)
    } else {
      ElMessage.error(result.message || '获取备份列表失败')
      isConnected.value = false  // 连接可能已断开
    }
  } catch (error) {
    ElMessage.error('加载备份列表失败：' + error.message)
  } finally {
    loading.value = false
  }
}

// 显示创建备份对话框
const showBackupDialog = () => {
  backupForm.value = {
    useCustomPassword: false,
    password: '',
    confirmPassword: ''
  }
  backupDialogVisible.value = true
}

// 创建备份
const handleBackupConfirm = async () => {
  backupDialogVisible.value = false
  if (backupForm.value.useCustomPassword) {
    try {
      await backupFormRef.value.validate()
    } catch (error) {
      return
    }
  }

  backingUp.value = true
  progressVisible.value = true
  progress.value = 0
  try {
    // 获取当前数据
    const data = {
      cards: cardData.value,
      categories: [], // 如果需要备份其他数据，可以在这里添加
      tags: []
    }

    // 加密数据
    const encryptedData = encryptData(
      data,
      backupForm.value.useCustomPassword ? backupForm.value.password : undefined
    )

    const result = await webdavClient.createBackup(encryptedData)
    if (result.success) {
      ElMessage.success(result.message)
      await loadBackupList()
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    ElMessage.error(error.message)
  } finally {
    backingUp.value = false
  }
}

// 恢复备份
const handleRestore = async (backup) => {
  try {
    await ElMessageBox.confirm(
      '恢复备份将覆盖当前所有数据，是否继续？',
      '警告',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    backup.restoring = true
    progressVisible.value = true
    progress.value = 0
    
    const result = await webdavClient.restoreBackup(backup.filename)
    if (result.success) {
      try {
        // 检查数据是否加密
        const content = result.data
        if (typeof content === 'string' && (content.startsWith('encrypted:') || content.startsWith('default:'))) {
          // 如果是默认加密，直接解密
          if (content.startsWith('default:')) {
            const decryptedData = decryptData(content)
            handleRestoreSuccess(decryptedData)
          } else {
            // 如果是自定义密码加密，显示密码输入对话框
            currentBackup.value = content
            restoreDialogVisible.value = true
          }
        } else {
          // 未加密数据直接使用
          handleRestoreSuccess(content)
        }
      } catch (error) {
        ElMessage.error('处理备份数据失败：' + error.message)
      }
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('恢复失败：' + error.message)
    }
  } finally {
    backup.restoring = false
    loading.value = false
  }
}

// 处理恢复成功
const handleRestoreSuccess = (data) => {
  try {
    // 如果是字符串，尝试解析 JSON
    const parsedData = typeof data === 'string' ? JSON.parse(data) : data
    
    // 更新数据
    cardData.value = parsedData.cards || []
    emit('update', cardData.value)
    ElMessage.success('数据恢复成功')
    
    // 关闭所有对话框
    restoreDialogVisible.value = false
    visible.value = false
    restoreForm.value.password = ''
  } catch (error) {
    ElMessage.error('解析备份数据失败：' + error.message)
  }
}

// 确认恢复（输入密码后）
const handleRestoreConfirm = async () => {
  if (!restoreForm.value.password) {
    ElMessage.warning('请输入密码')
    return
  }

  try {
    const decryptedData = decryptData(currentBackup.value, restoreForm.value.password)
    handleRestoreSuccess(decryptedData)
  } catch (error) {
    ElMessage.error('解密备份失败：' + error.message)
  }
}

// 删除备份
const handleDelete = async (backup) => {
  try {
    await ElMessageBox.confirm(
      '确定要删除这个备份吗？此操作不可恢复',
      '警告',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    backup.deleting = true
    loading.value = true
    const result = await webdavClient.deleteBackup(backup.filename)
    if (result.success) {
      ElMessage.success(result.message)
      await loadBackupList()
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error(error.message)
    }
  } finally {
    backup.deleting = false
    loading.value = false
  }
}

// 对话框关闭时的处理
const handleClosed = () => {
  backupList.value = []
  backupForm.value.password = ''
  backupForm.value.useCustomPassword = false
  restoreForm.value.password = ''
  backingUp.value = false
  progressVisible.value = false
  progress.value = 0
  isConnected.value = false  // 重置连接状态
}

// 打开对话框时加载备份列表
const open = async (data) => {
  cardData.value = data
  visible.value = true
  isConnected.value = false  // 重置连接状态
  
  try {
    // 检查 WebDAV 配置
    const config = await webdavClient.loadConfig()
    if (!config) {
      ElMessage.warning('未配置 WebDAV 服务器信息，请先配置')
      emit('showConfig')
      visible.value = false
      return
    }

    // 初始化 WebDAV 客户端
    if (!webdavClient.client) {
      const initialized = webdavClient.initialize(config)
      if (!initialized) {
        ElMessage.error('WebDAV 客户端初始化失败')
        emit('showConfig')
        visible.value = false
        return
      }
    }

    // 测试连接
    loading.value = true
    const result = await webdavClient.testConnection()
    if (result.success) {
      ElMessage.success('已成功连接到 WebDAV 服务器')
      isConnected.value = true  // 设置连接状态
      await loadBackupList()
    } else {
      ElMessage.error(result.message)
      emit('showConfig')
      visible.value = false
    }
  } catch (error) {
    ElMessage.error('连接 WebDAV 服务器失败：' + error.message)
    emit('showConfig')
    visible.value = false
  } finally {
    loading.value = false
  }
}

// 更新进度
const updateProgress = (type, value) => {
  progress.value = Math.round(value)
  progressStatus.value = value >= 100 ? 'success' : ''
  
  if (type === 'upload') {
    currentOperation.value = 'backup'
  } else {
    currentOperation.value = 'restore'
  }

  // 如果进度完成，延迟关闭进度对话框
  if (value >= 100) {
    setTimeout(() => {
      progressVisible.value = false
      progress.value = 0
      currentOperation.value = ''
    }, 500)
  }
}

// 在组件挂载时设置进度回调
import { onMounted } from 'vue'
onMounted(() => {
  webdavClient.setProgressCallback(updateProgress)
})

defineExpose({
  open
})
</script>

<style lang="scss" scoped>
.backup-dialog {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.backup-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 0 16px;
  border-bottom: 1px solid var(--el-border-color-lighter);
}

.backup-list-container {
  flex: 1;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
  background-color: var(--el-bg-color);
}

.backup-list {
  padding: 16px;
  min-height: 200px;
}

.backup-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  border-bottom: 1px solid var(--el-border-color-lighter);
  transition: background-color 0.2s;

  &:last-child {
    border-bottom: none;
  }

  &:hover {
    background-color: var(--el-fill-color-light);
  }
}

.backup-info {
  flex: 1;
  min-width: 0;
}

.backup-name {
  font-weight: 500;
  margin-bottom: 4px;
  color: var(--el-text-color-primary);
}

.backup-meta {
  font-size: 12px;
  color: var(--el-text-color-secondary);
  display: flex;
  gap: 12px;
}

.backup-actions {
  display: flex;
  gap: 8px;
  margin-left: 16px;
}

.progress-container {
  padding: 24px 0;
  text-align: center;

  .progress-text {
    margin-top: 8px;
    color: var(--el-text-color-secondary);
  }
}

.connection-status {
  margin-left: 16px;
}
</style>
