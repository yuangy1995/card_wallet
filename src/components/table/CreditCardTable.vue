<template>
  <div class="table-container credit-card-table">
    <el-table 
      :data="tableData" 
      style="width: 100%" 
      border
      height="calc(100vh - 250px)"
      @row-dblclick="handleRowDoubleClick"
      class="mobile-optimized"
      @row-contextmenu="handleContextMenu"
      @sort-change="handleSortChange"
      :default-sort="{ prop: sortState.key, order: sortState.order }"
      :row-class-name="rowClassName"
      @selection-change="handleSelectionChange"
      :span-method="spanMethod"
      ref="tableRef"
    >
      <el-table-column type="selection" width="55" align="center" fixed />
      <el-table-column type="index" label="序号" width="60" align="center" fixed />
      <template v-for="column in columns" :key="column.value">
        <el-table-column
          v-if="isColumnVisible(column.value)"
          :prop="column.value"
          :label="column.label"
          :width="getColumnWidth(column.value)"
          :min-width="getColumnMinWidth(column.value)"
          align="center"
          :fixed="isColumnFixed(column.value)"
          :sortable="isSortable(column.value)"
          :class-name="getColumnClass(column.value)"
          :sort-method="getSortMethod(column.value)"
        >
          <template v-if="column.value === 'cardNumber'" #default="scope">
            <SecureField 
              :id="`card-number-${scope.$index}`"
              :value="scope.row.cardNumber"
              :mask-start="4"
              :mask-end="12"
              type="cardNumber"
              @visibility-change="(visible) => handleVisibilityChange({ id: scope.row.id, isVisible: visible, type: 'cardNumber' })"
            />
          </template>
          <template v-else-if="column.value === 'cvv'" #default="scope">
            <SecureField 
              :id="`cvv-${scope.$index}`"
              :value="scope.row.cvv"
              :mask-all="true"
              type="cvv"
              @visibility-change="(visible) => handleVisibilityChange({ id: scope.row.id, isVisible: visible, type: 'cvv' })"
            />
          </template>
          <template v-else-if="column.value === 'lastTime'" #default="{ row }">
            <div v-if="row.lastTime" style="display: flex; flex-direction: column; align-items: center;">
              <span>{{ row.lastTime }}</span>
              <span style="color: #909399; font-size: 12px;">
                ({{ getDaysFromNow(row.lastTime).text }}{{ getDaysFromNow(row.lastTime).days }}天)
              </span>
            </div>
            <span v-else>-</span>
          </template>
          <template v-else-if="column.value === 'lastModifyTime'" #default="{ row }">
            <div v-if="row.lastModifyTime" style="display: flex; flex-direction: column; align-items: center;">
              <span>{{ row.lastModifyTime }}</span>
            </div>
            <span v-else>-</span>
          </template>
          <template v-else-if="column.value === 'bank'" #default="{ row }">
            <span>{{ row.bank.replace(/\(.*?\)/g, "").trim() }}</span>
          </template>
          <template v-else-if="column.value === 'isQualified'" #default="{ row }">
            <el-tag v-if="row.isQualified === '1'" type="success">已达标</el-tag>
            <el-tag v-if="row.isQualified === '2'" type="danger">未达标</el-tag>
            <el-tag v-if="row.isQualified === '3'" type="info">终免年费</el-tag>
          </template>
          <template v-else-if="column.value === 'interestFreePeriod'" #default="{ row }">
            <span>{{ calculateInterestFreePeriod(row.accountBillDate, row.dueDate) }}</span>
          </template>
          <template v-else-if="column.value === 'nextAnnualFeeCollectionTime'" #default="{ row }">
            <div style="display: flex; flex-direction: column; align-items: center;">
              <span>{{ row.nextAnnualFeeCollectionTime }}</span>
              <span style="color: #909399; font-size: 12px;">
                (距离收取年费{{ getDaysFromNow(row.nextAnnualFeeCollectionTime).text }}{{ getDaysFromNow(row.nextAnnualFeeCollectionTime).days }}天)
              </span>
            </div>
          </template>
          <template v-else-if="column.value === 'valid'" #default="{ row }">
            <span>{{ formatValidDate(row.valid) }}</span>
          </template>
        </el-table-column>
      </template>
    </el-table>

    <!-- 右键菜单 -->
    <div 
      v-show="contextMenuVisible"
      class="context-menu"
      :style="{ left: contextMenuX + 'px', top: contextMenuY + 'px' }"
    >
      <el-menu>
        <el-menu-item v-if="showAnnualFeeOption" @click="handleSetAnnualFeeQualified">
          <el-icon><Check /></el-icon>
          <span>设置年费已达标</span>
        </el-menu-item>
        <el-menu-item @click="handleContextMenuAction('edit')">
          <el-icon><Edit /></el-icon>
          <span>编辑</span>
        </el-menu-item>
        <el-menu-item @click="handleContextMenuAction('delete')">
          <el-icon><Delete /></el-icon>
          <span>删除</span>
        </el-menu-item>
        <el-menu-item @click="handleContextMenuAction('details')">
          <el-icon><View /></el-icon>
          <span>查看详情</span>
        </el-menu-item>
      </el-menu>
    </div>
  </div>
</template>

<script>
import SecureField from '../common/SecureField.vue'
import { ElMessageBox } from 'element-plus'
import { Edit, View, Delete, Check } from '@element-plus/icons-vue'
import { ref, computed, nextTick, onMounted, watch, toRef } from 'vue'
import { daysBetween } from '../../utils/dateUtils'
import { getDaysFromNow, formatValidDate } from '../../utils/dateCalculator'
import { creditCardOptions } from '@/config/creditCardOptions'
import { cardDataCache } from '@/utils/cache'

// 获取卡片类型权重
function getCardTypeWeight(cardNumber) {
  const types = {
    'visa': 1,
    'mastercard': 2,
    'amex': 3,
    'discover': 4,
    'unionpay': 5,
    'jcb': 6
  }
  
  if (!cardNumber) return 999 // 无卡号排最后
  
  const cleanNumber = cardNumber.replace(/\D/g, '')
  for (const [type, pattern] of Object.entries(CARD_TYPES)) {
    if (pattern.test(cleanNumber)) {
      return types[type] || 999
    }
  }
  return 999 // 未知类型排最后
}

// 解析有效期为日期对象
function parseValidDate(valid) {
  if (!valid) return new Date(0) // 无效期排最前
  const [year, month] = valid.split('-')
  return new Date(year, month - 1)
}

// 解析年费
function parseAnnualFee(fee) {
  if (!fee) return 0
  const num = parseFloat(fee)
  return isNaN(num) ? 0 : num
}

// 计算免息期天数
function calculateInterestFreePeriodDays(accountBillDate, dueDate) {
  if (!accountBillDate || !dueDate) return 0
  
  const today = new Date()
  const currentDay = today.getDate()
  const currentMonth = today.getMonth()
  const currentYear = today.getFullYear()
  
  const billingDay = parseInt(accountBillDate)
  const repaymentDay = parseInt(dueDate)
  
  if (isNaN(billingDay) || isNaN(repaymentDay)) return 0
  
  // 计算下一个还款日
  let repaymentDate = new Date(currentYear, currentMonth, repaymentDay)
  
  // 如果今天超过了本月的账单日，则计算下个月的还款日
  if (currentDay > billingDay) {
    repaymentDate.setMonth(repaymentDate.getMonth() + 1)
  }
  
  // 账单日当天的消费按当期账单计算
  if (currentDay === billingDay) {
    repaymentDate = new Date(currentYear, currentMonth, repaymentDay)
    if (repaymentDay < billingDay) {
      repaymentDate.setMonth(repaymentDate.getMonth() + 1)
    }
  }
  
  // 计算天数差
  const diffTime = repaymentDate.getTime() - today.getTime()
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
  
  return diffDays
}

// 计算免息期
function calculateInterestFreePeriod(billingDay, repaymentDay) {
  // 如果账单日或还款日未设置，返回 '-'
  if (!billingDay || !repaymentDay) {
    return '-'
  }

  // 将字符串转换为数字
  billingDay = parseInt(billingDay)
  repaymentDay = parseInt(repaymentDay)

  // 获取当前日期
  const today = new Date()
  const currentYear = today.getFullYear()
  const currentMonth = today.getMonth()
  const currentDay = today.getDate()

  // 获取当月的最后一天
  const lastDayOfMonth = new Date(currentYear, currentMonth + 1, 0).getDate()

  // 确保账单日和还款日不超过当月天数
  billingDay = Math.min(billingDay, lastDayOfMonth)
  repaymentDay = Math.min(repaymentDay, lastDayOfMonth)

  // 计算下一个账单日
  let nextBillingDate
  if (currentDay >= billingDay) {
    // 如果当前日期大于等于账单日，下一个账单日在下个月
    nextBillingDate = new Date(currentYear, currentMonth + 1, billingDay)
  } else {
    // 如果当前日期小于账单日，下一个账单日在当月
    nextBillingDate = new Date(currentYear, currentMonth, billingDay)
  }

  // 计算还款日期
  let repaymentDate = new Date(nextBillingDate)
  if (repaymentDay < billingDay) {
    // 如果还款日小于账单日，还款日在下个月
    repaymentDate.setMonth(repaymentDate.getMonth() + 1)
  }
  repaymentDate.setDate(repaymentDay)

  if (currentDay === billingDay) {
    repaymentDate = new Date(currentYear, currentMonth, repaymentDay)
    if (repaymentDay < billingDay) {
      repaymentDate.setMonth(repaymentDate.getMonth() + 1)
    }
  }

  // 计算天数差
  const diffTime = repaymentDate.getTime() - today.getTime()
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

  return diffDays
}

export default {
  name: 'CreditCardTable',
  components: {
    SecureField,
    Edit,
    View,
    Delete,
    Check
  },
  props: {
    tableData: {
      type: Array,
      required: true
    },
    rowClassName: {
      type: Function,
      default: null
    },
    visibleColumns: {
      type: Array,
      default: () => []
    }
  },
  emits: ['edit', 'delete', 'card-number-visibility', 'cvv-visibility', 'view-details', 'annual-fee-qualified'],
  setup(props, { emit }) {
    const contextMenuVisible = ref(false)
    const contextMenuX = ref(0)
    const contextMenuY = ref(0)
    const selectedRow = ref(null)

    let cleanupClickListener = null

    const sortState = ref({
      key: localStorage.getItem('creditCardTableSortKey') || '',
      order: localStorage.getItem('creditCardTableSortOrder') || ''
    })

    const columns = creditCardOptions.tableCustomData

    const isColumnVisible = (columnValue) => {
      return props.visibleColumns.includes(columnValue)
    }

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
        case 'nextAnnualFeeCollectionTime': return '170'
        case 'lastTime': return '170'
        case 'lastModifyTime': return '170'
        case 'isQualified': return '130'
        case 'equity': return '200'
        case 'remark': return '200'
        case 'interestFreePeriod': return '150'
        default: return '150'
      }
    }

    const getColumnMinWidth = (columnValue) => {
      switch (columnValue) {
        case 'country': return '80'
        case 'bank': return '100'
        case 'alias': return '120'
        case 'level': return '80'
        case 'type': return '100'
        case 'annualFee': return '70'
        case 'cardNumber': return '180'
        case 'valid': return '90'
        case 'cvv': return '80'
        case 'limit': return '80'
        case 'nextAnnualFeeCollectionTime': return '120'
        case 'lastTime': return '120'
        case 'lastModifyTime': return '120'
        case 'isQualified': return '100'
        case 'equity': return '120'
        case 'remark': return '120'
        case 'interestFreePeriod': return '100'
        default: return '100'
      }
    }

    const isColumnFixed = (columnValue) => {
      return ['country', 'bank', 'alias'].includes(columnValue)
    }

    const isSortable = (columnValue) => {
      return ['country', 'bank', 'level', 'type', 'annualFee', 'cardNumber', 'valid', 'interestFreePeriod'].includes(columnValue)
    }

    const isColumnSortable = (columnValue) => {
      return isSortable(columnValue)
    }

    function getSortMethod(columnValue) {
      switch (columnValue) {
        case 'type':
          return (a, b) => {
            const weightA = getCardTypeWeight(a.cardNumber) || 999
            const weightB = getCardTypeWeight(b.cardNumber) || 999
            return weightA - weightB
          }
        case 'annualFee':
          return (a, b) => {
            const feeA = parseAnnualFee(a.annualFee)
            const feeB = parseAnnualFee(b.annualFee)
            return feeA - feeB
          }
        case 'interestFreePeriod':
          return (a, b) => {
            const daysA = calculateInterestFreePeriodDays(a.accountBillDate, a.dueDate) || 0
            const daysB = calculateInterestFreePeriodDays(b.accountBillDate, b.dueDate) || 0
            return daysA - daysB
          }
        default:
          return undefined
      }
    }

    // 获取列的响应式类名
    function getColumnClass(columnValue) {
      const mobileHiddenColumns = ['equity', 'remark', 'lastTime', 'lastModifyTime']
      const tabletHiddenColumns = ['lastModifyTime']
      
      let classes = []
      
      if (mobileHiddenColumns.includes(columnValue)) {
        classes.push('mobile-hidden')
      }
      
      if (tabletHiddenColumns.includes(columnValue)) {
        classes.push('tablet-hidden')
      }
      
      return classes.join(' ')
    }

    // 自定义排序方法
    const sortMethods = {
      cardNumber: (a, b) => {
        const weightA = getCardTypeWeight(a.cardNumber)
        const weightB = getCardTypeWeight(b.cardNumber)
        return weightA - weightB
      },
      valid: (a, b) => {
        const dateA = parseValidDate(a.valid)
        const dateB = parseValidDate(b.valid)
        return dateA - dateB
      },
      annualFee: (a, b) => {
        const feeA = parseAnnualFee(a.annualFee)
        const feeB = parseAnnualFee(b.annualFee)
        return feeA - feeB
      }
    }

    const showAnnualFeeOption = computed(() => {
      if (!selectedRow.value) return false
      // 只在未达标的情况下显示
      return selectedRow.value.isQualified === '2'
    })

    // 处理双击行事件
    const handleRowDoubleClick = (row) => {
      emit('view-details', row)
    }

    // 表格引用和选中的行
    const tableRef = ref(null)
    const selectedRows = ref([])
    
    // 处理选中行变化
    const handleSelectionChange = (selection) => {
      selectedRows.value = selection
      emit('selection-change', selection)
    }
    
    // 批量操作方法
    const toggleSelectAll = () => {
      if (tableRef.value && tableRef.value.toggleRowSelection) {
        if (selectedRows.value.length === props.tableData.length) {
          tableRef.value.clearSelection()
        } else {
          nextTick(() => {
            props.tableData.forEach(row => {
              if (tableRef.value && tableRef.value.toggleRowSelection) {
                tableRef.value.toggleRowSelection(row, true)
              }
            })
          })
        }
      }
    }
    
    const clearSelection = () => {
      if (tableRef.value) {
        tableRef.value.clearSelection()
      }
    }

    // 处理右键菜单显示
    const handleContextMenu = (row, column, event) => {
      event.preventDefault()
      selectedRow.value = row
      contextMenuX.value = event.clientX
      contextMenuY.value = event.clientY
      contextMenuVisible.value = true

      // 点击其他地方时关闭菜单
      const closeMenu = () => {
        contextMenuVisible.value = false
        cleanupClickListener = null
      }
      
      // 清理之前的监听器
      if (cleanupClickListener) {
        cleanupClickListener()
      }
      
      // 添加新的监听器并保存清理函数
      document.addEventListener('click', closeMenu)
      cleanupClickListener = () => {
        document.removeEventListener('click', closeMenu)
      }
    }

    // 处理右键菜单动作
    const handleContextMenuAction = (action) => {
      if (!selectedRow.value) return

      switch (action) {
        case 'edit':
          emit('edit', selectedRow.value)
          break
        case 'delete':
          emit('delete', selectedRow.value)
          break
        case 'details':
          emit('view-details', selectedRow.value)
          break
      }
      
      contextMenuVisible.value = false
    }

    const handleSetAnnualFeeQualified = () => {
      // 更新年费达标状态和下次收取时间
      selectedRow.value.isQualified = '1'
      if (selectedRow.value.nextAnnualFeeCollectionTime) {
        const nextDate = new Date(selectedRow.value.nextAnnualFeeCollectionTime)
        nextDate.setFullYear(nextDate.getFullYear() + 1)
        selectedRow.value.nextAnnualFeeCollectionTime = nextDate.toISOString().split('T')[0]
      }
      emit('annual-fee-qualified', selectedRow.value.id)
      contextMenuVisible.value = false
    }

    // 处理可见性变化
    const handleVisibilityChange = ({ id, isVisible, type }) => {
      if (type === 'cardNumber') {
        emit('card-number-visibility', { id, isVisible })
      } else if (type === 'cvv') {
        emit('cvv-visibility', { id, isVisible })
      }
    }

    // 处理排序变化
    const handleSortChange = ({ prop, order }) => {
      sortState.value = { key: prop, order }
      // 保存排序状态
      localStorage.setItem('creditCardTableSortKey', prop)
      localStorage.setItem('creditCardTableSortOrder', order)
    }

    // 行样式类名
    const rowClassName = ({ row }) => {
      return props.rowClassName({ row });
    }

    // 表格合并单元格方法
    const spanMethod = ({ row, column, rowIndex, columnIndex }) => {
      // 国家列合并
      if (column.property === 'country') {
        if (row.showCountry) {
          return {
            rowspan: row.countryRowSpan,
            colspan: 1
          }
        } else {
          return {
            rowspan: 0,
            colspan: 0
          }
        }
      }
      // 银行列合并
      else if (column.property === 'bank') {
        if (row.showBank) {
          return {
            rowspan: row.bankRowSpan,
            colspan: 1
          }
        } else {
          return {
            rowspan: 0,
            colspan: 0
          }
        }
      }
      // 额度列合并（只有共享额度的才合并）
      else if (column.property === 'limit') {
        if (row.isSharedLimit) {
          if (row.showLimit) {
            return {
              rowspan: row.limitRowSpan,
              colspan: 1
            }
          } else {
            return {
              rowspan: 0,
              colspan: 0
            }
          }
        } else {
          // 独立额度不合并
          return {
            rowspan: 1,
            colspan: 1
          }
        }
      }
      // 其他列不合并
      return {
        rowspan: 1,
        colspan: 1
      }
    }

    // 初始化时恢复排序状态
    onMounted(() => {
      if (sortState.value.key && sortState.value.order) {
        // 这里需要获取表格实例并设置排序
        // 如果使用 el-table ref，可以调用 sort 方法
      }
    })

    return {
      tableData: toRef(props, 'tableData'),
      visibleColumns: toRef(props, 'visibleColumns'),
      handleEdit: (row) => emit('edit', row),
      handleDelete: (row) => emit('delete', row),
      handleVisibilityChange: (data) => {
        if (data.type === 'cardNumber') {
          emit('card-number-visibility', data)
        } else if (data.type === 'cvv') {
          emit('cvv-visibility', data)
        }
      },
      handleViewDetails: (row) => emit('view-details', row),
      handleAnnualFeeQualified: (cardId) => emit('annual-fee-qualified', cardId),
      rowClassName: props.rowClassName,
      columns,
      isColumnVisible,
      getColumnWidth,
      getColumnMinWidth,
      isSortable,
      isColumnFixed,
      isColumnSortable,
      getSortMethod,
      getColumnClass,
      sortMethods,
      formatValidDate,
      getDaysFromNow,
      handleRowDoubleClick,
      handleContextMenu,
      handleSortChange,
      sortState,
      parseAnnualFee,
      calculateInterestFreePeriodDays,
      calculateInterestFreePeriod,
      contextMenuVisible,
      contextMenuX,
      contextMenuY,
      selectedRow,
      showAnnualFeeOption,
      tableRef,
      selectedRows,
      handleSelectionChange,
      toggleSelectAll,
      clearSelection,
      handleContextMenuAction,
      spanMethod
    }
  }
}
</script>

<style lang="scss" scoped>
.credit-card-table {
  width: 100%;
  position: relative;
}

.context-menu {
  position: fixed;
  z-index: 3000;
  background: white;
  border-radius: 4px;
  box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
  
  .el-menu {
    border: none;
    padding: 4px 0;
    min-width: 120px;
  }

  .el-menu-item {
    height: 36px;
    line-height: 36px;
    padding: 0 16px;
    display: flex;
    align-items: center;
    gap: 8px;
    
    &:hover {
      background-color: var(--el-menu-hover-bg-color);
    }

    .el-icon {
      margin-right: 4px;
      font-size: 16px;
    }
  }
}

:deep(.el-table) {
  --el-table-border-color: var(--el-border-color-lighter);
  --el-table-border: 1px solid var(--el-table-border-color);
  --el-table-text-color: var(--el-text-color-regular);
  --el-table-header-text-color: var(--el-text-color-secondary);
  --el-table-row-hover-bg-color: var(--el-fill-color-light);
  
  th {
    background-color: var(--el-fill-color-light);
    font-weight: bold;
  }
  
  td {
    padding: 8px 0;
  }
}
</style>
