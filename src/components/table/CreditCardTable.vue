<template>
  <div class="credit-card-table">
    <el-table 
      :data="tableData" 
      style="width: 100%" 
      border
      height="calc(100vh - 250px)"
      @row-contextmenu="handleContextMenu"
      @sort-change="handleSortChange"
      :default-sort="{ prop: sortState.key, order: sortState.order }"
      :row-class-name="rowClassName"
    >
      <el-table-column type="index" label="序号" width="60" align="center" fixed />
      <template v-for="column in columns" :key="column.value">
        <el-table-column
          v-if="isColumnVisible(column.value)"
          :prop="column.value"
          :label="column.label"
          :width="getColumnWidth(column.value)"
          align="center"
          :fixed="isColumnFixed(column.value)"
          :sortable="isColumnSortable(column.value)"
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
import { ref, onMounted, computed } from 'vue'
import { getDaysFromNow } from '../../utils/dateCalculator'
import { creditCardOptions } from '@/config/creditCardOptions'

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

  // 如果消费日是账单日当天，按当期账单计算
  if (currentDay === billingDay) {
    repaymentDate = new Date(currentYear, currentMonth, repaymentDay)
    if (repaymentDay < billingDay) {
      repaymentDate.setMonth(repaymentDate.getMonth() + 1)
    }
  }

  // 计算天数差
  const diffTime = repaymentDate.getTime() - today.getTime()
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

  return `${diffDays}天`
}

// 计算免息期天数（仅返回数字，用于排序）
function calculateInterestFreePeriodDays(billingDay, repaymentDay) {
  if (!billingDay || !repaymentDay) {
    return 0
  }

  billingDay = parseInt(billingDay)
  repaymentDay = parseInt(repaymentDay)

  const today = new Date()
  const currentYear = today.getFullYear()
  const currentMonth = today.getMonth()
  const currentDay = today.getDate()

  const lastDayOfMonth = new Date(currentYear, currentMonth + 1, 0).getDate()
  billingDay = Math.min(billingDay, lastDayOfMonth)
  repaymentDay = Math.min(repaymentDay, lastDayOfMonth)

  let nextBillingDate
  if (currentDay >= billingDay) {
    nextBillingDate = new Date(currentYear, currentMonth + 1, billingDay)
  } else {
    nextBillingDate = new Date(currentYear, currentMonth, billingDay)
  }

  let repaymentDate = new Date(nextBillingDate)
  if (repaymentDay < billingDay) {
    repaymentDate.setMonth(repaymentDate.getMonth() + 1)
  }
  repaymentDate.setDate(repaymentDay)

  if (currentDay === billingDay) {
    repaymentDate = new Date(currentYear, currentMonth, repaymentDay)
    if (repaymentDay < billingDay) {
      repaymentDate.setMonth(repaymentDate.getMonth() + 1)
    }
  }

  const diffTime = repaymentDate.getTime() - today.getTime()
  return Math.ceil(diffTime / (1000 * 60 * 60 * 24))
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
        case 'isQualified': return '130'
        case 'equity': return '200'
        case 'remark': return '200'
        case 'interestFreePeriod': return '150'
        default: return '150'
      }
    }

    const isColumnFixed = (columnValue) => {
      return ['country', 'bank', 'alias'].includes(columnValue)
    }

    const isColumnSortable = (columnValue) => {
      return ['country', 'bank', 'level', 'type', 'annualFee', 'cardNumber', 'valid', 'interestFreePeriod'].includes(columnValue)
    }

    const getSortMethod = (columnValue) => {
      switch (columnValue) {
        case 'cardNumber':
          return (a, b) => {
            const weightA = getCardTypeWeight(a.cardNumber)
            const weightB = getCardTypeWeight(b.cardNumber)
            return weightA - weightB
          }
        case 'valid':
          return (a, b) => {
            const dateA = parseValidDate(a.valid)
            const dateB = parseValidDate(b.valid)
            return dateA - dateB
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
        document.removeEventListener('click', closeMenu)
      }
      document.addEventListener('click', closeMenu)
    }

    // 处理右键菜单动作
    const handleContextMenuAction = (action) => {
      if (!selectedRow.value) return

      switch (action) {
        case 'edit':
          emit('edit', selectedRow.value)
          break
        case 'delete':
        console.log('编辑', selectedRow.value)
          emit('delete', selectedRow.value)
          break
        case 'details':
          emit('view-details', selectedRow.value)
          break
      }
      
      contextMenuVisible.value = false
    }

    const handleSetAnnualFeeQualified = () => {
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

    // 初始化时恢复排序状态
    onMounted(() => {
      if (sortState.value.key && sortState.value.order) {
        // 这里需要获取表格实例并设置排序
        // 如果使用 el-table ref，可以调用 sort 方法
      }
    })

    return {
      columns,
      isColumnVisible,
      getColumnWidth,
      isColumnFixed,
      isColumnSortable,
      getSortMethod,
      handleContextMenu,
      handleContextMenuAction,
      handleVisibilityChange,
      contextMenuVisible,
      contextMenuX,
      contextMenuY,
      selectedRow,
      sortState,
      sortMethods,
      handleSortChange,
      getDaysFromNow,
      handleSetAnnualFeeQualified,
      showAnnualFeeOption,
      rowClassName,
      calculateInterestFreePeriod
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
