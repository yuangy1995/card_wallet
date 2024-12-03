<template>
  <el-dialog
    v-model="visible"
    title="操作历史记录"
    width="80%"
    :close-on-click-modal="false"
    :close-on-press-escape="false"
  >
    <div class="header-actions" v-if="isDev">
      <el-button type="danger" @click="clearHistory" size="small">
        清除历史记录
      </el-button>
    </div>
    <el-table :data="historyList" style="width: 100%">
      <el-table-column prop="timestamp" label="操作时间" width="180" />
      <el-table-column prop="type" label="操作类型" width="120" />
      <el-table-column prop="description" label="操作描述" />
      <el-table-column label="操作" width="200" fixed="right">
        <template #default="scope">
          <el-button @click="handleCompare(scope.row)" size="small">比对</el-button>
          <el-button @click="handleRestore(scope.row)" size="small" type="warning"
            >恢复</el-button
          >
        </template>
      </el-table-column>
    </el-table>

    <!-- 比对弹窗 -->
    <el-dialog v-model="compareDialogVisible" title="数据比对" width="90%" append-to-body>
      <div class="compare-content">
        <el-descriptions title="操作信息" :column="1" border>
          <el-descriptions-item label="操作时间">
            {{ currentCompareData?.timestamp }}
          </el-descriptions-item>
          <el-descriptions-item label="操作类型">
            {{ currentCompareData?.type }}
          </el-descriptions-item>
          <el-descriptions-item label="操作描述">
            {{ currentCompareData?.description }}
          </el-descriptions-item>
        </el-descriptions>
        
        <div class="data-diff" v-if="diffResult.length > 0">
          <h3>数据变更详情：</h3>
          <el-tabs type="border-card">
            <el-tab-pane label="变更总览">
              <el-table :data="diffResult" style="width: 100%">
                <el-table-column type="expand">
                  <template #default="props">
                    <div class="diff-details">
                      <template v-if="props.row.changeType === '修改'">
                        <el-row :gutter="20" class="diff-row" v-for="(value, key) in props.row.details" :key="key">
                          <el-col :span="6">
                            <span class="label">{{ key }}：</span>
                          </el-col>
                          <el-col :span="9">
                            <div class="old-value">
                              <span class="diff-label">原值：</span>
                              <span :class="{'diff-deleted': value.old !== value.new}">{{ value.old }}</span>
                            </div>
                          </el-col>
                          <el-col :span="9">
                            <div class="new-value">
                              <span class="diff-label">新值：</span>
                              <span :class="{'diff-added': value.old !== value.new}">{{ value.new }}</span>
                            </div>
                          </el-col>
                        </el-row>
                      </template>
                      <template v-else>
                        <el-descriptions :column="2" border>
                          <el-descriptions-item 
                            v-for="(value, key) in props.row.details" 
                            :key="key"
                            :label="key"
                          >
                            {{ value }}
                          </el-descriptions-item>
                        </el-descriptions>
                      </template>
                    </div>
                  </template>
                </el-table-column>
                <el-table-column prop="cardNumber" label="卡号" width="180" />
                <el-table-column prop="bank" label="发卡行" width="150" />
                <el-table-column prop="changeType" label="变更类型" width="100" />
                <el-table-column prop="summary" label="变更摘要" />
              </el-table>
            </el-tab-pane>
            <el-tab-pane label="数据对比">
              <div class="compare-tables">
                <div class="compare-table">
                  <h4>原数据</h4>
                  <el-table :data="oldData" style="width: 100%" size="small">
                    <el-table-column
                      v-for="col in tableColumns"
                      :key="col.prop"
                      :prop="col.prop"
                      :label="col.label"
                      :width="col.width"
                    />
                  </el-table>
                </div>
                <div class="compare-table">
                  <h4>当前数据</h4>
                  <el-table :data="newData" style="width: 100%" size="small">
                    <el-table-column
                      v-for="col in tableColumns"
                      :key="col.prop"
                      :prop="col.prop"
                      :label="col.label"
                      :width="col.width"
                    />
                  </el-table>
                </div>
              </div>
            </el-tab-pane>
          </el-tabs>
        </div>
        <div v-else class="no-diff">
          <el-empty description="没有发现数据差异" />
        </div>
      </div>
    </el-dialog>
  </el-dialog>
</template>

<script setup>
import { ref, computed } from 'vue'
import { ElMessageBox, ElMessage } from 'element-plus'
import { creditCardOptions } from '@/config/creditCardOptions'

const visible = ref(false)
const compareDialogVisible = ref(false)
const currentCompareData = ref(null)
const historyList = ref([])
const currentCardData = ref([])
const diffResult = ref([])
const oldData = ref([])
const newData = ref([])
const tableColumns = ref([
  { prop: 'cardNumber', label: '卡号', width: '180' },
  { prop: 'bank', label: '发卡行', width: '150' },
  { prop: 'country', label: '国家', width: '120' },
  { prop: 'cardType', label: '卡类型', width: '120' },
  { prop: 'level', label: '卡片等级', width: '120' },
  { prop: 'billDay', label: '账单日', width: '100' },
  { prop: 'repaymentDay', label: '还款日', width: '100' },
  { prop: 'creditLimit', label: '额度', width: '120' },
  { prop: 'annualFee', label: '年费', width: '120' },
  { prop: 'isQualified', label: '年费减免资格', width: '120' },
  { prop: 'cardStatus', label: '卡片状态', width: '120' }
])

const fieldNameMap = {
  cardNumber: '卡号',
  bank: '发卡行',
  country: '国家',
  cardType: '卡类型',
  billDay: '账单日',
  repaymentDay: '还款日',
  creditLimit: '额度',
  annualFee: '年费',
  isQualified: '年费减免资格',
  cardStatus: '卡片状态',
  level: '卡片等级',
  alias: '卡片别名',
  cvv: '安全码',
  validityPeriod: '有效期'
}

const getFieldValueLabel = (field, value) => {
  switch (field) {
    case 'country':
      return creditCardOptions.countryData.find(item => item.name === value)?.chineseName || value
    case 'bank':
      return creditCardOptions.bankList.find(item => item.name === value)?.chineseName || value
    case 'isQualified':
      return value === '1' ? '已达标' : '未达标'
    case 'cardStatus':
      return value === '1' ? '正常' : '已注销'
    case 'level':
      return creditCardOptions.cardLevel.find(item => item.name === value)?.chineseName || value
    case 'cardType':
      return creditCardOptions.cardType.find(item => item.name === value)?.chineseName || value
    default:
      return value
  }
}

const getFieldLabel = (field) => {
  return fieldNameMap[field] || field
}

const compareData = (oldData, newData) => {
  console.log('Old Data:', oldData)
  console.log('New Data:', newData)
  
  const result = []
  
  // 确保数据是数组
  const oldArray = Array.isArray(oldData) ? oldData : []
  const newArray = Array.isArray(newData) ? newData : []
  
  // 创建ID到对象的映射，以提高查找效率
  const oldMap = new Map(oldArray.map(card => [card.id, card]))
  const newMap = new Map(newArray.map(card => [card.id, card]))
  
  // 检查删除的卡
  for (const [id, oldCard] of oldMap) {
    if (!newMap.has(id)) {
      result.push({
        cardNumber: oldCard.cardNumber,
        bank: getFieldValueLabel('bank', oldCard.bank),
        changeType: '删除',
        summary: '该卡片被删除',
        details: Object.entries(oldCard).reduce((acc, [key, value]) => {
          if (fieldNameMap[key]) {
            acc[getFieldLabel(key)] = getFieldValueLabel(key, value)
          }
          return acc
        }, {})
      })
    }
  }

  // 检查新增和修改的卡
  for (const [id, newCard] of newMap) {
    const oldCard = oldMap.get(id)
    if (!oldCard) {
      result.push({
        cardNumber: newCard.cardNumber,
        bank: getFieldValueLabel('bank', newCard.bank),
        changeType: '新增',
        summary: '新增卡片',
        details: Object.entries(newCard).reduce((acc, [key, value]) => {
          if (fieldNameMap[key]) {
            acc[getFieldLabel(key)] = getFieldValueLabel(key, value)
          }
          return acc
        }, {})
      })
    } else {
      // 检查是否有修改
      const changes = {}
      let hasChanges = false
      let changeSummary = []
      
      // 先检查卡号变更
      if (oldCard.cardNumber !== newCard.cardNumber) {
        changes[getFieldLabel('cardNumber')] = {
          old: oldCard.cardNumber,
          new: newCard.cardNumber
        }
        hasChanges = true
        changeSummary.push(`卡号从 ${oldCard.cardNumber} 变更为 ${newCard.cardNumber}`)
      }
      
      // 再检查其他字段变更
      for (const key of Object.keys(fieldNameMap)) {
        if (key === 'cardNumber') continue // 跳过卡号，因为已经处理过了
        
        const oldValue = oldCard[key]
        const newValue = newCard[key]
        
        // 特殊处理数组和对象类型的比较
        let isDifferent = false
        if (Array.isArray(oldValue) || Array.isArray(newValue)) {
          isDifferent = JSON.stringify(oldValue || []) !== JSON.stringify(newValue || [])
        } else if (oldValue && typeof oldValue === 'object' || newValue && typeof newValue === 'object') {
          isDifferent = JSON.stringify(oldValue || {}) !== JSON.stringify(newValue || {})
        } else {
          isDifferent = oldValue !== newValue
        }

        if (isDifferent) {
          changes[getFieldLabel(key)] = {
            old: getFieldValueLabel(key, oldValue),
            new: getFieldValueLabel(key, newValue)
          }
          hasChanges = true
          changeSummary.push(`${getFieldLabel(key)}发生变更`)
        }
      }
      
      if (hasChanges) {
        result.push({
          cardNumber: oldCard.cardNumber, // 使用旧卡号，这样更容易找到是哪张卡被修改了
          bank: getFieldValueLabel('bank', oldCard.bank),
          changeType: '修改',
          summary: changeSummary.join('、'),
          details: changes
        })
      }
    }
  }

  console.log('Comparison Result:', result)
  return result
}

const formatTableData = (data) => {
  return data.map(item => {
    const formattedItem = { ...item }
    Object.keys(formattedItem).forEach(key => {
      if (fieldNameMap[key]) {
        formattedItem[key] = getFieldValueLabel(key, formattedItem[key])
      }
    })
    return formattedItem
  })
}

const handleCompare = (row) => {
  currentCompareData.value = row
  compareDialogVisible.value = true
  
  // 设置比对数据
  const oldDataValue = Array.isArray(row.data) ? row.data : []
  const newDataValue = Array.isArray(currentCardData.value) ? currentCardData.value : []
  
  oldData.value = formatTableData(oldDataValue)
  newData.value = formatTableData(newDataValue)
  
  // 比较数据差异
  diffResult.value = compareData(oldDataValue, newDataValue)
}

const open = () => {
  visible.value = true
  loadHistoryList()
  // 获取当前信用卡数据
  currentCardData.value = JSON.parse(localStorage.getItem('cardData') || '[]')
}

const loadHistoryList = () => {
  const history = JSON.parse(localStorage.getItem('creditCardHistory') || '[]')
  historyList.value = history
}

const isDev = computed(() => import.meta.env.DEV)

const clearHistory = () => {
  ElMessageBox.confirm('确定要清除所有历史记录吗？', '警告', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning',
  })
    .then(() => {
      localStorage.removeItem('creditCardHistory')
      historyList.value = []
      ElMessage.success('历史记录已清除')
    })
    .catch(() => {
      // 用户取消操作
    })
}

const handleRestore = (row) => {
  ElMessageBox.confirm('此操作将覆盖现有所有数据，是否继续？', '警告', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning',
  })
    .then(() => {
      // 执行恢复操作
      localStorage.setItem('cardData', JSON.stringify(row.data))
      // 记录恢复操作
      const history = JSON.parse(localStorage.getItem('creditCardHistory') || '[]')
      history.unshift({
        timestamp: new Date().toLocaleString(),
        type: '回滚操作',
        description: `回滚到 ${row.timestamp} 的数据状态`,
        data: JSON.parse(JSON.stringify(row.data))
      })
      localStorage.setItem('creditCardHistory', JSON.stringify(history))
      
      ElMessage.success('数据恢复成功')
      // 重新加载历史记录
      loadHistoryList()
      // 通知父组件刷新数据
      emit('update', row.data)
    })
    .catch(() => {
      // 用户取消操作
    })
}

const emit = defineEmits(['update'])

defineExpose({
  open,
})
</script>

<style scoped>
.header-actions {
  margin-bottom: 16px;
}

.compare-content {
  margin-top: 16px;
  max-height: calc(90vh - 200px); /* 设置最大高度，留出标题和底部按钮的空间 */
  overflow-y: auto;
  padding-right: 16px; /* 为滚动条预留空间 */
}

.data-diff {
  margin-top: 24px;
}

.diff-details {
  padding: 20px;
}

.diff-row {
  margin-bottom: 12px;
}

.label {
  font-weight: bold;
}

.diff-label {
  color: #666;
  margin-right: 8px;
}

.diff-deleted {
  color: #f56c6c;
  text-decoration: line-through;
}

.diff-added {
  color: #67c23a;
}

/* 表格横向滚动样式 */
.el-table {
  width: 100% !important;
}

:deep(.el-table__body-wrapper) {
  overflow-x: auto !important;
}

:deep(.el-table__header-wrapper) {
  overflow-x: auto !important;
}

.compare-tables {
  display: flex;
  gap: 20px;
  overflow-x: auto;
  margin-top: 16px;
}

.compare-table {
  flex: 1;
  min-width: 300px;
}

/* 确保表格内容不会被截断 */
:deep(.el-table .cell) {
  white-space: nowrap;
}

/* 优化表格展开行的样式 */
:deep(.el-table__expanded-cell) {
  padding: 20px !important;
}

:deep(.el-descriptions) {
  width: 100%;
}

:deep(.el-descriptions__cell) {
  min-width: 120px;
}

/* 自定义滚动条样式 */
.compare-content::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

.compare-content::-webkit-scrollbar-track {
  background: #f5f7fa;
  border-radius: 4px;
}

.compare-content::-webkit-scrollbar-thumb {
  background: #c0c4cc;
  border-radius: 4px;
}

.compare-content::-webkit-scrollbar-thumb:hover {
  background: #909399;
}

/* 确保内容区域在固定高度内可滚动 */
:deep(.el-tabs__content) {
  overflow: visible;
}

:deep(.el-tab-pane) {
  height: 100%;
}

/* 优化表格在固定容器中的显示 */
:deep(.el-table) {
  margin-bottom: 16px;
}

:deep(.el-table__body) {
  width: 100% !important;
}
</style>
