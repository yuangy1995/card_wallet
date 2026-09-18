<template>
  <div class="table-container credit-card-table">
    <el-table
      :data="pageRows"
      row-key="id"
      style="width: 100%"
      border
      height="100%"
      @row-dblclick="handleRowDoubleClick"
      class="mobile-optimized"
      @row-contextmenu="handleContextMenu"
      :row-class-name="rowClassName"
      :cell-class-name="cellClassName"
      @selection-change="handleSelectionChange"
      :span-method="spanMethod"
      ref="tableRef"
      @cell-mouse-enter="handleCellMouseEnter"
      @cell-mouse-leave="handleCellMouseLeave"
    >
      <el-table-column type="selection" width="55" align="center" fixed />
      <el-table-column label="收藏" width="60" align="center">
        <template #default="{ row }">
          <el-button text circle :aria-label="favoriteIds.has(row.id) ? '取消收藏' : '收藏卡片'" :aria-pressed="favoriteIds.has(row.id)" @click.stop="$emit('toggle-favorite', row.id)">
            <el-icon><StarFilled v-if="favoriteIds.has(row.id)" /><Star v-else /></el-icon>
          </el-button>
        </template>
      </el-table-column>
      <el-table-column type="index" :index="index => (page - 1) * 50 + index + 1" label="序号" width="60" align="center" fixed />
      <template v-for="column in columns" :key="column.value">
        <el-table-column
          v-if="isColumnVisible(column.value)"
          :prop="column.value"
          :label="column.label"
          :width="getColumnWidth(column.value)"
          :min-width="getColumnMinWidth(column.value)"
          align="center"
          :fixed="isColumnFixed(column.value)"
          :sortable="false"
          :class-name="getColumnClass(column.value)"
          :sort-method="getSortMethod(column.value)"
        >
          <template v-if="column.value === 'cardNumber'" #default="scope">
            <SecureField
              :id="`card-number-${scope.row.id}`"
              :value="scope.row.cardNumber"
              :mask-start="4"
              :mask-end="12"
              type="cardNumber"
              @visibility-change="(visible) => handleVisibilityChange({ id: scope.row.id, isVisible: visible, type: 'cardNumber' })"
            />
          </template>
          <template v-else-if="column.value === 'cardCategory'" #default="{ row }">
            <span :class="['category-badge', row.cardCategory === 'debit' ? 'debit' : 'credit']">
              {{ row.cardCategory === 'debit' ? '储蓄卡' : '信用卡' }}
            </span>
          </template>
          <template v-else-if="column.value === 'bank'" #default="{ row }">
            <span class="wallet-bank-cell"><WalletBrandMark :bank="row.bank" :country="row.country" /><span>{{ row.bank }}</span></span>
          </template>
          <template v-else-if="column.value === 'cvv'" #default="scope">
            <SecureField
              v-if="scope.row.cvv"
              :id="`cvv-${scope.row.id}`"
              :value="scope.row.cvv"
              :mask-all="true"
              type="cvv"
              @visibility-change="(visible) => handleVisibilityChange({ id: scope.row.id, isVisible: visible, type: 'cvv' })"
            />
          </template>
          <template v-else-if="column.value === 'lastTime'" #default="{ row }">
            <div v-if="row.lastTime" style="display: flex; flex-direction: column; align-items: center;">
              <span>{{ formatCardTimestamp(row.lastTime) }}</span>
              <span style="color: #909399; font-size: 12px;">
                ({{ getDaysFromNow(row.lastTime).text }}{{ getDaysFromNow(row.lastTime).days }}天)
              </span>
            </div>
            <span v-else>-</span>
          </template>
          <template v-else-if="column.value === 'lastModifyTime'" #default="{ row }">
            <div v-if="row.lastModifyTime" style="display: flex; flex-direction: column; align-items: center;">
              <span>{{ formatCardTimestamp(row.lastModifyTime) }}</span>
            </div>
            <span v-else>-</span>
          </template>
          <template v-else-if="column.value === 'isQualified'" #default="{ row }">
            <el-tag v-if="row.isQualified === '1'" type="success">已达标</el-tag>
            <el-tag v-if="row.isQualified === '2'" type="danger">未达标</el-tag>
            <el-tag v-if="row.isQualified === '3'" type="info">终免年费</el-tag>
          </template>
          <template v-else-if="column.value === 'interestFreePeriod'" #default="{ row }">
            <span>{{ row.cardCategory === 'debit' ? '-' : calculateInterestFreePeriod(row.accountBillDate, row.dueDate, row.billingDaySpendingToNextBill) }}</span>
          </template>
          <template v-else-if="column.value === 'nextAnnualFeeCollectionTime'" #default="{ row }">
            <div style="display: flex; flex-direction: column; align-items: center;">
              <template v-if="row.isQualified === '3'">
                <span>- -</span>
              </template>
              <template v-else>
                <span>{{ formatCardTimestamp(row.nextAnnualFeeCollectionTime) }}</span>
                <span v-if="row.nextAnnualFeeCollectionTime" style="color: #909399; font-size: 12px;">
                  (距离收取年费{{ getDaysFromNow(row.nextAnnualFeeCollectionTime).text }}{{ getDaysFromNow(row.nextAnnualFeeCollectionTime).days }}天)
                </span>
              </template>
            </div>
          </template>
          <template v-else-if="column.value === 'valid'" #default="{ row }">
            <span>{{ formatValidDate(row.valid) }}</span>
          </template>
        </el-table-column>
      </template>
    </el-table>
    <el-pagination v-if="tableData.length > 50" v-model:current-page="page" :page-size="50" :total="tableData.length" layout="total, prev, pager, next" class="wallet-pagination" />
    <div class="table-row-hover-overlay" :style="rowHoverOverlayStyle"></div>

    <!-- 右键菜单 -->
    <div
      v-show="contextMenuVisible"
      class="context-menu"
      :style="{ left: contextMenuX + 'px', top: contextMenuY + 'px' }"
    >
      <el-menu>
        <el-menu-item index="annual-fee-qualified" v-if="showAnnualFeeOption" @click="handleSetAnnualFeeQualified">
          <el-icon><Check /></el-icon>
          <span>确认本周期年费已达标</span>
        </el-menu-item>
        <el-menu-item index="edit" @click="handleContextMenuAction('edit')">
          <el-icon><Edit /></el-icon>
          <span>编辑</span>
        </el-menu-item>
        <el-menu-item index="delete" @click="handleContextMenuAction('delete')">
          <el-icon><Delete /></el-icon>
          <span>删除</span>
        </el-menu-item>
        <el-menu-item index="details" @click="handleContextMenuAction('details')">
          <el-icon><View /></el-icon>
          <span>查看详情</span>
        </el-menu-item>
      </el-menu>
    </div>
  </div>
</template>

<script>
import SecureField from '../common/SecureField.vue'
import WalletBrandMark from '../common/WalletBrandMark.vue'
import { ElMessageBox } from 'element-plus'
import { Edit, View, Delete, Check, Star, StarFilled } from '@element-plus/icons-vue'
import { ref, computed, nextTick, onMounted, onUnmounted, watch, toRef, inject } from 'vue'
import { prepareTableRows } from '@/utils/cardMetrics'
import { mergePageSelection } from '@/utils/cardPagination'
import { usePagedCards } from '@/composables/usePagedCards'
import { cardOrganization } from '@/utils/cardBrand'
import { calculateCurrentInterestFreeDays } from '@/utils/dateCalculator'
import { daysBetween } from '../../utils/dateUtils'
import { getDaysFromNow, formatValidDate } from '../../utils/dateCalculator'
import { creditCardOptions } from '@/config/creditCardOptions'
import { cardDataCache } from '@/utils/cache'
import { formatCardTimestamp } from '@/utils/cardTimestamp'

const getCardTypeWeight = number => ['visa', 'mastercard', 'amex', 'discover', 'unionpay', 'jcb', 'diners', 'other'].indexOf(cardOrganization({ cardNumber: number }))
const parseValidDate = valid => valid ? new Date(`${valid.slice(0, 7)}-01T12:00:00`) : new Date(0)
const parseAnnualFee = fee => Number(fee) || 0
const calculateInterestFreePeriodDays = (accountBillDate, dueDate, billingDaySpendingToNextBill = true) => calculateCurrentInterestFreeDays({ accountBillDate, dueDate, billingDaySpendingToNextBill })
const calculateInterestFreePeriod = (...args) => {
  const days = calculateInterestFreePeriodDays(...args)
  return days < 0 ? '-' : days
}

export default {
  name: 'CreditCardTable',
  components: {
    Star, StarFilled,
    SecureField,
    WalletBrandMark,
    Edit,
    View,
    Delete,
    Check
  },
  props: {
    favoriteIds: { type: Set, default: () => new Set() },
    selectedRows: { type: Array, default: () => [] },
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
  emits: ['toggle-favorite', 'edit', 'delete', 'card-number-visibility', 'cvv-visibility', 'view-details', 'annual-fee-qualified', 'selection-change'],
  setup(props, { emit }) {
    const contextMenuVisible = ref(false)
    const contextMenuX = ref(0)
    const contextMenuY = ref(0)
    const selectedRow = ref(null)
    const rowHoverOverlayStyle = ref({
      display: 'none'
    })

    let cleanupClickListener = null

    const sortState = ref({
      key: localStorage.getItem('creditCardTableSortKey') || '',
      order: localStorage.getItem('creditCardTableSortOrder') || ''
    })

    const { page, rows } = usePagedCards(toRef(props, 'tableData'), 50)
    const day = inject('calendarDay', ref(Date.now()))
    const pageRows = computed(() => { day.value; return prepareTableRows(rows.value) })
    const columns = creditCardOptions.tableCustomData

    const isColumnVisible = (columnValue) => {
      return props.visibleColumns.includes(columnValue)
    }

    const getColumnWidth = (columnValue) => {
      switch (columnValue) {
        case 'country': return '100'
        case 'cardCategory': return '100'
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
        case 'cardCategory': return '80'
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
      return ['cardCategory', 'country', 'bank', 'alias'].includes(columnValue)
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
            const daysA = calculateInterestFreePeriodDays(a.accountBillDate, a.dueDate, a.billingDaySpendingToNextBill) || 0
            const daysB = calculateInterestFreePeriodDays(b.accountBillDate, b.dueDate, b.billingDaySpendingToNextBill) || 0
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
      return selectedRow.value.cardCategory !== 'debit' && selectedRow.value.isQualified !== '3'
    })

    // 处理双击行事件
    const handleRowDoubleClick = (row) => {
      emit('view-details', row)
    }

    // 表格引用和选中的行
    const tableRef = ref(null)
    let syncingSelection = false
    const handleSelectionChange = selection => {
      if (!syncingSelection) emit('selection-change', mergePageSelection(props.selectedRows, selection, pageRows.value))
    }
    const toggleSelectAll = () => {
      const selected = new Set(props.selectedRows.map(row => row.id))
      emit('selection-change', props.tableData.every(row => selected.has(row.id)) ? [] : [...props.tableData])
    }
    const clearSelection = () => emit('selection-change', [])
    watch([pageRows, () => props.selectedRows], async () => {
      syncingSelection = true
      await nextTick()
      const selected = new Set(props.selectedRows.map(row => row.id))
      tableRef.value?.clearSelection()
      pageRows.value.forEach(row => tableRef.value?.toggleRowSelection(row, selected.has(row.id)))
      await nextTick()
      syncingSelection = false
    }, { immediate: true, flush: 'sync' })

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
        cleanupClickListener?.()
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
      // 数据更新集中交给父组件，避免多个入口重复顺延年费日期。
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

    const getTableElement = () => {
      return tableRef.value?.$el || document.querySelector('.credit-card-table .el-table')
    }

    const clearTableRowHover = () => {
      const tableElement = getTableElement()
      if (!tableElement) return

      tableElement.classList.remove('is-table-row-hovered')
      tableElement.style.removeProperty('--table-row-hover-top')
      tableElement.style.removeProperty('--table-row-hover-left')
      tableElement.style.removeProperty('--table-row-hover-width')
      tableElement.style.removeProperty('--table-row-hover-height')
      rowHoverOverlayStyle.value = {
        display: 'none'
      }
    }

    const syncTableRowHover = (cell) => {
      const tableElement = getTableElement()
      const tableContainer = tableElement?.closest?.('.credit-card-table')
      const rowElement = cell?.closest?.('tr.el-table__row')
      if (!tableElement || !tableContainer || !rowElement) return

      const tableRect = tableElement.getBoundingClientRect()
      const containerRect = tableContainer.getBoundingClientRect()
      const rowRect = rowElement.getBoundingClientRect()

      tableElement.classList.add('is-table-row-hovered')
      tableElement.style.setProperty('--table-row-hover-top', `${rowRect.top - tableRect.top}px`)
      tableElement.style.setProperty('--table-row-hover-left', `${rowRect.left - tableRect.left}px`)
      tableElement.style.setProperty('--table-row-hover-width', `${rowRect.width}px`)
      tableElement.style.setProperty('--table-row-hover-height', `${rowRect.height}px`)
      rowHoverOverlayStyle.value = {
        display: 'block',
        top: `${rowRect.top - containerRect.top}px`,
        left: `${rowRect.left - containerRect.left}px`,
        width: `${rowRect.width}px`,
        height: `${rowRect.height}px`
      }
    }

    const handleCellMouseEnter = (row, column, cell) => {
      syncTableRowHover(cell)
    }

    const handleCellMouseLeave = (row, column, cell, event) => {
      const nextRow = event?.relatedTarget?.closest?.('tr.el-table__row')
      if (nextRow) return
      clearTableRowHover()
    }

    // 行样式类名
    const rowClassName = ({ row }) => {
      if (props.rowClassName) {
        return props.rowClassName({ row }) || ''
      }
      return ''
    }

    const isMergedParentCell = (row, property) => {
      const mergedCells = {
        country: row.showCountry && row.countryRowSpan > 1,
        bank: row.showBank && row.bankRowSpan > 1,
        limit: row.isSharedLimit && row.showLimit && row.limitRowSpan > 1,
        lastTime: row.isSharedLimit && row.showLastTime && row.lastTimeRowSpan > 1
      }
      return Boolean(mergedCells[property])
    }

    const cellClassName = ({ row, column }) => {
      if (isMergedParentCell(row, column.property)) {
        return 'credit-card-merged-cell'
      }
      return ''
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
        if (row.cardCategory !== 'debit' && row.isSharedLimit !== false) {
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
      // 上次提额时间合并（共享额度时也合并）
      else if (column.property === 'lastTime') {
        if (row.cardCategory !== 'debit' && row.isSharedLimit !== false) {
          if (row.showLastTime) {
            return {
              rowspan: row.lastTimeRowSpan,
              colspan: 1
            }
          } else {
            return {
              rowspan: 0,
              colspan: 0
            }
          }
        } else {
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

    onUnmounted(() => { cleanupClickListener?.(); selectedRow.value = null })

    // 初始化时恢复排序状态
    onMounted(() => {
      if (sortState.value.key && sortState.value.order) {
        // 这里需要获取表格实例并设置排序
        // 如果使用 el-table ref，可以调用 sort 方法
      }
    })

    return {
      tableData: toRef(props, 'tableData'),
      pageRows, page,
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
      rowClassName,
      handleCellMouseEnter,
      handleCellMouseLeave,
      cellClassName,
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
      formatCardTimestamp,
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
      selectedRows: toRef(props, 'selectedRows'),
      rowHoverOverlayStyle,
      handleSelectionChange,
      toggleSelectAll,
      clearSelection,
      handleContextMenuAction,
      handleSetAnnualFeeQualified,
      spanMethod
    }
  }
}
</script>

<style lang="scss" scoped>
.credit-card-table {
  width: 100%;
  min-height: 0;
  position: relative;
  display: flex;
  flex: 1;
  flex-direction: column;
}
.credit-card-table > :deep(.el-table) { flex: 1; min-height: 0; }
.credit-card-table > .wallet-pagination { flex-shrink: 0; }

.category-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 3px 10px;
  font-size: 11px;
  font-weight: 600;
  border-radius: 12px;
  border: 1px solid transparent;
  line-height: 1.2;
  transition: all 0.2s ease;

  &.credit {
    background: rgba(0, 168, 180, 0.06) !important;
    border: 1px solid rgba(0, 168, 180, 0.18) !important;
    color: #008892 !important;
  }

  &.debit {
    background: rgba(217, 119, 6, 0.08) !important;
    border: 1px solid rgba(217, 119, 6, 0.18) !important;
    color: #d97706 !important;
  }

  :global(html.dark) & {
    &.credit {
      background: rgba(0, 242, 254, 0.06) !important;
      border: 1px solid rgba(0, 242, 254, 0.15) !important;
      color: #00f2fe !important;
    }

    &.debit {
      background: rgba(245, 158, 11, 0.08) !important;
      border: 1px solid rgba(245, 158, 11, 0.2) !important;
      color: #fbbf24 !important;
    }
  }
}


:global(html.dark),
:global(body.dark) {
  --table-fixed-header-bg: linear-gradient(180deg, rgba(18, 28, 57, 0.98) 0%, rgba(11, 16, 33, 0.98) 100%);
  --table-fixed-header-color: #111b35;
  --table-fixed-body-bg: #121626;
  --table-fixed-hover-bg: #121626;
  --table-fixed-shadow: 10px 0 22px rgba(0, 0, 0, 0.45);
  --table-fixed-border-color: rgba(0, 242, 254, 0.24);
}

:global(html:not(.dark)) {
  --table-fixed-header-bg: linear-gradient(180deg, #f0f4f8 0%, #e2e8f0 100%);
  --table-fixed-header-color: #f0f4f8;
  --table-fixed-body-bg: #ffffff;
  --table-fixed-hover-bg: #ffffff;
  --table-fixed-shadow: 10px 0 18px rgba(15, 23, 42, 0.08);
  --table-fixed-border-color: rgba(0, 168, 180, 0.22);
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

  .el-table__cell {
    overflow: hidden;
  }

  .el-table__cell > .cell {
    min-width: 0;
    overflow: hidden;
  }

  /* 固定列必须是不透明背景，否则横向滚动时普通列会从下面透出来。 */
  &.el-table .el-table__header-wrapper .el-table__header tr th.el-table-fixed-column--left.el-table__cell {
    background: var(--table-fixed-header-bg) !important;
    background-color: var(--table-fixed-header-color) !important;
    background-clip: padding-box !important;
    z-index: 7 !important;
  }

  &.el-table .el-table__body-wrapper .el-table__body tr td.el-table-fixed-column--left.el-table__cell {
    background: var(--table-fixed-body-bg) !important;
    background-color: var(--table-fixed-body-bg) !important;
    background-clip: padding-box !important;
    z-index: 6 !important;
  }

  &.el-table .el-table__body-wrapper .el-table__body tr:hover > td.el-table-fixed-column--left.el-table__cell,
  &.el-table .el-table__body-wrapper .el-table__body tr.hover-row > td.el-table-fixed-column--left.el-table__cell,
  &.el-table .el-table__body-wrapper .el-table__body tr.current-row > td.el-table-fixed-column--left.el-table__cell {
    background: var(--table-fixed-hover-bg) !important;
    background-color: var(--table-fixed-hover-bg) !important;
  }

  .el-table-fixed-column--left.is-last-column {
    border-right: 1px solid var(--table-fixed-border-color) !important;

    &::before {
      box-shadow: var(--table-fixed-shadow) !important;
    }
  }

  th {
    background-color: var(--el-fill-color-light);
    font-weight: bold;
  }

  td {
    padding: 8px 0;
  }
}
</style>

<style scoped>
.wallet-bank-cell { display:inline-flex; align-items:center; gap:6px; max-width:100%; }
.wallet-bank-cell .wallet-brand-mark { width:24px; height:24px; }
.wallet-bank-cell > span:last-child { min-width:0; overflow-wrap:anywhere; }
</style>
