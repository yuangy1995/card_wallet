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
                <el-dropdown trigger="click" :disabled="!isConnected">
                  <el-button size="small">
                    操作<el-icon class="el-icon--right"><arrow-down /></el-icon>
                  </el-button>
                  <template #dropdown>
                    <el-dropdown-menu>
                      <el-dropdown-item @click="handleCompare(backup)" :loading="backup.comparing">
                        <el-icon><document-copy /></el-icon>比对
                      </el-dropdown-item>
                      <el-dropdown-item @click="handleRestore(backup)" :loading="backup.restoring">
                        <el-icon><refresh-right /></el-icon>恢复
                      </el-dropdown-item>
                      <el-dropdown-item @click="handleRename(backup)" :loading="backup.renaming">
                        <el-icon><edit /></el-icon>重命名
                      </el-dropdown-item>
                      <el-dropdown-item @click="handleDelete(backup)" :loading="backup.deleting">
                        <el-icon><delete /></el-icon>删除
                      </el-dropdown-item>
                    </el-dropdown-menu>
                  </template>
                </el-dropdown>
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
        <el-button @click="handleRestoreCancel">取消</el-button>
        <el-button type="primary" @click="handleRestoreConfirm">确定</el-button>
      </span>
    </template>
  </el-dialog>

  <!-- 重命名对话框 -->
  <el-dialog
    v-model="renameDialogVisible"
    title="重命名备份"
    width="400px"
    append-to-body
  >
    <el-form :model="renameForm" label-width="80px">
      <el-form-item label="新文件名">
        <el-input v-model="renameForm.newFilename" />
      </el-form-item>
    </el-form>
    <template #footer>
      <span class="dialog-footer">
        <el-button @click="renameDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleRenameConfirm">确定</el-button>
      </span>
    </template>
  </el-dialog>

  <!-- 比对对话框 -->
  <el-dialog
    v-model="compareDialogVisible"
    title="备份数据比对"
    width="90%"
    append-to-body
    :close-on-click-modal="false"
    class="compare-dialog"
  >
    <div class="compare-container">
      <div class="table-wrapper">
        <el-table 
          :data="comparisonData" 
          border 
          stripe
          style="width: 100%"
          height="600px"
          :cell-class-name="getTableCellClass"
        >
          <el-table-column type="index" width="50" />
          <el-table-column
            label="数据来源"
            width="180"
            align="center"
          >
            <template #default="{ row }">
              <div class="data-source">
                <div class="source-item">
                  <span class="source-label">云端数据：</span>
                  <span class="source-value" :class="{ 'text-success': row._status !== 'added', 'text-danger': row._status === 'added' }">
                    {{ row._status !== 'added' ? '✅' : '❌' }}
                  </span>
                </div>
                <div class="source-item">
                  <span class="source-label">本地数据：</span>
                  <span class="source-value" :class="{ 'text-success': row._status !== 'deleted', 'text-danger': row._status === 'deleted' }">
                    {{ row._status !== 'deleted' ? '✅' : '❌' }}
                  </span>
                </div>
              </div>
            </template>
          </el-table-column>
          <el-table-column
            v-for="col in tableColumns"
            :key="col.value"
            :prop="col.value"
            :label="col.label"
            :min-width="getColumnWidth(col.value)"
          >
            <template #default="{ row }">
              <template v-if="row._diff && row._diff[col.value]">
                <div class="diff-content" :class="{ 'diff-highlight': true }">
                  <div class="diff-item">
                    <span class="diff-label">云端值：</span>
                    <span class="diff-value">{{ formatColumnValue(row._diff[col.value].cloud, col.value) }}</span>
                  </div>
                  <div class="diff-item">
                    <span class="diff-label">本地值：</span>
                    <span class="diff-value">{{ formatColumnValue(row._diff[col.value].local, col.value) }}</span>
                  </div>
                </div>
              </template>
              <template v-else>
                {{ formatColumnValue(row[col.value], col.value) }}
              </template>
            </template>
          </el-table-column>
        </el-table>
      </div>
    </div>
    <template #footer>
      <span class="dialog-footer">
        <el-button @click="compareDialogVisible = false">关闭</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { handleNetworkError, handleEncryptionError, handleValidationError } from '@/utils/errorHandler'
import { webdavClient } from '@/utils/webdav'
import { encryptData, decryptData } from '@/utils/encryption'
import { Delete, ArrowDown, DocumentCopy, RefreshRight, Edit } from '@element-plus/icons-vue'
import { creditCardOptions } from '@/config/creditCardOptions'

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

// 暂存的自定义密码
const tempCustomPassword = ref('')

// 恢复表单相关
const restoreDialogVisible = ref(false)
const restoreForm = ref({
  password: ''
})
const currentBackup = ref(null)

// 比对相关
const compareDialogVisible = ref(false)
const comparisonData = ref([])
const tableColumns = creditCardOptions.tableCustomData

// 重命名对话框
const renameDialogVisible = ref(false)
const renameForm = ref({
  oldFilename: '',
  newFilename: ''
})

// 进度相关
const progressVisible = ref(false)
const progress = ref(0)
const progressStatus = ref('')
const currentOperation = ref('') // 新增：当前操作类型（'backup' 或 'restore'）
const awaitingPassword = ref(false)

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
      // 按照lastmod时间倒序排序
      backupList.value = result.data.sort((a, b) => {
        return new Date(b.lastmod) - new Date(a.lastmod)
      })
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    handleNetworkError(error, '加载备份列表失败')
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
      ElMessage.error('表单验证失败')
      return
    }
  }

  backingUp.value = true
  progressVisible.value = true
  progress.value = 0
  currentOperation.value = 'backup'
  try {
    // 获取当前数据
    const data = {
      cards: cardData.value,
      categories: [], // 如果需要备份其他数据，可以在这里添加
      tags: []
    }

    // 如果使用自定义密码，先暂存密码
    if (backupForm.value.useCustomPassword) {
      tempCustomPassword.value = backupForm.value.password
    }

    // 加密数据
    const encryptedData = encryptData(
      data,
      backupForm.value.useCustomPassword ? backupForm.value.password : undefined
    )

    const result = await webdavClient.createBackup(encryptedData, tempCustomPassword.value)
    if (result.success) {
      progress.value = 100
      ElMessage.success(result.message)
      await loadBackupList()
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    ElMessage.error(error.message)
  } finally {
    backingUp.value = false
    progressVisible.value = false
    progress.value = 0
    // 清除暂存的密码
    tempCustomPassword.value = ''
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
    currentOperation.value = 'restore'
    
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
            awaitingPassword.value = true
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
      handleNetworkError(error, '恢复备份')
    }
  } finally {
    backup.restoring = false
    loading.value = false
    // 仅当不在等待密码时，才重置/关闭进度显示
    if (!awaitingPassword.value && progressVisible.value) {
      progressVisible.value = false
      progress.value = 0
      currentOperation.value = ''
    }
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
    // 重置进度与状态
    progressVisible.value = false
    progress.value = 0
    currentOperation.value = ''
    awaitingPassword.value = false
  } catch (error) {
    handleEncryptionError(error, '解析备份数据')
  }
}

// 确认密码输入后的处理
const handleRestoreConfirm = async () => {
  if (!restoreForm.value.password) {
    ElMessage.warning('请输入密码')
    return
  }

  try {
    if (typeof currentBackup.value === 'object' && currentBackup.value.type === 'compare') {
      // 比对逻辑
      const decryptedData = decryptData(currentBackup.value.content, restoreForm.value.password)
      compareData(decryptedData, currentBackup.value.backup)
      restoreDialogVisible.value = false
      restoreForm.value.password = ''
    } else {
      // 恢复逻辑
      const decryptedData = decryptData(currentBackup.value, restoreForm.value.password)
      handleRestoreSuccess(decryptedData)
    }
  } catch (error) {
    handleEncryptionError(error, '解密备份')
  }
}

// 根据解密后的数据进行比对，并展示结果
const compareData = (decryptedData) => {
  // 解析数据
  const parsedData = typeof decryptedData === 'string' ? JSON.parse(decryptedData) : decryptedData
  const backupData = parsedData.cards || []
  const currentData = JSON.parse(localStorage.getItem('cardData') || '[]')

  // 创建Map用于快速查找
  const currentMap = new Map(currentData.map(item => [item.id, item]))
  const backupMap = new Map(backupData.map(item => [item.id, item]))
  const comparedData = []
  let hasChanges = false

  // 检查删除和修改的数据
  backupData.forEach(backupItem => {
    const currentItem = currentMap.get(backupItem.id)
    if (!currentItem) {
      // 已删除的数据
      comparedData.push({
        ...backupItem,
        _status: 'deleted'
      })
      hasChanges = true
    } else {
      // 首先检查lastModifyTime是否不一致
      let itemHasChanges = backupItem.lastModifyTime !== currentItem.lastModifyTime

      // 如果lastModifyTime一致，仍然检查其他关键字段是否有变化
      if (!itemHasChanges) {
        itemHasChanges = Object.keys(backupItem).some(key => {
          // 对于特殊字段（如年费达标状态），比较原始值
          if (key === 'isQualified') {
            return backupItem[key] !== currentItem[key]
          }
          // 排除lastTime和lastModifyTime字段
          if (key !== 'lastTime' && key !== 'lastModifyTime') {
            return JSON.stringify(backupItem[key]) !== JSON.stringify(currentItem[key])
          }
          return false
        })
      }

      if (itemHasChanges) {
        // 创建一个新的对象来存储差异信息
        const diffItem = { ...currentItem, _status: 'modified', _diff: {} }

        // 检查每个字段的差异
        Object.keys(backupItem).forEach(key => {
          // 对于特殊字段（如年费达标状态），比较原始值
          if (key === 'isQualified') {
            if (backupItem[key] !== currentItem[key]) {
              diffItem._diff[key] = {
                cloud: backupItem[key],
                local: currentItem[key]
              }
            }
          } else if (JSON.stringify(backupItem[key]) !== JSON.stringify(currentItem[key])) {
            diffItem._diff[key] = {
              cloud: backupItem[key],
              local: currentItem[key]
            }
          }
        })

        comparedData.push(diffItem)
        hasChanges = true
      }
    }
  })

  // 检查新增的数据
  currentData.forEach(currentItem => {
    if (!backupMap.has(currentItem.id)) {
      comparedData.push({
        ...currentItem,
        _status: 'added'
      })
      hasChanges = true
    }
  })

  if (!hasChanges) {
    ElMessage.success('本地数据与云端数据一致')
    return
  }

  comparisonData.value = comparedData
  compareDialogVisible.value = true
}

// 取消密码输入
const handleRestoreCancel = () => {
  restoreDialogVisible.value = false
  awaitingPassword.value = false
  // 取消恢复时，关闭并重置进度状态
  progressVisible.value = false
  progress.value = 0
  currentOperation.value = ''
  restoreForm.value.password = ''
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

// 比对数据
const handleCompare = async (backup) => {
  try {
    backup.comparing = true
    const result = await webdavClient.restoreBackup(backup.filename)
    if (result.success) {
      try {
        // 检查数据是否加密
        const content = result.data
        let decryptedData

        if (typeof content === 'string' && (content.startsWith('encrypted:') || content.startsWith('default:'))) {
          // 如果是默认加密，直接解密
          if (content.startsWith('default:')) {
            decryptedData = decryptData(content)
          } else {
            // 如果是自定义密码加密，显示密码输入对话框
            currentBackup.value = { content, type: 'compare', backup }
            restoreDialogVisible.value = true
            return
          }
        } else {
          // 未加密数据直接使用
          decryptedData = content
        }

        // 解析数据
        const parsedData = typeof decryptedData === 'string' ? JSON.parse(decryptedData) : decryptedData
        const backupData = parsedData.cards || []
        const currentData = JSON.parse(localStorage.getItem('cardData') || '[]')

        // 创建Map用于快速查找
        const currentMap = new Map(currentData.map(item => [item.id, item]))
        const backupMap = new Map(backupData.map(item => [item.id, item]))
        const comparedData = []
        let hasChanges = false

        // 检查删除和修改的数据
        backupData.forEach(backupItem => {
          const currentItem = currentMap.get(backupItem.id)
          if (!currentItem) {
            // 已删除的数据
            comparedData.push({
              ...backupItem,
              _status: 'deleted'
            })
            hasChanges = true
          } else {
            // 首先检查lastModifyTime是否不一致
            let itemHasChanges = backupItem.lastModifyTime !== currentItem.lastModifyTime
            
            // 如果lastModifyTime一致，仍然检查其他关键字段是否有变化
            if (!itemHasChanges) {
              itemHasChanges = Object.keys(backupItem).some(key => {
                // 对于特殊字段（如年费达标状态），比较原始值
                if (key === 'isQualified') {
                  return backupItem[key] !== currentItem[key]
                }
                // 排除lastTime和lastModifyTime字段
                if (key !== 'lastTime' && key !== 'lastModifyTime') {
                  return JSON.stringify(backupItem[key]) !== JSON.stringify(currentItem[key])
                }
                return false
              })
            }
            
            if (itemHasChanges) {
              // 创建一个新的对象来存储差异信息
              const diffItem = { ...currentItem, _status: 'modified', _diff: {} }
              
              // 检查每个字段的差异
              Object.keys(backupItem).forEach(key => {
                // 对于特殊字段（如年费达标状态），比较原始值
                if (key === 'isQualified') {
                  if (backupItem[key] !== currentItem[key]) {
                    diffItem._diff[key] = {
                      cloud: backupItem[key],
                      local: currentItem[key]
                    }
                  }
                } else if (JSON.stringify(backupItem[key]) !== JSON.stringify(currentItem[key])) {
                  diffItem._diff[key] = {
                    cloud: backupItem[key],
                    local: currentItem[key]
                  }
                }
              })
              
              comparedData.push(diffItem)
              hasChanges = true
            }
          }
        })

        // 检查新增的数据
        currentData.forEach(currentItem => {
          if (!backupMap.has(currentItem.id)) {
            comparedData.push({
              ...currentItem,
              _status: 'added'
            })
            hasChanges = true
          }
        })

        if (!hasChanges) {
          // 不显示一致消息，避免与 handleCompare 中的消息重复
          return
        }

        comparisonData.value = comparedData
        compareDialogVisible.value = true
      } catch (error) {
        ElMessage.error('处理备份数据失败：' + error.message)
      }
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    ElMessage.error('比对失败：' + error.message)
  } finally {
    backup.comparing = false
  }
}

// 获取表格单元格的类名
const getTableCellClass = ({ row }) => {
  if (row._status === 'deleted') return 'comparison-deleted'
  if (row._status === 'modified') return 'comparison-modified'
  if (row._status === 'added') return 'comparison-added'
  return ''
}

// 获取列宽度
const getColumnWidth = (columnValue) => {
  switch (columnValue) {
    case 'country': return '100'
    case 'bank': return '150'
    case 'alias': return '200'
    case 'level': return '110'
    case 'type': return '150'
    case 'annualFee': return '90'
    case 'cardNumber': return '250'
    case 'valid': return '120'
    case 'cvv': return '120'
    case 'limit': return '100'
    case 'nextAnnualFeeCollectionTime': return '150'
    case 'lastTime': return '170'
    case 'isQualified': return '100'
    case 'equity': return '200'
    case 'remark': return '200'
    default: return '150'
  }
}

// 格式化列值
const formatColumnValue = (value, columnType) => {
  if (value === undefined || value === null || value === '') return '-'
  
  switch (columnType) {
    case 'isQualified':
      switch (value) {
        case '1': return '已达标'
        case '2': return '未达标'
        case '3': return '终免年费'
        case '0': return '未达标' // 兼容旧数据
        default: return value
      }
    case 'nextAnnualFeeCollectionTime':
    case 'lastTime':
      return value ? formatDate(value) : '-'
    default:
      return value
  }
}

// 重命名备份
const handleRename = (backup) => {
  renameForm.value.oldFilename = backup.filename
  renameForm.value.newFilename = backup.filename
  renameDialogVisible.value = true
}

// 确认重命名
const handleRenameConfirm = async () => {
  const backup = backupList.value.find(b => b.filename === renameForm.value.oldFilename)
  if (!backup) return

  backup.renaming = true
  try {
    const result = await webdavClient.renameBackup(
      renameForm.value.oldFilename,
      renameForm.value.newFilename
    )
    if (result.success) {
      ElMessage.success(result.message)
      await loadBackupList()
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    ElMessage.error(error.message)
  } finally {
    backup.renaming = false
    renameDialogVisible.value = false
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
  currentOperation.value = ''
  awaitingPassword.value = false
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
      const initialized = await webdavClient.initialize(config)
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
      // 在恢复操作且等待密码输入时，保持进度可见
      if (currentOperation.value === 'restore' && awaitingPassword.value) return
      progressVisible.value = false
      progress.value = 0
      currentOperation.value = ''
    }, 500)
  }
}

// 在组件挂载时设置进度回调
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
}

.diff-content {
  padding: 8px;
  
  &.diff-highlight {
    background-color: #fdf6ec;
  }
}

.diff-item {
  margin-bottom: 4px;
  &:last-child {
    margin-bottom: 0;
  }
}

.diff-label {
  color: #909399;
  margin-right: 8px;
  font-size: 13px;
}

.diff-value {
  color: #303133;
  font-weight: 500;

  .progress-text {
    margin-top: 8px;
    color: var(--el-text-color-secondary);
  }
}

.data-source {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.source-item {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
}

.source-label {
  font-size: 13px;
  color: var(--el-text-color-regular);
}

.source-value {
  font-size: 14px;
}

.text-success {
  color: var(--el-color-success);
}

.text-danger {
  color: var(--el-color-danger);
}

.connection-status {
  margin-left: 16px;
}
</style>
