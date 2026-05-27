<template>
  <el-dialog
    v-model="visible"
    title="云端备份管理"
    width="600px"
    :close-on-click-modal="false"
    :append-to-body="true"
    :z-index="2000"
    class="backup-dialog-shell"
    draggable
    @closed="handleClosed"
  >
    <div class="backup-dialog">
      <div class="backup-header" v-if="!progressVisible">
        <div class="backup-primary-actions">
          <el-button
            type="success"
            @click="handlePublishV3"
            :disabled="!isConnected || loading || publishingV3"
          >
            同步当前数据
          </el-button>
        </div>
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
                <div class="backup-name">{{ formatBackupDisplayName(backup) }}</div>
                <div class="backup-meta">
                  <el-tag :type="isAutomaticSyncBackup(backup.filename) ? 'success' : 'warning'" size="small">
                    {{ isAutomaticSyncBackup(backup.filename) ? '自动同步' : '手动备份' }}
                  </el-tag>
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
    top="4vh"
    append-to-body
    :close-on-click-modal="false"
    class="compare-dialog"
  >
    <div class="compare-container">
      <div class="compare-toolbar">
        <div class="summary-tags">
          <el-tag size="small" type="info" effect="plain" class="summary-tag summary-total">总计 {{ diffSummary.total }}</el-tag>
          <el-tag size="small" type="success" effect="plain" class="summary-tag summary-added">新增 {{ diffSummary.added }}</el-tag>
          <el-tag size="small" type="danger" effect="plain" class="summary-tag summary-deleted">删除 {{ diffSummary.deleted }}</el-tag>
          <el-tag size="small" type="warning" effect="plain" class="summary-tag summary-modified">修改 {{ diffSummary.modified }}</el-tag>
          <el-tag size="small" effect="plain" class="summary-tag summary-fields">字段差异 {{ diffSummary.modifiedFields }}</el-tag>
        </div>
        <div class="toolbar-actions">
          <el-radio-group v-model="activeFilter" size="small" class="filter-switch">
            <el-radio-button value="all">全部</el-radio-button>
            <el-radio-button value="diff">只看差异</el-radio-button>
            <el-radio-button value="modified">仅修改</el-radio-button>
            <el-radio-button value="added">仅新增</el-radio-button>
            <el-radio-button value="deleted">仅删除</el-radio-button>
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
          height="100%"
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
              </div>
            </template>
          </el-table-column>
          <el-table-column
            v-for="col in comparisonTableColumns"
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
        <el-button @click="compareDialogVisible = false">关闭</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, inject, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { handleNetworkError, handleEncryptionError, handleValidationError } from '@/utils/errorHandler'
import { webdavClient } from '@/utils/webdav'
import { decryptData } from '@/utils/encryption'
import { Delete, ArrowDown, DocumentCopy, RefreshRight, Edit } from '@element-plus/icons-vue'
import { creditCardOptions } from '@/config/creditCardOptions'
import { useAutoLock } from '@/composables/useAutoLock'
import { backupPayloadInfo } from '@/utils/backupPayload'
import { cardsEqualForSync, comparableCardForSync } from '@/utils/syncProtocol'
import { formatCardTimestamp } from '@/utils/cardTimestamp'
import { migrateCardData } from '@/utils/cardDataMigration'
import {
  RESTORE_IDENTITY_DECISIONS,
  cardNumberFingerprint,
  resolveRestoreIdentityConflicts
} from '@/utils/restoreIdentityResolver'

const emit = defineEmits(['update', 'showConfig', 'publishV3'])
const visible = ref(false)
const loading = ref(false)
const publishingV3 = ref(false)
const backupList = ref([])
const cardData = ref([])
const isConnected = ref(false)  // 添加连接状态
const providedAutoLock = inject('autoLock', null)
const { isLocked } = providedAutoLock || useAutoLock()

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
const tableColumns = creditCardOptions.tableCustomData
const hiddenCompareFieldLabels = {
  id: '卡片标识',
  isSharedLimit: '共享额度',
  accountBillDate: '账单日',
  dueDate: '还款日',
  billingDaySpendingToNextBill: '账单日消费计入下期'
}

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

const comparisonTableColumns = computed(() => {
  const columns = [...tableColumns]
  const existing = new Set(columns.map(column => column.value))
  comparisonData.value.forEach((item) => {
    Object.keys(item._diff || {}).forEach((key) => {
      if (!existing.has(key)) {
        columns.push({
          label: hiddenCompareFieldLabels[key] || key,
          value: key
        })
        existing.add(key)
      }
    })
  })
  return columns
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
  restoreDialogVisible.value = false
  renameDialogVisible.value = false
  compareDialogVisible.value = false
  loading.value = false
  publishingV3.value = false
  progressVisible.value = false
  progress.value = 0
  progressStatus.value = ''
  currentOperation.value = ''
  awaitingPassword.value = false
  comparisonData.value = []
  compareStatus.value = 'idle'
  activeFilter.value = 'diff'
  currentBackup.value = null
  restoreForm.value.password = ''
}

const handlePublishV3 = () => {
  if (!isConnected.value || loading.value || publishingV3.value) return
  publishingV3.value = true
  ElMessage.info('正在同步当前数据...')
  emit('publishV3', async () => {
    publishingV3.value = false
    if (visible.value && isConnected.value) {
      await loadBackupList()
    }
  })
}

// 进度文本（computed）
const progressText = computed(() => {
  return currentOperation.value === 'backup' 
    ? `正在备份... ${progress.value}%`
    : `正在恢复... ${progress.value}%`
})

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

const isAutomaticSyncBackup = (filename = '') => {
  return filename.includes('[SyncV3]') && filename.includes('[自]')
}

const formatBackupDisplayName = (backup) => {
  if (!backup?.filename) return '云端备份'
  if (!isAutomaticSyncBackup(backup.filename)) return backup.filename

  const cardCount = backup.filename.match(/---\((\d+)\)/)?.[1]
  return cardCount ? `自动同步备份（${cardCount} 张卡片）` : '自动同步备份'
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
            await handleRestoreSuccess(decryptedData)
          } else {
            // 如果是自定义密码加密，显示密码输入对话框
            currentBackup.value = content
            awaitingPassword.value = true
            restoreDialogVisible.value = true
          }
        } else {
          // 未加密数据直接使用
          await handleRestoreSuccess(content)
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
const handleRestoreSuccess = async (data) => {
  try {
    const cards = await cardsForRestore(data)
    if (!cards) {
      progressVisible.value = false
      progress.value = 0
      currentOperation.value = ''
      awaitingPassword.value = false
      restoreDialogVisible.value = false
      restoreForm.value.password = ''
      return
    }

    cardData.value = cards
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

const cardsForRestore = async (data) => {
  const payloadInfo = backupPayloadInfo(data)
  if (!payloadInfo.isRecognized) {
    throw new Error('此备份文件不是可识别的账本格式，可能文件已损坏或不是本应用生成的备份。')
  }
  if (!payloadInfo.isLegacy) {
    return payloadInfo.cards
  }

  const backupCards = payloadInfo.cards
    .map(card => migrateCardData(card))
    .filter(Boolean)

  return resolveRestoreIdentityConflicts(
    backupCards,
    Array.isArray(cardData.value) ? cardData.value : [],
    requestRestoreIdentityDecision
  )
}

const requestRestoreIdentityDecision = async ({ incoming, existing }) => {
  const firstChoice = await confirmSameCard(incoming, existing)
  if (!firstChoice) return null

  if (firstChoice === 'separate') {
    const confirmed = await confirmSeparateCard(incoming, existing)
    return confirmed ? RESTORE_IDENTITY_DECISIONS.KEEP_SEPARATE : null
  }

  const keepChoice = await chooseDataToKeep(incoming, existing)
  if (!keepChoice) return null

  const confirmed = await confirmSameCardChoice(incoming, existing, keepChoice)
  if (!confirmed) return null

  return keepChoice === 'incoming'
    ? RESTORE_IDENTITY_DECISIONS.KEEP_INCOMING
    : RESTORE_IDENTITY_DECISIONS.KEEP_CURRENT
}

const confirmSameCard = async (incoming, existing) => {
  try {
    await ElMessageBox.confirm(
      `备份中的「${formatCardForPrompt(incoming)}」和当前卡包里的「${formatCardForPrompt(existing)}」卡号相同。\n\n请确认它们是不是同一张卡。`,
      '发现卡号相同的卡片',
      {
        confirmButtonText: '是，同一张卡',
        cancelButtonText: '不是，作为新卡保存',
        distinguishCancelAndClose: true,
        type: 'warning'
      }
    )
    return 'same'
  } catch (action) {
    return action === 'cancel' ? 'separate' : null
  }
}

const chooseDataToKeep = async () => {
  try {
    await ElMessageBox.confirm(
      '这张卡在当前卡包和备份里都有记录。请选择恢复后保留哪一份内容。',
      '选择保留哪份数据',
      {
        confirmButtonText: '使用备份中的数据',
        cancelButtonText: '保留当前卡包中的数据',
        distinguishCancelAndClose: true,
        type: 'info'
      }
    )
    return 'incoming'
  } catch (action) {
    return action === 'cancel' ? 'current' : null
  }
}

const confirmSameCardChoice = async (incoming, existing, keepChoice) => {
  const keepText = keepChoice === 'incoming' ? '备份中的内容' : '当前卡包中的内容'
  try {
    await ElMessageBox.confirm(
      `将把「${formatCardForPrompt(incoming)}」和「${formatCardForPrompt(existing)}」视为同一张卡，并保留${keepText}。\n\n确认后不会额外生成重复卡片。`,
      '再次确认',
      {
        confirmButtonText: '确认',
        cancelButtonText: '返回检查',
        type: 'warning'
      }
    )
    return true
  } catch {
    return false
  }
}

const confirmSeparateCard = async (incoming, existing) => {
  try {
    await ElMessageBox.confirm(
      `将把备份中的「${formatCardForPrompt(incoming)}」作为另一张卡保存，与当前卡包里的「${formatCardForPrompt(existing)}」分开管理。\n\n确认后这两张卡会同时保留。`,
      '再次确认',
      {
        confirmButtonText: '确认作为新卡保存',
        cancelButtonText: '返回检查',
        type: 'warning'
      }
    )
    return true
  } catch {
    return false
  }
}

const formatCardForPrompt = (card) => {
  const alias = String(card?.alias || '').trim()
  const name = alias ? `${card?.bank || '未知银行'} - ${alias}` : (card?.bank || '未知银行')
  const digits = cardNumberFingerprint(card?.cardNumber)
  return digits.length >= 4 ? `${name} 尾号 ${digits.slice(-4)}` : name
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
      await handleRestoreSuccess(decryptedData)
    }
  } catch (error) {
    handleEncryptionError(error, '解密备份')
  }
}

// 根据解密后的数据进行比对，并展示结果
const compareData = (decryptedData) => {
  const payloadInfo = backupPayloadInfo(decryptedData)
  if (!payloadInfo.isRecognized) {
    throw new Error('此备份文件不是可识别的账本格式，可能文件已损坏或不是本应用生成的备份。')
  }
  const backupData = payloadInfo.cards
  const currentData = Array.isArray(cardData.value) ? cardData.value : []

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
      const itemHasChanges = !cardsEqualForSync(backupItem, currentItem)

      if (itemHasChanges) {
        // 创建一个新的对象来存储差异信息
        const diffItem = { ...currentItem, _status: 'modified', _diff: {} }
        const backupComparable = comparableCardForSync(backupItem)
        const currentComparable = comparableCardForSync(currentItem)
        const keys = new Set([
          ...Object.keys(backupComparable),
          ...Object.keys(currentComparable)
        ])

        // 检查每个字段的差异
        keys.forEach(key => {
          if (JSON.stringify(backupComparable[key]) !== JSON.stringify(currentComparable[key])) {
            diffItem._diff[key] = {
              cloud: backupComparable[key],
              local: currentComparable[key]
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
    comparisonData.value = []
    compareStatus.value = 'match'
    activeFilter.value = 'diff'
    compareDialogVisible.value = true
    ElMessage.success('本地数据与云端数据一致')
    return
  }

  comparisonData.value = comparedData
  compareStatus.value = 'diff'
  activeFilter.value = 'diff'
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
  compareStatus.value = 'idle'
  comparisonData.value = []
  const runComparison = (data) => {
    try {
      compareData(data)
    } catch (error) {
      ElMessage.error('处理备份数据失败：' + error.message)
    }
  }

  try {
    backup.comparing = true
    const result = await webdavClient.restoreBackup(backup.filename)

    if (!result.success) {
      ElMessage.error(result.message)
      return
    }

    const content = result.data

    if (typeof content === 'string' && (content.startsWith('encrypted:') || content.startsWith('default:'))) {
      if (content.startsWith('default:')) {
        runComparison(decryptData(content))
      } else {
        currentBackup.value = { content, type: 'compare', backup }
        restoreDialogVisible.value = true
      }
    } else {
      runComparison(content)
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
    case 'limit': return '160'
    case 'nextAnnualFeeCollectionTime': return '150'
    case 'lastTime': return '170'
    case 'lastModifyTime': return '220'
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
    case 'lastModifyTime':
      return value ? formatCardTimestamp(value) : '-'
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
  restoreForm.value.password = ''
  publishingV3.value = false
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
      ElMessage.warning('未完成云同步设置，请先配置')
      emit('showConfig')
      visible.value = false
      return
    }

    // 初始化 WebDAV 客户端
    if (!webdavClient.client) {
      const initialized = await webdavClient.initialize(config)
      if (!initialized) {
        ElMessage.error('云同步初始化失败')
        emit('showConfig')
        visible.value = false
        return
      }
    }

    // 测试连接
    loading.value = true
    const result = await webdavClient.testConnection()
    if (result.success) {
      ElMessage.success('已成功连接到云端')
      isConnected.value = true  // 设置连接状态
      await loadBackupList()
    } else {
      ElMessage.error(result.message)
      emit('showConfig')
      visible.value = false
    }
  } catch (error) {
    ElMessage.error('连接云端失败：' + error.message)
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

watch(isLocked, (locked) => {
  if (locked) {
    closeAll()
  }
})

defineExpose({
  open,
  closeAll
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

.backup-primary-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;

  :deep(.el-button) {
    border-radius: 8px;
    font-weight: 500;
  }
}

.backup-list-container {
  flex: 1;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
  background-color: var(--el-bg-color);
  overflow: hidden;
}

.backup-list {
  position: relative;
  padding: 16px;
  min-height: 200px;

  :deep(.el-loading-mask) {
    background-color: var(--app-loading-mask-bg, rgba(248, 250, 252, 0.72));
    backdrop-filter: blur(8px) saturate(110%);
    -webkit-backdrop-filter: blur(8px) saturate(110%);
  }

  :deep(.el-loading-spinner .circular) {
    color: var(--app-loading-spinner-color, var(--el-color-primary));
  }

  :deep(.el-empty) {
    background: transparent;
  }

  :deep(.el-empty__description p) {
    color: var(--el-text-color-secondary);
  }
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

  :deep(.el-tag) {
    border-radius: 999px;
    font-weight: 500;
  }
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

:global(.backup-dialog-shell.el-dialog .el-dialog__header) {
  background: transparent !important;
  border-bottom: none !important;
  padding: 18px 24px 10px !important;
  margin: 0 !important;
}

:global(.backup-dialog-shell.el-dialog .el-dialog__title) {
  color: var(--el-color-primary) !important;
}

:global(.backup-dialog-shell.el-dialog .el-dialog__headerbtn) {
  top: 14px;
}

:global(.backup-dialog-shell.el-dialog .el-dialog__body) {
  padding-top: 10px !important;
}

:global(html.dark) .backup-list {
  background: rgba(15, 23, 42, 0.28);

  :deep(.el-loading-mask) {
    background-color: var(--app-loading-mask-bg, rgba(3, 7, 18, 0.78));
  }
}

:global(html.dark) .backup-primary-actions :deep(.el-button--success) {
  background: rgba(16, 185, 129, 0.12);
  border-color: rgba(16, 185, 129, 0.34);
  color: #7dd3bd;
  box-shadow: none;

  &:hover,
  &:focus {
    background: rgba(16, 185, 129, 0.18);
    border-color: rgba(16, 185, 129, 0.46);
    color: #99f6d4;
  }
}

:global(html.dark) .backup-meta :deep(.el-tag) {
  background: rgba(15, 23, 42, 0.58);
  border-color: rgba(148, 163, 184, 0.22);
  color: rgba(226, 232, 240, 0.82);
}

:global(html.dark) .backup-meta :deep(.el-tag--success) {
  background: rgba(16, 185, 129, 0.10);
  border-color: rgba(16, 185, 129, 0.28);
  color: #7dd3bd;
}

:global(html.dark) .backup-meta :deep(.el-tag--warning) {
  background: rgba(245, 158, 11, 0.10);
  border-color: rgba(245, 158, 11, 0.28);
  color: #f8d98a;
}

:global(html.dark) .backup-meta :deep(.el-tag--info) {
  background: rgba(14, 165, 233, 0.10);
  border-color: rgba(14, 165, 233, 0.24);
  color: #8fd8f8;
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

.summary-tag {
  border-radius: 999px;
  font-weight: 500;
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

:global(html.dark) .filter-switch :deep(.el-radio-button__inner) {
  background: rgba(15, 23, 42, 0.70);
  border-color: rgba(14, 165, 233, 0.22);
  color: rgba(226, 232, 240, 0.78);
  box-shadow: none;
}

:global(html.dark) .filter-switch :deep(.el-radio-button__original-radio:checked + .el-radio-button__inner) {
  background: rgba(14, 165, 233, 0.18);
  border-color: rgba(14, 165, 233, 0.42);
  color: #93e7ff;
  box-shadow: none;
}

:global(html.dark) .summary-tag {
  background: rgba(15, 23, 42, 0.66);
  border-color: rgba(148, 163, 184, 0.22);
  color: rgba(226, 232, 240, 0.82);
  box-shadow: none;
}

:global(html.dark) .summary-added {
  background: rgba(16, 185, 129, 0.10);
  border-color: rgba(16, 185, 129, 0.28);
  color: #7dd3bd;
}

:global(html.dark) .summary-deleted {
  background: rgba(244, 63, 94, 0.10);
  border-color: rgba(244, 63, 94, 0.30);
  color: #fda4af;
}

:global(html.dark) .summary-modified {
  background: rgba(245, 158, 11, 0.10);
  border-color: rgba(245, 158, 11, 0.30);
  color: #f8d98a;
}

:global(html.dark) .summary-fields,
:global(html.dark) .summary-total {
  background: rgba(14, 165, 233, 0.10);
  border-color: rgba(14, 165, 233, 0.26);
  color: #8fd8f8;
}

:global(html.dark) .legend-item {
  background: rgba(15, 23, 42, 0.62);
  border-color: rgba(148, 163, 184, 0.22);
  color: rgba(226, 232, 240, 0.78);
}

:global(html.dark) .legend-modified {
  border-color: rgba(245, 158, 11, 0.30);
  color: #f8d98a;
}

:global(html.dark) .legend-added {
  border-color: rgba(16, 185, 129, 0.30);
  color: #7dd3bd;
}

:global(html.dark) .legend-deleted {
  border-color: rgba(244, 63, 94, 0.30);
  color: #fda4af;
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

.compare-container {
  display: flex;
  flex-direction: column;
  min-height: 0;
  height: min(760px, calc(100vh - 220px));
  max-height: calc(100vh - 220px);
  overflow: hidden;
}

.compare-container .table-wrapper {
  flex: 1 1 auto;
  min-height: 0;
  margin-top: 8px;
  overflow: hidden;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
}

.compare-empty {
  margin: 16px 0;
}

:global(.compare-dialog.el-dialog),
:global(.compare-dialog .el-dialog) {
  display: flex;
  flex-direction: column;
  max-height: calc(100vh - 48px);
  margin: 24px auto !important;
}

:global(.compare-dialog .el-dialog__header),
:global(.compare-dialog.el-dialog .el-dialog__header),
:global(.compare-dialog .el-dialog__footer),
:global(.compare-dialog.el-dialog .el-dialog__footer) {
  flex: 0 0 auto;
}

:global(.compare-dialog .el-dialog__body),
:global(.compare-dialog.el-dialog .el-dialog__body) {
  flex: 1 1 auto;
  min-height: 0;
  overflow: hidden;
  padding-top: 0;
  padding-bottom: 0;
}

:global(.compare-dialog .el-table),
:global(.compare-dialog.el-dialog .el-table) {
  height: 100% !important;
}

:global(.compare-dialog .el-table__inner-wrapper),
:global(.compare-dialog.el-dialog .el-table__inner-wrapper) {
  height: 100%;
}

:global(.compare-dialog .el-table .cell),
:global(.compare-dialog.el-dialog .el-table .cell) {
  line-height: 1.45;
  word-break: normal;
}

.diff-content {
  display: grid;
  grid-template-rows: repeat(2, auto);
  gap: 6px;
  padding: 8px;
  min-width: 140px;
  background-color: rgba(245, 158, 11, 0.08);
  border: 1px solid rgba(245, 158, 11, 0.18);
  border-radius: 4px;
}

.diff-item {
  display: grid;
  grid-template-columns: 48px minmax(0, 1fr);
  align-items: start;
  gap: 8px;
}

.diff-label {
  color: #909399;
  font-size: 12px;
  line-height: 1.45;
  white-space: nowrap;
}

.diff-value {
  color: #303133;
  font-weight: 500;
  line-height: 1.45;
  word-break: normal;
  overflow-wrap: anywhere;
  text-align: left;
}

:global(html.dark) .diff-content {
  background: rgba(245, 158, 11, 0.09);
  border-color: rgba(245, 158, 11, 0.22);
}

:global(html.dark) .diff-label {
  color: rgba(203, 213, 225, 0.70);
}

:global(html.dark) .diff-value {
  color: rgba(241, 245, 249, 0.92);
}

.progress-text {
  margin-top: 8px;
  color: var(--el-text-color-secondary);
}
</style>
