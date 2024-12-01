<template>
  <el-dialog
    v-model="visible"
    title="备份管理"
    width="600px"
    :close-on-click-modal="false"
    :append-to-body="true"
    :z-index="2000"
    @closed="handleClosed"
  >
    <div class="backup-dialog">
      <!-- 备份列表 -->
      <div v-if="backupList.length > 0" class="backup-list">
        <el-table
          :data="backupList"
          style="width: 100%"
          v-loading="loading"
          element-loading-text="正在获取备份列表..."
          element-loading-background="rgba(255, 255, 255, 0.7)"
        >
          <el-table-column prop="basename" label="备份文件" min-width="200">
            <template #default="{ row }">
              <el-tooltip :content="row.filename" placement="top">
                <span>{{ row.basename }}</span>
              </el-tooltip>
            </template>
          </el-table-column>
          <el-table-column prop="lastmod" label="创建时间" min-width="160">
            <template #default="{ row }">
              {{ formatDate(row.lastmod) }}
            </template>
          </el-table-column>
          <el-table-column prop="size" label="大小" width="100">
            <template #default="{ row }">
              {{ formatSize(row.size) }}
            </template>
          </el-table-column>
          <el-table-column label="操作" width="120" fixed="right">
            <template #default="{ row }">
              <el-button-group>
                <el-button
                  type="primary"
                  :icon="Download"
                  size="small"
                  @click="handleRestore(row)"
                  title="恢复"
                  :loading="row.restoring"
                />
                <el-button
                  type="danger"
                  :icon="Delete"
                  size="small"
                  @click="handleDelete(row)"
                  title="删除"
                  :loading="row.deleting"
                />
              </el-button-group>
            </template>
          </el-table-column>
        </el-table>
      </div>
      <el-empty v-else description="暂无备份" />

      <!-- 进度条 -->
      <el-dialog
        v-model="progressVisible"
        :title="progressTitle"
        width="400px"
        :close-on-click-modal="false"
        :show-close="false"
        append-to-body
      >
        <div class="progress-content">
          <el-progress
            :percentage="progress"
            :status="progressStatus"
            :stroke-width="15"
            :show-text="true"
          />
          <div class="progress-text">{{ progressText }}</div>
        </div>
      </el-dialog>
    </div>

    <template #footer>
      <span class="dialog-footer">
        <el-button @click="visible = false">关闭</el-button>
        <el-button
          type="primary"
          :loading="backingUp"
          :disabled="!isConnected"
          @click="showBackupDialog"
        >
          创建备份
        </el-button>
      </span>
    </template>
  </el-dialog>

  <!-- 创建备份对话框 -->
  <el-dialog
    v-model="backupDialogVisible"
    title="创建备份"
    width="400px"
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
import { ref } from 'vue'
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
const progressTitle = ref('')
const progressText = ref('')

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
  return new Date(date).toLocaleString()
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
    } else {
      ElMessage.error(result.message || '获取备份列表失败')
      isConnected.value = false  // 连接可能已断开
    }
  } catch (error) {
    console.error('Failed to load backup list:', error)
    ElMessage.error('获取备份列表失败')
    isConnected.value = false  // 连接可能已断开
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
      backupDialogVisible.value = false
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
        console.error('Failed to process backup data:', error)
        ElMessage.error(error.message || '数据格式错误')
      }
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    if (error !== 'cancel') {
      console.error('Restore failed:', error)
      ElMessage.error(error.message || '恢复失败')
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
    console.log('Restored data:', parsedData) // 添加调试日志
    
    // 更新数据
    cardData.value = parsedData.cards || []
    emit('update', cardData.value)
    ElMessage.success('恢复成功')
    
    // 关闭所有对话框
    restoreDialogVisible.value = false
    visible.value = false
    restoreForm.value.password = ''
  } catch (error) {
    console.error('Failed to parse backup data:', error)
    ElMessage.error('备份数据格式错误')
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
    console.error('Failed to decrypt backup:', error)
    ElMessage.error(error.message)
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
      ElMessage.error(error.message || '删除失败')
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
    console.error('Failed to test WebDAV connection:', error)
    ElMessage.error('连接 WebDAV 服务器失败')
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
    progressTitle.value = '正在创建备份'
    progressText.value = `正在上传... ${progress.value}%`
  } else {
    progressTitle.value = '正在恢复备份'
    progressText.value = `正在下载... ${progress.value}%`
  }

  // 如果进度完成，延迟关闭进度对话框
  if (value >= 100) {
    setTimeout(() => {
      progressVisible.value = false
      progress.value = 0
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

<style lang="scss">
.backup-dialog {
  min-height: 300px;
}

.backup-list {
  margin-bottom: 20px;
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

.progress-content {
  padding: 20px;
  text-align: center;

  .progress-text {
    margin-top: 10px;
    color: #606266;
  }
}
</style>
