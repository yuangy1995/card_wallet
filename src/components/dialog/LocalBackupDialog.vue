<template>
  <el-dialog
    v-model="visible"
    title="本地备份管理"
    width="800px"
    :close-on-click-modal="false"
    :append-to-body="true"
    :z-index="2000"
    draggable
    @open="handleOpen"
  >
    <div class="backup-dialog">
      <el-scrollbar height="400px" class="backup-list-container">
        <div v-loading="loading" class="backup-list">
          <template v-if="backupList.length > 0">
            <div
              v-for="backup in backupList"
              :key="backup.timestamp"
              class="backup-item"
            >
              <div class="backup-info">
                <div class="backup-time">{{ formatDate(backup.timestamp) }}</div>
                <div class="backup-meta">
                  <el-tag :type="backup.status === 'success' ? 'success' : 'danger'" size="small">
                    {{ backup.status === 'success' ? '备份成功' : '备份失败' }}
                  </el-tag>
                  <el-tag type="info" size="small" class="card-count">
                    信用卡数量：{{ backup.data.length }}
                  </el-tag>
                </div>
              </div>
              <div class="backup-actions">
                <el-button
                  type="warning"
                  size="small"
                  @click="handleCompare(backup)"
                >
                  预览
                </el-button>
                <el-button
                  type="primary"
                  size="small"
                  @click="handleRestore(backup)"
                >
                  恢复
                </el-button>
              </div>
            </div>
          </template>
          <el-empty v-else description="暂无备份" />
        </div>
      </el-scrollbar>
    </div>

    <!-- 比对对话框 -->
    <el-dialog
      v-model="compareDialogVisible"
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
              v-for="col in tableColumns"
              :key="col.value"
              :prop="col.value"
              :label="col.label"
              :min-width="getColumnWidth(col.value)"
            >
              <template #default="{ row }">
                {{ formatColumnValue(row[col.value], col.value) }}
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

    <!-- 恢复确认对话框 -->
    <el-dialog
      v-model="restoreConfirmVisible"
      title="恢复确认"
      width="400px"
      append-to-body
    >
      <div class="restore-confirm-content">
        <p>确定要恢复到此备份版本吗？当前数据将被完全覆盖。</p>
      </div>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="restoreConfirmVisible = false">取消</el-button>
          <el-button type="primary" @click="confirmRestore">确定</el-button>
        </span>
      </template>
    </el-dialog>

    <template #footer>
      <span class="dialog-footer">
        <el-button @click="visible = false">关闭</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, inject, watch } from 'vue'
import { BACKUP_CONSTANTS } from '@/config/constants'
import { ElMessage } from 'element-plus'
import { creditCardOptions } from '@/config/creditCardOptions'
import { useAutoLock } from '@/composables/useAutoLock'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['update:modelValue', 'restore'])
const providedAutoLock = inject('autoLock', null)
const { isLocked } = providedAutoLock || useAutoLock()

// 对话框可见性
const visible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

// 状态变量
const loading = ref(false)
const backupList = ref([])
const compareDialogVisible = ref(false)
const restoreConfirmVisible = ref(false)
const comparisonData = ref([])
const selectedBackup = ref(null)
const tableColumns = creditCardOptions.tableCustomData

const closeAll = () => {
  visible.value = false
  compareDialogVisible.value = false
  restoreConfirmVisible.value = false
  comparisonData.value = []
  selectedBackup.value = null
  loading.value = false
}

// 格式化日期
const formatDate = (timestamp) => {
  const date = new Date(timestamp)
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })
}

// 加载备份列表
const loadBackupList = () => {
  loading.value = true
  try {
    const backups = JSON.parse(localStorage.getItem('cardDataBackups') || '[]')
    backupList.value = backups.slice(0, BACKUP_CONSTANTS.MAX_BACKUP_COUNT) // 只保留最近50条备份
  } catch (error) {
    console.error('加载备份列表失败:', error)
    ElMessage.error('加载备份列表失败')
  } finally {
    loading.value = false
  }
}

  // 比对数据
  const handleCompare = (backup) => {
    if (!backup || !backup.data) return
    
    const currentData = JSON.parse(localStorage.getItem('cardData') || '[]')
  const backupData = backup.data

  // 创建一个Map用于快速查找当前数据
  const currentMap = new Map(currentData.map(item => [item.id, item]))
  const backupMap = new Map(backupData.map(item => [item.id, item]))
  
  const comparedData = []

  // 检查删除和修改的数据
  backupData.forEach(backupItem => {
    const currentItem = currentMap.get(backupItem.id)
    if (!currentItem) {
      // 已删除的数据
      comparedData.push({
        ...backupItem,
        _status: 'deleted'
      })
    } else {
      // 检查是否有修改
      const hasChanges = Object.keys(backupItem).some(key => 
        JSON.stringify(backupItem[key]) !== JSON.stringify(currentItem[key])
      )
      if (hasChanges) {
        comparedData.push({
          ...backupItem,
          _status: 'modified'
        })
      } else {
        comparedData.push({
          ...backupItem,
          _status: 'unchanged'
        })
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
    }
  })

  comparisonData.value = comparedData
  compareDialogVisible.value = true
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
        default: return value
      }
    case 'limit':
    case 'annualFee':
      return value.toLocaleString()
    case 'valid':
      return typeof value === 'string' ? value : (value ?? '-')
    default:
      return value
  }
}

// 获取表格单元格的类名
const getTableCellClass = ({ row }) => {
  if (!row._status) return ''
  switch (row._status) {
    case 'deleted':
      return 'comparison-deleted'
    case 'modified':
      return 'comparison-modified'
    case 'added':
      return 'comparison-added'
    default:
      return ''
  }
}

// 处理恢复
const handleRestore = (backup) => {
  selectedBackup.value = backup
  restoreConfirmVisible.value = true
}

// 确认恢复
const confirmRestore = () => {
  if (!selectedBackup.value) return
  
  try {
    localStorage.setItem('cardData', JSON.stringify(selectedBackup.value.data))
    emit('restore', selectedBackup.value.data)
    // 不显示恢复成功消息，避免与 BackupDialog 中的恢复消息重复
    restoreConfirmVisible.value = false
  } catch (error) {
    console.error('恢复失败:', error)
    ElMessage.error('恢复失败')
  }
}

// 对话框打开时加载数据
const handleOpen = () => {
  loadBackupList()
}

defineExpose({
  handleOpen,
  closeAll
})

watch(isLocked, (locked) => {
  if (locked) {
    closeAll()
  }
})
</script>

<style scoped>
.backup-dialog {
  height: 400px;
  display: flex;
  flex-direction: column;

  .backup-list-container {
    flex: 1;
    overflow: hidden;
  }

  .backup-list {
    padding: 0 20px;
  }

  .backup-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 15px;
    border-bottom: 1px solid var(--el-border-color-lighter);

    &:last-child {
      border-bottom: none;
    }
  }

  .backup-info {
    flex: 1;
    margin-right: 20px;
  }

  .backup-time {
    font-size: 14px;
    color: var(--el-text-color-primary);
    margin-bottom: 5px;
  }

  .backup-meta {
    display: flex;
    gap: 10px;
    align-items: center;
    margin-top: 5px;
  }

  .backup-actions {
    display: flex;
    gap: 10px;
    flex-shrink: 0;
  }

  .card-count {
    font-size: 12px;
  }
}

.compare-dialog {
  :deep(.el-dialog__body) {
    padding: 10px;
    overflow: hidden;
  }
}

.compare-container {
  .table-wrapper {
    overflow: hidden;
  }

  :deep(.el-table) {
    .el-table__body-wrapper {
      overflow-x: auto;
      overflow-y: auto;
    }
  }
}

.comparison-deleted {
  background-color: #fef0f0;
  text-decoration: line-through;
  color: #f56c6c;
}

.comparison-modified {
  background-color: #fdf6ec;
}

.comparison-added {
  background-color: #f0f9eb;
}

.restore-confirm-content {
  text-align: center;
  padding: 20px 0;
}
</style>
