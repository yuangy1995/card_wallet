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
                        <el-icon><refresh-right /></el-icon>恢复 / 融合
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
    <el-alert
      v-if="currentBackup && currentBackup.automatic"
      title="正在自动比对最新云端备份，请输入该备份的解密密码"
      type="warning"
      :closable="false"
      show-icon
      class="password-hint"
    />
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
      <el-alert
        v-if="comparisonIsAutomatic && compareStatus === 'diff'"
        title="检测到最新云端备份与本地数据不一致，请选择智能融合或以云端数据覆盖本地"
        type="warning"
        :closable="false"
        show-icon
        class="automatic-compare-hint"
      />
      <div v-if="comparedBackup" class="compared-backup-name">
        当前比对备份：{{ comparedBackup.filename }}
      </div>
      <div class="compare-toolbar">
        <div class="summary-tags">
          <el-tag size="small" type="info">总计 {{ diffSummary.total }}</el-tag>
          <el-tag size="small" type="success">新增 {{ diffSummary.added }}</el-tag>
          <el-tag size="small" type="danger">删除 {{ diffSummary.deleted }}</el-tag>
          <el-tag size="small" type="warning">修改 {{ diffSummary.modified }}</el-tag>
          <el-tag size="small">字段差异 {{ diffSummary.modifiedFields }}</el-tag>
        </div>
        <div class="toolbar-actions">
          <el-radio-group v-model="activeFilter" size="small" class="filter-switch">
            <el-radio-button label="all">全部</el-radio-button>
            <el-radio-button label="diff">只看差异</el-radio-button>
            <el-radio-button label="modified">仅修改</el-radio-button>
            <el-radio-button label="added">仅新增</el-radio-button>
            <el-radio-button label="deleted">仅删除</el-radio-button>
          </el-radio-group>
          <div class="legend">
            <span class="legend-item legend-modified">修改</span>
            <span class="legend-item legend-added">新增</span>
            <span class="legend-item legend-deleted">删除</span>
          </div>
        </div>
      </div>

      <el-result
        v-if="compareStatus === 'match'"
        icon="success"
        title="本地数据与云端数据一致"
        sub-title="未发现新增、删除或修改"
        class="compare-empty"
      />

      <div class="table-wrapper" v-else>
        <el-empty
          v-if="filteredComparisonData.length === 0"
          description="当前筛选无结果"
          class="compare-empty"
        />
        <el-table 
          v-else
          :data="filteredComparisonData" 
          border 
          stripe
          style="width: 100%"
          height="600px"
          :cell-class-name="getTableCellClass"
          header-row-class-name="compare-header"
        >
          <el-table-column type="index" width="60" fixed="left" />
          <el-table-column
            label="数据来源"
            width="200"
            align="center"
            fixed="left"
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
                <el-tag
                  v-if="row._status === 'modified'"
                  :type="getVersionTagType(row._versionState)"
                  size="small"
                  effect="plain"
                  class="version-tag"
                >
                  {{ getVersionStateText(row._versionState) }}
                </el-tag>
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
                <div class="diff-content">
                  <div class="diff-item">
                    <span class="diff-label">云端值</span>
                    <span class="diff-value">{{ formatColumnValue(row._diff[col.value].cloud, col.value) }}</span>
                  </div>
                  <div class="diff-item">
                    <span class="diff-label">本地值</span>
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
        <el-button
          v-if="compareStatus === 'diff'"
          type="primary"
          :loading="resolvingComparison"
          @click="handleSmartMerge"
        >
          智能双向融合（保留最新）
        </el-button>
        <el-button
          v-if="compareStatus === 'diff'"
          type="warning"
          :disabled="resolvingComparison"
          @click="handleForceCloudOverwrite"
        >
          云端数据强制覆盖本地
        </el-button>
        <el-button @click="compareDialogVisible = false">关闭</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, onMounted, inject, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { handleNetworkError, handleEncryptionError, handleValidationError } from '@/utils/errorHandler'
import { webdavClient } from '@/utils/webdav'
import { encryptData, decryptData } from '@/utils/encryption'
import { Delete, ArrowDown, DocumentCopy, RefreshRight, Edit } from '@element-plus/icons-vue'
import { creditCardOptions } from '@/config/creditCardOptions'
import { useAutoLock } from '@/composables/useAutoLock'

const emit = defineEmits(['update', 'showConfig'])
const visible = ref(false)
const loading = ref(false)
const backingUp = ref(false)
const backupList = ref([])
const cardData = ref([])
const isConnected = ref(false)  // 添加连接状态
const providedAutoLock = inject('autoLock', null)
const { isLocked } = providedAutoLock || useAutoLock()

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
const compareStatus = ref('idle')
const activeFilter = ref('diff')
const comparedCloudCards = ref([])
const comparedBackup = ref(null)
const comparisonIsAutomatic = ref(false)
const comparisonPassword = ref('')
const resolvingComparison = ref(false)
const startupComparisonAttempted = ref(false)
const tableColumns = creditCardOptions.tableCustomData

const filteredComparisonData = computed(() => {
  const data = comparisonData.value || []
  switch (activeFilter.value) {
    case 'modified':
      return data.filter(item => item._status === 'modified')
    case 'added':
      return data.filter(item => item._status === 'added')
    case 'deleted':
      return data.filter(item => item._status === 'deleted')
    case 'diff':
      return data.filter(item => ['modified', 'added', 'deleted'].includes(item._status))
    default:
      return data
  }
})

const diffSummary = computed(() => {
  const summary = {
    total: comparisonData.value.length,
    added: 0,
    deleted: 0,
    modified: 0,
    modifiedFields: 0
  }

  comparisonData.value.forEach(item => {
    if (item._status === 'added') summary.added += 1
    if (item._status === 'deleted') summary.deleted += 1
    if (item._status === 'modified') {
      summary.modified += 1
      if (item._diff) {
        summary.modifiedFields += Object.keys(item._diff).length
      }
    }
  })

  return summary
})

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

const closeAll = () => {
  visible.value = false
  backupDialogVisible.value = false
  restoreDialogVisible.value = false
  renameDialogVisible.value = false
  compareDialogVisible.value = false
  loading.value = false
  backingUp.value = false
  progressVisible.value = false
  progress.value = 0
  progressStatus.value = ''
  currentOperation.value = ''
  awaitingPassword.value = false
  comparisonData.value = []
  compareStatus.value = 'idle'
  activeFilter.value = 'diff'
  comparedCloudCards.value = []
  comparedBackup.value = null
  comparisonIsAutomatic.value = false
  comparisonPassword.value = ''
  resolvingComparison.value = false
  currentBackup.value = null
  restoreForm.value.password = ''
}

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

const extractCards = (data) => {
  const parsedData = typeof data === 'string' ? JSON.parse(data) : data
  if (Array.isArray(parsedData)) return parsedData
  if (Array.isArray(parsedData?.cards)) return parsedData.cards
  if (Array.isArray(parsedData?.data)) return parsedData.data
  return []
}

const getStoredCards = () => {
  const storedData = JSON.parse(localStorage.getItem('cardData') || '[]')
  return Array.isArray(storedData) ? storedData : []
}

// 同时兼容 Web 端斜杠格式、Mac 端横杠格式以及 ISO 时间格式
const getModifyTimestamp = (value) => {
  if (!value) return null
  const dateValue = String(value).trim()
  const matched = dateValue.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?/)
  if (matched) {
    return new Date(
      Number(matched[1]),
      Number(matched[2]) - 1,
      Number(matched[3]),
      Number(matched[4]),
      Number(matched[5]),
      Number(matched[6] || 0)
    ).getTime()
  }

  const timestamp = new Date(dateValue).getTime()
  return Number.isNaN(timestamp) ? null : timestamp
}

const compareModifyTime = (localItem, cloudItem) => {
  const localTimestamp = getModifyTimestamp(localItem?.lastModifyTime)
  const cloudTimestamp = getModifyTimestamp(cloudItem?.lastModifyTime)
  if (localTimestamp !== null && cloudTimestamp !== null) {
    return Math.sign(localTimestamp - cloudTimestamp)
  }
  if (localTimestamp !== null) return 1
  if (cloudTimestamp !== null) return -1
  return 0
}

const isSameFieldValue = (field, localValue, cloudValue) => {
  if (field === 'lastModifyTime') {
    const localTimestamp = getModifyTimestamp(localValue)
    const cloudTimestamp = getModifyTimestamp(cloudValue)
    if (localTimestamp !== null && cloudTimestamp !== null && localTimestamp === cloudTimestamp) {
      return true
    }
  }
  return JSON.stringify(localValue) === JSON.stringify(cloudValue)
}

const getVersionState = (localItem, cloudItem) => {
  const compared = compareModifyTime(localItem, cloudItem)
  if (compared > 0) return 'localNewer'
  if (compared < 0) return 'cloudNewer'
  return 'sameTime'
}

const getVersionStateText = (state) => {
  if (state === 'localNewer') return '本地更新'
  if (state === 'cloudNewer') return '云端更新'
  return '时间相同，保留本地'
}

const getVersionTagType = (state) => {
  if (state === 'localNewer') return 'primary'
  if (state === 'cloudNewer') return 'success'
  return 'info'
}

const finishRestoreProgress = () => {
  progressVisible.value = false
  progress.value = 0
  currentOperation.value = ''
  awaitingPassword.value = false
}

const persistLocalCards = (cards) => {
  cardData.value = cards
  localStorage.setItem('cardData', JSON.stringify(cards))
  emit('update', cards)
}

const mergeLatestCards = (localCards, cloudCards) => {
  const mergedMap = new Map(localCards.map(card => [card.id, card]))

  cloudCards.forEach(cloudCard => {
    const localCard = mergedMap.get(cloudCard.id)
    if (!localCard || compareModifyTime(localCard, cloudCard) < 0) {
      mergedMap.set(cloudCard.id, cloudCard)
    }
  })

  return Array.from(mergedMap.values())
}

// 根据解密后的数据进行比对，并展示解决冲突的入口
const compareData = (decryptedData, backup, options = {}) => {
  const { automatic = false, showMatch = true } = options
  const backupData = extractCards(decryptedData)
  const currentData = getStoredCards()
  const currentMap = new Map(currentData.map(item => [item.id, item]))
  const backupMap = new Map(backupData.map(item => [item.id, item]))
  const comparedData = []

  comparedCloudCards.value = backupData
  comparedBackup.value = backup || null
  comparisonIsAutomatic.value = automatic

  backupData.forEach(backupItem => {
    const currentItem = currentMap.get(backupItem.id)
    if (!currentItem) {
      comparedData.push({
        ...backupItem,
        _status: 'deleted'
      })
      return
    }

    const diff = {}
    const fields = new Set([...Object.keys(backupItem), ...Object.keys(currentItem)])
    fields.forEach(field => {
      if (!field.startsWith('_') && !isSameFieldValue(field, currentItem[field], backupItem[field])) {
        diff[field] = {
          cloud: backupItem[field],
          local: currentItem[field]
        }
      }
    })

    if (Object.keys(diff).length > 0) {
      comparedData.push({
        ...currentItem,
        _status: 'modified',
        _versionState: getVersionState(currentItem, backupItem),
        _diff: diff
      })
    }
  })

  currentData.forEach(currentItem => {
    if (!backupMap.has(currentItem.id)) {
      comparedData.push({
        ...currentItem,
        _status: 'added'
      })
    }
  })

  comparisonData.value = comparedData
  activeFilter.value = 'diff'

  if (comparedData.length === 0) {
    compareStatus.value = 'match'
    if (showMatch) {
      compareDialogVisible.value = true
      ElMessage.success('本地数据与云端数据一致')
    }
    return
  }

  compareStatus.value = 'diff'
  compareDialogVisible.value = true
  if (automatic) {
    ElMessage.warning('最新云端备份与本地数据存在差异，请选择处理方式')
  }
}

const downloadAndCompareBackup = async (backup, options = {}) => {
  const { automatic = false, showMatch = true, action = 'compare' } = options
  const loadingField = action === 'restore' ? 'restoring' : 'comparing'

  compareStatus.value = 'idle'
  comparisonData.value = []
  comparisonPassword.value = ''
  backup[loadingField] = true

  if (!automatic && action === 'restore') {
    progressVisible.value = true
    progress.value = 0
    currentOperation.value = 'restore'
  }

  try {
    const result = await webdavClient.restoreBackup(backup.filename)
    if (!result.success) {
      ElMessage.error(result.message)
      return
    }

    const content = result.data
    if (typeof content === 'string' && content.startsWith('default:')) {
      compareData(decryptData(content), backup, { automatic, showMatch })
    } else if (typeof content === 'string' && content.startsWith('encrypted:')) {
      currentBackup.value = { content, backup, automatic, showMatch }
      awaitingPassword.value = true
      restoreDialogVisible.value = true
    } else {
      compareData(content, backup, { automatic, showMatch })
    }
  } catch (error) {
    const operation = automatic ? '自动比对最新备份' : '处理备份数据'
    ElMessage.error(`${operation}失败：${error.message}`)
  } finally {
    backup[loadingField] = false
    if (!awaitingPassword.value) {
      finishRestoreProgress()
    }
  }
}

// 恢复操作先展示差异，由用户决定融合或强制覆盖
const handleRestore = async (backup) => {
  await downloadAndCompareBackup(backup, { action: 'restore' })
}

// 确认密码输入后的处理
const handleRestoreConfirm = async () => {
  if (!restoreForm.value.password) {
    ElMessage.warning('请输入密码')
    return
  }

  try {
    const context = currentBackup.value
    const password = restoreForm.value.password
    const decryptedData = decryptData(context.content, password)
    comparisonPassword.value = password
    compareData(decryptedData, context.backup, {
      automatic: context.automatic,
      showMatch: context.showMatch
    })
    restoreDialogVisible.value = false
    restoreForm.value.password = ''
    currentBackup.value = null
    finishRestoreProgress()
  } catch (error) {
    handleEncryptionError(error, '解密备份')
  }
}

const handleSmartMerge = async () => {
  resolvingComparison.value = true
  let localMerged = false
  try {
    const mergedCards = mergeLatestCards(getStoredCards(), comparedCloudCards.value)
    persistLocalCards(mergedCards)
    localMerged = true

    const password = comparisonPassword.value || undefined
    const encryptedData = encryptData({
      cards: mergedCards,
      categories: [],
      tags: []
    }, password)
    const result = await webdavClient.createBackup(encryptedData, password)
    if (result.success) {
      ElMessage.success('智能融合完成，最新数据已生成新的云端备份')
      if (visible.value) {
        await loadBackupList()
      }
    } else {
      ElMessage.warning(`本地智能融合已完成，但同步云端失败：${result.message}`)
    }
    compareDialogVisible.value = false
  } catch (error) {
    const message = localMerged ? '本地智能融合已完成，但同步云端失败' : '智能融合失败'
    ElMessage.error(`${message}：${error.message}`)
  } finally {
    resolvingComparison.value = false
    comparisonPassword.value = ''
  }
}

const handleForceCloudOverwrite = async () => {
  try {
    await ElMessageBox.confirm(
      '确定使用云端备份强制覆盖本地数据吗？本地未同步的更新将丢失。',
      '确认覆盖本地数据',
      {
        confirmButtonText: '强制覆盖',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )
    persistLocalCards(comparedCloudCards.value)
    compareDialogVisible.value = false
    comparisonPassword.value = ''
    ElMessage.success('已使用云端备份覆盖本地数据')
  } catch (error) {
    if (error !== 'cancel' && error !== 'close') {
      ElMessage.error('覆盖本地数据失败：' + error.message)
    }
  }
}

// 取消密码输入
const handleRestoreCancel = () => {
  restoreDialogVisible.value = false
  currentBackup.value = null
  comparisonPassword.value = ''
  finishRestoreProgress()
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
  await downloadAndCompareBackup(backup)
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
  comparisonData.value = []
  compareStatus.value = 'idle'
  activeFilter.value = 'diff'
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

// 页面首次就绪后，仅自动比对一次最新云端备份
const checkLatestBackupOnStartup = async () => {
  if (startupComparisonAttempted.value || isLocked.value) return
  startupComparisonAttempted.value = true

  try {
    const config = webdavClient.loadConfig()
    if (!config) return

    if (!webdavClient.client) {
      await webdavClient.initialize(config)
    }

    const result = await webdavClient.getBackupList()
    if (!result.success || result.data.length === 0) return

    const latestBackup = [...result.data].sort((a, b) => {
      return new Date(b.lastmod) - new Date(a.lastmod)
    })[0]
    await downloadAndCompareBackup(latestBackup, {
      automatic: true,
      showMatch: false
    })
  } catch (error) {
    console.warn('自动比对最新云端备份失败：', error)
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

watch(isLocked, (locked) => {
  if (locked) {
    closeAll()
  }
})

defineExpose({
  open,
  closeAll,
  checkLatestBackupOnStartup
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

.data-source {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.password-hint,
.automatic-compare-hint {
  margin-bottom: 12px;
}

.compared-backup-name {
  color: var(--el-text-color-secondary);
  font-size: 13px;
  margin-bottom: 4px;
}

.version-tag {
  align-self: center;
  margin-top: 4px;
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

.compare-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  position: sticky;
  top: 0;
  z-index: 2;
  background: var(--el-bg-color);
}

.summary-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.toolbar-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  flex-wrap: wrap;
}

.filter-switch {
  margin-right: 4px;
}

.legend {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.legend-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  background: var(--el-fill-color-light);
  border: 1px solid var(--el-border-color-lighter);
  color: var(--el-text-color-regular);
}

.legend-modified {
  border-color: #f3d19e;
  color: #d48806;
}

.legend-added {
  border-color: #c6e2b3;
  color: #529b2e;
}

.legend-deleted {
  border-color: #f4c2c2;
  color: #c45656;
}

.compare-container .table-wrapper {
  margin-top: 8px;
}

.compare-empty {
  margin: 16px 0;
}

:deep(.compare-header th) {
  position: sticky;
  top: 0;
  z-index: 1;
  background: var(--el-bg-color);
}

.diff-content {
  display: flex;
  gap: 12px;
  padding: 8px;
  background-color: #fdf6ec;
  border-radius: 4px;
}

.diff-item {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 6px;
}

.diff-label {
  color: #909399;
  font-size: 12px;
}

.diff-value {
  color: #303133;
  font-weight: 500;
  word-break: break-all;
}

.progress-text {
  margin-top: 8px;
  color: var(--el-text-color-secondary);
}
</style>
