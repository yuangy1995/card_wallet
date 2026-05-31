<template>
  <div class="app-container">
    <div class="main_body">
      <!-- 一体式控制中心 (Unified Control Center) -->
      <div class="control-center-panel">
        <!-- 第一行：工具与操作控制栏 -->
        <div class="toolbar-row">

          <!-- 左侧区：控制中心标题、表格模式切换、展开筛选 -->
          <div class="toolbar-left">
            <span class="panel-title">
              <el-icon><Setting /></el-icon>控制中心
            </span>

            <!-- 表格模式/卡片模式选择器 -->
            <el-radio-group v-model="viewMode" size="small" class="view-mode-selector mobile-responsive">
              <el-radio-button value="table">
                <el-icon><Menu /></el-icon>表格
              </el-radio-button>
              <el-radio-button value="card">
                <el-icon><CreditCard /></el-icon>卡片
              </el-radio-button>
            </el-radio-group>

            <div class="divider-line"></div>

            <!-- 筛选开关与重置 -->
            <el-button-group class="filter-btn-group mobile-responsive">
              <el-button
                type="primary"
                :plain="isSearchCollapsed"
                size="small"
                @click="isSearchCollapsed = !isSearchCollapsed"
              >
                <el-icon><Filter v-if="isSearchCollapsed" /><ArrowUp v-else /></el-icon>
                {{ isSearchCollapsed ? '展开筛选' : '收起筛选' }}
              </el-button>
              <el-button type="danger" plain size="small" @click="resetSearchForm">
                重置
              </el-button>
            </el-button-group>

            <div class="divider-line"></div>

            <!-- 全局万能搜索框 -->
            <div class="omni-search-box mobile-responsive">
              <el-input
                v-model="quickSearchQuery"
                placeholder="任意内容检索 (别名/银行/卡号/备注...)"
                size="small"
                clearable
                class="omni-search-input"
              >
                <template #prefix>
                  <el-icon class="search-icon"><Search /></el-icon>
                </template>
              </el-input>
            </div>
          </div>

          <!-- 中间区：云同步小药丸胶囊 -->
          <div class="toolbar-center">
            <el-tooltip placement="bottom" effect="dark" :show-after="100" popper-class="sync-status-tooltip-popper">
              <template #content>
                <div class="sync-tooltip-content" style="font-size: 12px; line-height: 1.6; padding: 4px; color: #ffffff !important;">
                  <div style="font-weight: bold; margin-bottom: 6px; display: flex; align-items: center; gap: 6px; color: #ffffff !important;">
                    <span class="sync-status-dot-tooltip" :class="`is-${syncStatus.type || 'info'}`" style="display: inline-block; width: 8px; height: 8px; border-radius: 50%; background-color: currentColor;"></span>
                    <span style="color: #ffffff !important;">云同步状态：{{ syncStateText }}</span>
                  </div>
                  <div v-if="syncLastTimeText" style="margin-bottom: 2px; color: rgba(255, 255, 255, 0.95) !important;">{{ syncLastTimeText }}</div>
                  <div v-if="syncDurationText" style="margin-bottom: 2px; color: rgba(255, 255, 255, 0.95) !important;">{{ syncDurationText }}</div>
                  <div v-if="syncCountdownText" style="margin-bottom: 2px; color: rgba(255, 255, 255, 0.95) !important;">{{ syncCountdownText }}</div>
                  <div v-if="syncStatus.message" style="margin-top: 6px; border-top: 1px solid rgba(255,255,255,0.15); padding-top: 4px; color: rgba(255, 255, 255, 0.75) !important; max-width: 280px; word-break: break-all;">
                    {{ syncStatus.message }}
                  </div>
                </div>
              </template>
              <div class="sync-status-pill" :class="`is-${syncStatus.type || 'info'}`">
                <span class="sync-status-dot"></span>
                <span class="sync-state">{{ syncStateText }}</span>
              </div>
            </el-tooltip>
            <el-button
              class="sync-now-button"
              type="primary"
              plain
              size="small"
              :loading="syncStatus.isSyncing"
              @click="handleImmediateSync"
            >
              立即同步
            </el-button>
          </div>

          <!-- 右侧区：常用操作按钮组、主题与安全锁胶囊 -->
          <div class="toolbar-right">
            <el-button-group class="button-group mobile-responsive">
              <el-button type="primary" size="small" @click="addCreditCard">
                <el-icon><Plus /></el-icon>新增信用卡
              </el-button>
              <el-button type="primary" size="small" @click="showStatistics">
                <el-icon><TrendCharts /></el-icon>统计分析
              </el-button>
              <el-button type="warning" size="small" @click="manualCheckAnnualFees">
                <el-icon><Calendar /></el-icon>年费提醒
              </el-button>
            </el-button-group>

            <el-dropdown
              class="more-actions"
              trigger="click"
              popper-class="main-more-dropdown"
              @command="handleMoreAction"
            >
              <el-button size="small">
                更多<el-icon class="el-icon--right"><ArrowDown /></el-icon>
              </el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <!-- 移动端与小屏专属收纳操作项 (常态隐藏，小屏下自动显现) -->
                  <el-dropdown-item command="statistics" class="mobile-only-menu-item">
                    <el-icon><TrendCharts /></el-icon>统计分析
                  </el-dropdown-item>
                  <el-dropdown-item command="annualFeeRemind" class="mobile-only-menu-item">
                    <el-icon><Calendar /></el-icon>年费提醒
                  </el-dropdown-item>

                  <el-dropdown-item command="cloudSettings">
                    <el-icon><Connection /></el-icon>云同步设置
                  </el-dropdown-item>
                  <el-dropdown-item command="securitySettings">
                    <el-icon><Lock /></el-icon>安全设置
                  </el-dropdown-item>
                  <el-dropdown-item command="tableCustom">
                    <el-icon><Setting /></el-icon>自定义列
                  </el-dropdown-item>
                  <el-dropdown-item command="help">
                    <el-icon><QuestionFilled /></el-icon>使用帮助
                  </el-dropdown-item>
                  <el-dropdown-item command="clearData" divided class="danger-dropdown-item">
                    <el-icon><Delete /></el-icon>清除所有数据
                  </el-dropdown-item>
                  <el-dropdown-item v-if="isDev" command="generateTestData">
                    <el-icon><Star /></el-icon>生成测试数据
                  </el-dropdown-item>
                  <el-dropdown-item v-if="isDev" command="exportDesensitizedData">
                    <el-icon><CopyDocument /></el-icon>导出脱敏数据
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>

            <!-- 主题与安全锁控制集成胶囊 -->
            <div class="theme-toggle-container">
              <FloatingLockButton
                @lock-app="handleLockApp"
              />
              <el-button circle size="small" @click="toggleTheme" class="theme-toggle-btn" :title="isDarkMode ? '切换到浅色极光模式' : '切换到深色太空模式'">
                <el-icon v-if="isDarkMode"><Sunny /></el-icon>
                <el-icon v-else><Moon /></el-icon>
              </el-button>
            </div>
          </div>

        </div>

        <!-- 第二行：可折叠展示的纯无边界筛选表单 -->
        <el-collapse-transition>
          <div v-show="!isSearchCollapsed" class="filter-form-drawer">
            <SearchForm
              v-model="searchForm"
              :options="creditCardOptions"
              :is-collapse="false"
              class="search-form-clean"
            />
          </div>
        </el-collapse-transition>
      </div>

      <!-- 批量操作工具栏 -->
      <BatchOperationToolbar
        :selected-rows="selectedRows"
        :total-count="tableData.length"
        @batch-delete="handleBatchDelete"
        @batch-update-status="handleBatchUpdateStatus"
        @batch-update-annual-fee="handleBatchUpdateAnnualFee"
        @batch-update-validity="handleBatchUpdateValidity"
        @clear-selection="clearSelection"
        @toggle-select-all="toggleSelectAll"
      />

      <Transition name="view-fade" mode="out-in">
        <CreditCardTable
          v-if="viewMode === 'table'"
          :table-data="tableData"
          :visible-columns="visibleColumns"
          :selected-rows="selectedRows"
          @edit="editCreditCard"
          @delete="deleteCard"
          @card-number-visibility="handleCardNumberVisibility"
          @cvv-visibility="handleCvvVisibility"
          @view-details="viewDetails"
          @annual-fee-qualified="setAnnualFeeQualified"
          @selection-change="handleSelectionChange"
          :row-class-name="getRowClassName"
          ref="creditCardTableRef"
        />
        <CreditCardCardList
          v-else
          :table-data="tableData"
          :selected-rows="selectedRows"
          @edit="editCreditCard"
          @delete="deleteCard"
          @view-details="viewDetails"
          @annual-fee-qualified="setAnnualFeeQualified"
          @card-number-visibility="handleCardNumberVisibility"
          @cvv-visibility="handleCvvVisibility"
          @selection-change="handleSelectionChange"
          ref="creditCardCardListRef"
        />
      </Transition>

      <CreditCardDialog v-model:visible="creditCardData.dialogFormVisible" :mode="status"
        :initial-data="creditCardData.data" :existing-cards="cardData" @submit="confirmAdd" @cancel="handleDialogCancel" class="mobile-dialog mobile-form" />

      <DeleteConfirmDialog v-model:visible="deleteDialogVisible" :card-info="cardToDelete" @confirm="confirmDelete" class="mobile-dialog" />

      <!-- 表格自定义框 -->
      <TableCustomDialog v-model:visible="showTableCustomDialog" :columns="tableCustomColumns"
        @confirm="handleTableCustomConfirm" class="mobile-dialog" />
      <!-- 查看详情弹窗 -->
      <CardDetailsDialog v-model:visible="detailsVisible" :card-info="currentCard" class="mobile-dialog" />
      <!-- 统计分析弹窗 -->
      <el-dialog v-model="statisticsVisible" top="5vh" title="信用卡统计分析" width="80%" :destroy-on-close="true" class="mobile-dialog">
        <el-scrollbar height="80vh">
          <Statistics v-if="statisticsVisible" :card-data="cardData" />
        </el-scrollbar>

      </el-dialog>
      <HelpPage ref="helpPage" />
      <WebDAVConfigDialog ref="webDAVConfig" @saved="handleWebDAVConfigSaved" />

      <!-- 批量年费更新弹窗 -->
      <el-dialog
        v-model="batchAnnualFeeDialogVisible"
        title="批量更新年费"
        width="520px"
        draggable
        class="mobile-dialog batch-update-dialog"
      >
        <div class="batch-update-form">
          <el-alert
            :title="`将更新已选中的 ${batchAnnualFeeTargetCount} 张信用卡`"
            type="info"
            :closable="false"
            show-icon
          />

          <el-form label-width="130px">
            <el-form-item label="年费金额">
              <div class="batch-field-row">
                <el-checkbox v-model="batchAnnualFeeForm.updateAnnualFee">更新</el-checkbox>
                <el-input-number
                  v-model="batchAnnualFeeForm.annualFee"
                  :min="0"
                  :precision="2"
                  :step="100"
                  :disabled="!batchAnnualFeeForm.updateAnnualFee"
                  controls-position="right"
                  class="batch-input-number"
                />
              </div>
            </el-form-item>

            <el-form-item label="年费状态">
              <div class="batch-field-column">
                <el-checkbox v-model="batchAnnualFeeForm.updateStatus">更新</el-checkbox>
                <el-radio-group
                  v-model="batchAnnualFeeForm.isQualified"
                  :disabled="!batchAnnualFeeForm.updateStatus"
                >
                  <el-radio :value="'2'">未达标</el-radio>
                  <el-radio :value="'1'">已达标</el-radio>
                  <el-radio :value="'3'">终免年费</el-radio>
                </el-radio-group>
              </div>
            </el-form-item>

            <el-form-item label="下次年费时间">
              <div class="batch-field-row">
                <el-checkbox
                  v-model="batchAnnualFeeForm.updateNextAnnualFee"
                  :disabled="batchAnnualFeeForm.updateStatus && batchAnnualFeeForm.isQualified === '3'"
                >
                  更新
                </el-checkbox>
                <el-date-picker
                  v-model="batchAnnualFeeForm.nextAnnualFeeCollectionTime"
                  type="date"
                  format="YYYY-MM-DD"
                  value-format="YYYY-MM-DD"
                  placeholder="选择下次年费收取时间"
                  :disabled="!batchAnnualFeeForm.updateNextAnnualFee || (batchAnnualFeeForm.updateStatus && batchAnnualFeeForm.isQualified === '3')"
                  :disabled-date="disablePastDates"
                  style="width: 100%"
                />
              </div>
            </el-form-item>
          </el-form>

          <el-alert
            v-if="batchAnnualFeeForm.updateStatus && batchAnnualFeeForm.isQualified === '3'"
            title="选择终免年费时，将清空所选卡片的下次年费收取时间。"
            type="warning"
            :closable="false"
            show-icon
          />
        </div>
        <template #footer>
          <span class="dialog-footer">
            <el-button @click="batchAnnualFeeDialogVisible = false">取消</el-button>
            <el-button type="primary" @click="confirmBatchAnnualFeeUpdate">确定更新</el-button>
          </span>
        </template>
      </el-dialog>

      <!-- 批量有效期更新弹窗 -->
      <el-dialog
        v-model="batchValidityDialogVisible"
        title="批量更新有效期"
        width="420px"
        draggable
        class="mobile-dialog batch-update-dialog"
      >
        <div class="batch-update-form">
          <el-alert
            :title="`将更新已选中的 ${batchValidityTargetCount} 张信用卡`"
            type="info"
            :closable="false"
            show-icon
          />
          <el-form label-width="90px">
            <el-form-item label="有效期">
              <el-date-picker
                v-model="batchValidityForm.valid"
                type="month"
                format="MM/YY"
                value-format="MM/YY"
                placeholder="选择新的有效期"
                :disabled-date="disablePastMonths"
                style="width: 100%"
              />
            </el-form-item>
          </el-form>
        </div>
        <template #footer>
          <span class="dialog-footer">
            <el-button @click="batchValidityDialogVisible = false">取消</el-button>
            <el-button type="primary" @click="confirmBatchValidityUpdate">确定更新</el-button>
          </span>
        </template>
      </el-dialog>

      <!-- 全局加载覆盖层 -->
      <LoadingOverlay
        :visible="loadingState.visible"
        :text="loadingState.text"
        :progress="loadingState.progress"
        full-screen
      />
    </div>
        <!-- 安全功能组件 -->
        <PasswordSetup
      v-model="showPasswordSetup"
      @password-set="handlePasswordSet"
    />

    <PasswordVerify
      v-model="showPasswordVerify"
      @verified="handlePasswordVerified"
      @forgot-password="showForgotPasswordDialog = true"
    />

    <ForgotPassword
      v-model="showForgotPasswordDialog"
      @option-selected="handleForgotPasswordOption"
    />

    <PasswordRecovery
      v-model="showPasswordRecovery"
      @recovery-success="handleRecoverySuccess"
    />

  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, defineAsyncComponent, watch, onUnmounted, provide } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Delete,
  Setting,
  Plus,
  TrendCharts,
  Calendar,
  Star,
  QuestionFilled,
  Connection,
  CopyDocument,
  Menu,
  CreditCard,
  Sunny,
  Moon,
  ArrowDown,
  ArrowUp,
  Filter,
  Lock,
  Search
} from '@element-plus/icons-vue'
import CreditCardTable from '@/components/table/CreditCardTable.vue'
import BatchOperationToolbar from '@/components/toolbar/BatchOperationToolbar.vue'
// 懒加载组件
const CreditCardCardList = defineAsyncComponent(() => import('@/components/card/CreditCardCardList.vue'))
const CreditCardDialog = defineAsyncComponent(() => import('@/components/dialog/CreditCardDialog.vue'))
const DeleteConfirmDialog = defineAsyncComponent(() => import('@/components/dialog/DeleteConfirmDialog.vue'))
const TableCustomDialog = defineAsyncComponent(() => import('@/components/dialog/TableCustomDialog.vue'))
const CardDetailsDialog = defineAsyncComponent(() => import('@/components/dialog/CardDetailsDialog.vue'))
const Statistics = defineAsyncComponent(() => import('@/components/Statistics.vue'))
const HelpPage = defineAsyncComponent(() => import('@/components/help/HelpPage.vue'))
const WebDAVConfigDialog = defineAsyncComponent(() => import('@/components/dialog/WebDAVConfigDialog.vue'))

// 安全功能组件导入
import PasswordSetup from '@/components/security/PasswordSetup.vue'
import PasswordVerify from '@/components/security/PasswordVerify.vue'
import ForgotPassword from '@/components/security/ForgotPassword.vue'
import PasswordRecovery from '@/components/security/PasswordRecovery.vue'
import FloatingLockButton from '@/components/security/FloatingLockButton.vue'

import { creditCardOptions } from '@/config/creditCardOptions'
import SearchForm from '@/components/search/SearchForm.vue'
import { generateMockData } from '@/utils/mockData'
import { formatDate, daysBetween } from '@/utils/dateUtils'
import { getCurrentTimestamp } from '@/utils/dateFormatter'
import { BACKUP_CONSTANTS, STORAGE_KEYS } from '@/config/constants'
import { saveCardData, saveTableColumns, getTableColumns, CardDataStorage } from '@/utils/storage'
import { useDebouncedRef } from '@/composables/useDebounce'
import { useKeyboardShortcuts } from '@/composables/useKeyboardShortcuts'
import { useTheme } from '@/composables/useTheme'
import { useAutoLock } from '@/composables/useAutoLock'
import { PasswordManager } from '@/utils/passwordManager'
import { getBankDisplayName } from '@/utils/bankNameFormatter'
import { normalizeCountryValue, normalizeBankValue } from '@/utils/referenceDataUtils'
import { webdavSyncService } from '@/utils/webdavSyncService'
import { formatCardTimestamp, normalizeCardTimeFields, timestampFromDateInput } from '@/utils/cardTimestamp'

// 主题控制
const { isDarkMode, toggleTheme } = useTheme()

// 状态管理
const cardData = ref([])
const syncStatus = ref({
  message: '正在准备云同步...',
  type: 'info',
  pending: false,
  isSyncing: false,
  nextSyncAt: null,
  lastSuccessfulSyncAt: null,
  lastFailedSyncAt: null,
  syncStartedAt: null,
  elapsedMs: 0,
  lastDurationMs: null,
  intervalMs: 5 * 60 * 1000
})
const syncCountdownNow = ref(Date.now())
let syncCountdownTimer = null
const selectedRows = ref([])
const creditCardTableRef = ref(null)
const creditCardCardListRef = ref(null)

const viewMode = ref(localStorage.getItem('creditCardViewMode') || 'table')
watch(viewMode, (newValue) => {
  localStorage.setItem('creditCardViewMode', newValue)
  // 视图切换时，自动清除所有批量勾选状态，防范多视图数据和渲染不同步的 Bug
  clearSelection()
})

const formatDuration = (milliseconds) => {
  const totalSeconds = Math.max(0, Math.ceil(milliseconds / 1000))
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60

  if (hours > 0) {
    return `${hours}小时${String(minutes).padStart(2, '0')}分`
  }
  if (minutes > 0) {
    return `${minutes}分${String(seconds).padStart(2, '0')}秒`
  }
  return `${seconds}秒`
}

const syncElapsedMs = computed(() => {
  if (syncStatus.value.isSyncing) {
    if (syncStatus.value.syncStartedAt) {
      return Math.max(0, syncCountdownNow.value - syncStatus.value.syncStartedAt)
    }
    return syncStatus.value.elapsedMs || 0
  }
  return 0
})

const syncStateText = computed(() => {
  if (syncStatus.value.isSyncing) return `正在同步 ${formatDuration(syncElapsedMs.value)}`
  if (syncStatus.value.type === 'success') return '更新成功'
  if (syncStatus.value.lastFailedSyncAt && ['warning', 'danger'].includes(syncStatus.value.type)) return '更新失败'
  if ((syncStatus.value.message || '').includes('设置')) return '未设置云同步'
  if (['warning', 'danger'].includes(syncStatus.value.type)) return '需要处理'
  if (syncStatus.value.pending) return '等待同步'
  return '云同步待命'
})

const syncLastTimeText = computed(() => {
  const isFailureState = syncStatus.value.lastFailedSyncAt && ['warning', 'danger'].includes(syncStatus.value.type)
  const time = isFailureState
    ? syncStatus.value.lastFailedSyncAt
    : (syncStatus.value.lastSuccessfulSyncAt || syncStatus.value.lastFailedSyncAt)
  if (!time) return '尚未同步'
  const label = isFailureState || !syncStatus.value.lastSuccessfulSyncAt ? '最近失败' : '最近更新'
  return `${label}：${formatCardTimestamp(time)}`
})

const syncCountdownText = computed(() => {
  if (syncStatus.value.isSyncing) return ''
  if (!syncStatus.value.nextSyncAt) return ''
  const remaining = syncStatus.value.nextSyncAt - syncCountdownNow.value
  return `下次自动同步：${formatDuration(remaining)}后`
})

const syncDurationText = computed(() => {
  if (syncStatus.value.isSyncing) {
    return `已用时：${formatDuration(syncElapsedMs.value)}`
  }
  if (syncStatus.value.lastDurationMs) {
    return `上次耗时：${formatDuration(syncStatus.value.lastDurationMs)}`
  }
  return ''
})

const showTableCustomDialog = ref(false)
const tableCustomColumns = ref(JSON.parse(JSON.stringify(creditCardOptions.tableCustomData)))
const deleteDialogVisible = ref(false)
const cardToDelete = ref({
  cardName: '',
  bankName: '',
  country: '',
  level: '',
  limit: '',
  id: ''
})
const detailsVisible = ref(false)
const currentCard = ref({
  country: '',
  bank: '',
  alias: '',
  level: '',
  type: '',
  limit: '',
  cardNumber: '',
  valid: '',
  cvv: '',
  accountBillDate: '',
  dueDate: '',
  annualFee: '',
  isQualified: '',
  nextAnnualFeeCollectionTime: '',
  lastTime: '',
  lastModifyTime: '',
  equity: '',
  remark: ''
})
const statisticsVisible = ref(false)
const creditCardData = ref({
  dialogFormVisible: false,
  data: {},
  options: creditCardOptions,
})
const searchForm = ref({
  type: '',  // 币种字段
  bank: '',
  cardNumber: '',
  level: '',
  limit: '',
  isQualified: '',
  equity: '',
  remark: '',
  country: ''  // 保留country字段
})
const status = ref('add')
const labelWidth = ref('120px')

const batchAnnualFeeDialogVisible = ref(false)
const batchAnnualFeeTargetIds = ref([])
const batchAnnualFeeForm = ref({
  updateAnnualFee: true,
  annualFee: 0,
  updateStatus: false,
  isQualified: '2',
  updateNextAnnualFee: false,
  nextAnnualFeeCollectionTime: ''
})

const batchValidityDialogVisible = ref(false)
const batchValidityTargetIds = ref([])
const batchValidityForm = ref({
  valid: ''
})

const batchAnnualFeeTargetCount = computed(() => batchAnnualFeeTargetIds.value.length)
const batchValidityTargetCount = computed(() => batchValidityTargetIds.value.length)

const disablePastDates = (time) => {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return time.getTime() < today.getTime()
}

const disablePastMonths = (time) => {
  const today = new Date()
  const firstDayOfCurrentMonth = new Date(today.getFullYear(), today.getMonth(), 1)
  return time.getTime() < firstDayOfCurrentMonth.getTime()
}

const resetBatchAnnualFeeForm = () => {
  batchAnnualFeeForm.value = {
    updateAnnualFee: true,
    annualFee: 0,
    updateStatus: false,
    isQualified: '2',
    updateNextAnnualFee: false,
    nextAnnualFeeCollectionTime: ''
  }
}

const resetBatchValidityForm = () => {
  batchValidityForm.value = {
    valid: ''
  }
}

const isSearchCollapsed = ref(true)

// 万能检索与高级筛选状态
const quickSearchQuery = ref('')
const debouncedQuickSearchQuery = useDebouncedRef(quickSearchQuery, 300)

const resetSearchForm = (showToast = true) => {
  searchForm.value = {
    type: '',
    bank: '',
    cardNumber: '',
    level: '',
    limit: '',
    isQualified: '',
    equity: '',
    remark: '',
    country: '',
    alias: ''
  }
  if (showToast) {
    ElMessage.success('筛选条件已重置')
  }
}

// 判断高级筛选是否包含任何非空过滤条件
const hasAdvancedSearchConditions = computed(() => {
  const form = searchForm.value
  return !!(
    form.type ||
    form.bank ||
    form.cardNumber ||
    form.level ||
    form.limit ||
    form.isQualified ||
    form.equity ||
    form.remark ||
    form.country ||
    form.alias
  )
})

// 监听高级搜索条件：只要高级搜索中有输入，就自动清空万能搜索框
watch(
  searchForm,
  () => {
    if (hasAdvancedSearchConditions.value && quickSearchQuery.value !== '') {
      quickSearchQuery.value = ''
    }
  },
  { deep: true }
)

// 监听展开高级搜索：一旦用户点开折叠的高级搜索面板，默认清空万能搜索框
watch(isSearchCollapsed, (isCollapsed) => {
  if (!isCollapsed) {
    quickSearchQuery.value = ''
  }
})

// 监听万能搜索输入：一旦有内容，就默认清空高级搜索的各项条件（不弹提示，保留当前面板折叠状态）
watch(quickSearchQuery, (newVal) => {
  if (newVal && newVal.trim() !== '') {
    resetSearchForm(false)
  }
})

// 加载状态管理
const loadingState = ref({
  visible: false,
  text: '加载中...',
  progress: null
})

// 开发环境标识
const isDev = import.meta.env.DEV || import.meta.env.MODE === 'development'

// 组件引用
const helpPage = ref(null)
const webDAVConfig = ref(null)

// 计算属性 - 优化缓存
const visibleColumns = computed(() => {
  return tableCustomColumns.value
    .filter(item => item.checked)
    .map(item => item.value)
})

// 防抖搜索优化
const debouncedSearchForm = useDebouncedRef(searchForm, 300)

const tableData = computed(() => {
  const query = debouncedQuickSearchQuery.value ? debouncedQuickSearchQuery.value.trim().toLowerCase() : ''

  let filtered = []
  if (query) {
    // 存在万能检索条件时：对卡片所有相关字段执行全局模糊检索
    filtered = cardData.value.filter(card => {
      const bankMatch = card.bank && card.bank.toLowerCase().includes(query)
      const aliasMatch = card.alias && card.alias.toLowerCase().includes(query)

      // 卡号去除多余的分隔符进行容错检索
      const cleanQuery = query.replace(/[\s-]/g, '')
      const cleanCardNumber = card.cardNumber ? card.cardNumber.replace(/[\s-]/g, '').toLowerCase() : ''
      const cardNumberMatch = cleanCardNumber.includes(cleanQuery)

      const levelMatch = card.level && card.level.toLowerCase().includes(query)
      const typeMatch = card.type && card.type.toLowerCase().includes(query)
      const countryMatch = card.country && card.country.toLowerCase().includes(query)
      const equityMatch = card.equity && card.equity.toLowerCase().includes(query)
      const remarkMatch = card.remark && card.remark.toLowerCase().includes(query)

      // 额度检索
      const limitMatch = card.limit && card.limit.toString().includes(query)

      return bankMatch || aliasMatch || cardNumberMatch || levelMatch || typeMatch || countryMatch || equityMatch || remarkMatch || limitMatch
    })
  } else {
    // 否则，使用高级搜索逻辑
    const form = debouncedSearchForm.value
    filtered = cardData.value.filter(card => {
      // 币种匹配
      const matchType = !form.type ||
                       (card.type && (form.type.includes(card.type) ||
                       card.type.includes(form.type)));

      // 银行匹配
      const matchBank = !form.bank ||
                       (card.bank && (form.bank.includes(card.bank) ||
                       card.bank.includes(form.bank)));

      // 卡片等级匹配
      const matchLevel = !form.level ||
                        (card.level && (form.level.includes(card.level) ||
                        card.level.includes(form.level)));

      // 年费达标状态匹配
      const matchStatus = !form.isQualified ||
                         form.isQualified.length === 0 ||
                         form.isQualified.includes(card.isQualified);

      // 别名搜索
      const matchAlias = !form.alias ||
                        (card.alias && card.alias.toLowerCase().includes(form.alias.toLowerCase()));

      // 国家匹配
      const matchCountry = !form.country ||
                          (card.country && (form.country.includes(card.country) ||
                          card.country.includes(form.country)));

      // 卡号匹配 - 去除空格和其他格式字符进行匹配
      const matchCardNumber = !form.cardNumber ||
                             (card.cardNumber &&
                              card.cardNumber.replace(/[\s-]/g, '').includes(form.cardNumber.replace(/[\s-]/g, '')));

      // 额度匹配
      const matchLimit = !form.limit ||
                        (card.limit && card.limit.toString().includes(form.limit));

      // 权益匹配
      const matchEquity = !form.equity ||
                         (card.equity && card.equity.toLowerCase().includes(form.equity.toLowerCase()));

      // 备注匹配
      const matchRemark = !form.remark ||
                         (card.remark && card.remark.toLowerCase().includes(form.remark.toLowerCase()));

      return matchType && matchBank && matchLevel && matchStatus && matchAlias &&
             matchCountry && matchCardNumber && matchLimit && matchEquity && matchRemark;
    });
  }

  // 默认排序：先按国家，再按银行
  const sorted = filtered.sort((a, b) => {
    // 首先按国家排序
    const countryCompare = (a.country || '').localeCompare(b.country || '', 'zh-CN');
    if (countryCompare !== 0) return countryCompare;

    // 然后按银行排序（去除括号部分）
    const bankA = (a.bank || '').replace(/\(.*?\)/g, "").trim();
    const bankB = (b.bank || '').replace(/\(.*?\)/g, "").trim();
    const bankCompare = bankA.localeCompare(bankB, 'zh-CN');
    if (bankCompare !== 0) return bankCompare;

    // 最后按别名排序
    return (a.alias || '').localeCompare(b.alias || '', 'zh-CN');
  });

  // 生成分组显示的数据
  const grouped = [];
  let currentCountry = null;
  let currentBank = null;
  let currentSharedLimit = null;

  // 第一遍遍历，计算每个分组的行数
  const countryGroups = new Map();
  const bankGroups = new Map();
  const sharedLimitGroups = new Map();
  const sharedLastTimeGroups = new Map();

  sorted.forEach(card => {
    const country = normalizeCountryValue(card.country || '');
    const bank = normalizeBankValue(card.bank || '');
    const countryBankKey = `${country}-${bank}`;
    const sharedLimitKey = card.isSharedLimit ? `${country}-${bank}-shared` : `${card.id}-individual`;

    // 统计国家分组
    if (!countryGroups.has(country)) {
      countryGroups.set(country, 0);
    }
    countryGroups.set(country, countryGroups.get(country) + 1);

    // 统计银行分组
    if (!bankGroups.has(countryBankKey)) {
      bankGroups.set(countryBankKey, 0);
    }
    bankGroups.set(countryBankKey, bankGroups.get(countryBankKey) + 1);

    // 统计额度分组（只有共享额度的才合并）
    if (card.isSharedLimit) {
      if (!sharedLimitGroups.has(sharedLimitKey)) {
        sharedLimitGroups.set(sharedLimitKey, 0);
      }
      sharedLimitGroups.set(sharedLimitKey, sharedLimitGroups.get(sharedLimitKey) + 1);

      if (!sharedLastTimeGroups.has(sharedLimitKey)) {
        sharedLastTimeGroups.set(sharedLimitKey, 0);
      }
      sharedLastTimeGroups.set(sharedLimitKey, sharedLastTimeGroups.get(sharedLimitKey) + 1);
    }
  });

  // 第二遍遍历，生成显示数据
  sorted.forEach((card, index) => {
    const country = normalizeCountryValue(card.country || '');
    const bank = normalizeBankValue(card.bank || '');
    const countryBankKey = `${country}-${bank}`;
    const sharedLimitKey = card.isSharedLimit ? `${country}-${bank}-shared` : `${card.id}-individual`;

    const processedCard = { ...card };

    // 处理国家列合并
    if (country !== currentCountry) {
      currentCountry = country;
      processedCard.countryRowSpan = countryGroups.get(country);
      processedCard.showCountry = true;
    } else {
      processedCard.countryRowSpan = 0;
      processedCard.showCountry = false;
    }

    // 处理银行列合并
    if (countryBankKey !== currentBank) {
      currentBank = countryBankKey;
      processedCard.bankRowSpan = bankGroups.get(countryBankKey);
      processedCard.showBank = true;
    } else {
      processedCard.bankRowSpan = 0;
      processedCard.showBank = false;
    }

    // 处理额度列合并（只有共享额度的才合并）
    if (card.isSharedLimit) {
      if (sharedLimitKey !== currentSharedLimit) {
        currentSharedLimit = sharedLimitKey;
        processedCard.limitRowSpan = sharedLimitGroups.get(sharedLimitKey);
        processedCard.showLimit = true;
        processedCard.lastTimeRowSpan = sharedLastTimeGroups.get(sharedLimitKey);
        processedCard.showLastTime = true;
      } else {
        processedCard.limitRowSpan = 0;
        processedCard.showLimit = false;
        processedCard.lastTimeRowSpan = 0;
        processedCard.showLastTime = false;
      }
    } else {
      // 独立额度不合并
      processedCard.limitRowSpan = 1;
      processedCard.showLimit = true;
      processedCard.lastTimeRowSpan = 1;
      processedCard.showLastTime = true;
      currentSharedLimit = null; // 重置共享额度状态
    }

    grouped.push(processedCard);
  });

  return grouped
})

// 显示加载状态
const showLoading = (text = '加载中...', progress = null) => {
  loadingState.value = {
    visible: true,
    text,
    progress
  }
}

// 隐藏加载状态
const hideLoading = () => {
  loadingState.value.visible = false
}

const persistSyncedMutation = async (options = {}) => {
  await webdavSyncService.commitCards(cardData.value, options)
}

const publishCurrentV4Snapshot = async (afterPublish) => {
  try {
    await webdavSyncService.synchronize(true)
  } finally {
    if (typeof afterPublish === 'function') {
      await afterPublish()
    }
  }
}

const handleImmediateSync = () => {
  publishCurrentV4Snapshot()
}

const applySyncedCards = (syncedCards) => {
  cardData.value = syncedCards.map(card => normalizeCardTimeFields(card, { fillLastModifyTime: true }))
}

const handleSyncStatusChanged = (newStatus) => {
  syncStatus.value = newStatus
}

// 初始化数据
onMounted(async () => {
  syncCountdownTimer = window.setInterval(() => {
    syncCountdownNow.value = Date.now()
  }, 1000)

  showLoading('正在初始化应用...')

  try {
    // 加载列配置
    const storedColumns = getTableColumns()
    if (storedColumns && storedColumns.length > 0) {
      tableCustomColumns.value = storedColumns
    }

    // 加载卡片数据（带迁移信息）
    showLoading('正在加载数据...')
    const result = CardDataStorage.getCardData(true)
    const migrationInfo = result.migrationInfo
    cardData.value = result.data.map(card => normalizeCardTimeFields(card, { fillLastModifyTime: true }))

    // 检查并为没有 ID 的卡片生成唯一 ID
    let hasChanges = false
    cardData.value.forEach(card => {
      if (!card.id) {
        card.id = crypto.randomUUID()
        hasChanges = true
      }
    })

    // 如果有卡片被添加了 ID，更新本地存储
    if (hasChanges) {
      saveCardData(cardData.value)
    }

    await webdavSyncService.start(cardData.value, applySyncedCards, handleSyncStatusChanged)

    // 判断应用是否处于锁定状态，锁定时跳过弹窗类检测
    const appIsLocked = PasswordManager.hasPassword() &&
      (PasswordManager.isAppLocked() || PasswordManager.shouldAutoLock())

    if (appIsLocked) {
      // 锁定状态下延迟卡片检测，等待解锁后执行
      pendingMigrationInfo.value = migrationInfo
      needsInitialChecks.value = true
    } else {
      if (cardData.value && cardData.value.length > 0) {
        // 检查年费达标状态
        showLoading('正在检查年费状态...')
        await checkAnnualFeeQualified()

        // 自动检查年费情况
        await manualCheckAnnualFees()
      }

      // 显示迁移报告（需要在所有loading完成后）
      hideLoading()
      await nextTick()
      await showMigrationReport(migrationInfo)
    }
  } finally {
    hideLoading()
  }
})

// 检查年费达标状态
const checkAnnualFeeQualified = async () => {
  const now = new Date()
  const warningCards = cardData.value.filter(card => {
    // 排除终免年费('3')、已经是未达标状态('2')、或没有年费收取时间的卡片
    if (card.isQualified === '3' || card.isQualified === '2' || !card.nextAnnualFeeCollectionTime) return false
    const dueDate = new Date(card.nextAnnualFeeCollectionTime)
    const diffDays = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24))
    return diffDays <= BACKUP_CONSTANTS.ANNUAL_FEE_CHECK_DAYS && diffDays >= 0
  })

  if (warningCards.length > 0) {
    try {
      const message = `
        <div style="display: flex; min-height: 200px; max-height: 500px;">
          <div style="flex: 1; padding: 16px; display: flex; flex-direction: column; justify-content: center;">
            <h3 style="margin: 0 0 16px 0; color: #E6A23C;">年费达标状态检测</h3>
            <p style="margin: 0 0 12px 0; line-height: 1.6;">检测到以下卡片临近年费收取时间不足${BACKUP_CONSTANTS.ANNUAL_FEE_CHECK_DAYS}天。</p>
            <p style="margin: 0 0 12px 0; line-height: 1.6;">建议将这些卡片修改为未达标状态，以协助您处理年费收取问题。</p>
            <p class="annual-fee-desc" style="margin: 0; line-height: 1.6;">
              提示：如果您在去年将卡片设为已达标，但今年忘记修改状态且消费未达标，可能会遗漏年费情况。为避免年费损失，建议点击"是"来更新状态。
            </p>
          </div>
          <div class="annual-fee-divider" style="width: 1px; margin: 16px 0;"></div>
          <div style="flex: 1; padding: 16px;">
            <h3 style="margin: 0 0 16px 0; color: #E6A23C;">待处理卡片列表</h3>
            <div style="max-height: 400px; overflow-y: auto;">
              <ul style="list-style-type: none; padding: 0; margin: 0;">
                ${warningCards.map(card => `
                  <li class="annual-fee-card-item">
                    <div class="annual-fee-card-title">
                      ${card.bank.replace(/\(.*?\)/g, "").trim()} - ${card.alias}
                    </div>
                    <div class="annual-fee-card-time">
                      下次年费收取时间：${formatCardTimestamp(card.nextAnnualFeeCollectionTime)}
                    </div>
                    <div class="annual-fee-card-countdown">
                      距离收取年费：${Math.ceil((new Date(card.nextAnnualFeeCollectionTime) - new Date()) / (1000 * 60 * 60 * 24))} 天
                    </div>
                  </li>
                `).join('')}
              </ul>
            </div>
          </div>
        </div>`

      const result = await ElMessageBox.confirm(
        message,
        '',
        {
          confirmButtonText: '是',
          cancelButtonText: '取消',
          dangerouslyUseHTMLString: true,
          customClass: 'annual-fee-check-dialog',
          center: false
        }
      )

      if (result === 'confirm') {
        // 更新卡片状态为未达标
        warningCards.forEach(card => {
          const index = cardData.value.findIndex(c => c.id === card.id)
          if (index !== -1) {
            cardData.value[index].isQualified = '2'
          }
        })
        // 保存更新后的数据
        await persistSyncedMutation()
        ElMessage.success('已将符合条件的卡片更新为未达标状态')
      }
    } catch (e) {
      // 用户点击取消，不做任何操作
    }
  }
}

// 方法
const handleTableCustomConfirm = (columns) => {
  tableCustomColumns.value = columns
  saveTableColumns(columns)
  showTableCustomDialog.value = false
  ElMessage.success('列配置已保存')
}

const openTableCustom = () => {
  showTableCustomDialog.value = true
}

const confirmDelete = async () => {
  if (!cardToDelete.value.id) return

  showLoading('正在删除信用卡...')

  try {
    // 模拟删除延时
    await new Promise(resolve => setTimeout(resolve, 300))

    const index = cardData.value.findIndex(item => item.id === cardToDelete.value.id)
    if (index > -1) {
      const cardName = cardToDelete.value.cardName
      cardData.value.splice(index, 1)
      await persistSyncedMutation({ deletedCardIds: [cardToDelete.value.id] })

      deleteDialogVisible.value = false

      // 更好的删除反馈
      ElMessage({
        message: `信用卡 "${cardName}" 已删除`,
        type: 'success',
        duration: 2000,
        showClose: true
      })
    }
  } finally {
    hideLoading()
  }
}

const addCreditCard = () => {
  status.value = 'add'
  creditCardData.value.dialogFormVisible = true
  creditCardData.value.data = {}
}

const editCreditCard = (row) => {
  status.value = 'edit'
  creditCardData.value.dialogFormVisible = true
  creditCardData.value.data = Object.assign({}, row)
}

const confirmAdd = async (data) => {
  showLoading(status.value === 'add' ? '正在添加信用卡...' : '正在保存修改...')

  try {
    // 模拟保存延时
    await new Promise(resolve => setTimeout(resolve, 500))

    creditCardData.value.dialogFormVisible = false
    // 添加最后修改时间
    data.lastModifyTime = getCurrentTimestamp()

    if (status.value === 'add') {
      cardData.value.push(data)
    } else {
      const index = cardData.value.findIndex(item => item.id === data.id)
      if (index !== -1) {
        cardData.value[index] = data
      }
    }

    // 如果是共享额度，同步更新所有同银行共享额度的卡片
    if (data.isSharedLimit && data.bank && data.country) {
      const currentBank = (data.bank || '').replace(/\(.*?\)/g, "").trim()
      cardData.value.forEach((card, idx) => {
        if (card.id !== data.id &&
            card.isSharedLimit === true &&
            card.country === data.country &&
            (card.bank || '').replace(/\(.*?\)/g, "").trim() === currentBank) {
          cardData.value[idx].limit = data.limit
          cardData.value[idx].type = data.type
          cardData.value[idx].lastTime = data.lastTime
          cardData.value[idx].lastModifyTime = getCurrentTimestamp()
        }
      })
    }

    await persistSyncedMutation()

    // 更好的成功反馈
    ElMessage({
      message: status.value === 'add' ? '信用卡添加成功！' : '信用卡信息更新成功！',
      type: 'success',
      duration: 2000,
      showClose: true
    })
  } finally {
    hideLoading()
  }
}

const deleteCard = (row) => {
  cardToDelete.value = {
    cardName: row.alias || '未命名信用卡',
    bankName: row.bank || '',
    country: row.country || '',
    level: row.level || '',
    limit: row.limit ? `${row.limit} ${row.type}` : '',
    id: row.id
  }
  deleteDialogVisible.value = true
}

const handleMoreAction = async (command) => {
  switch (command) {
    case 'cloudSettings':
      showWebDAVConfig()
      break
    case 'securitySettings':
      showPasswordSetup.value = true
      break
    case 'tableCustom':
      openTableCustom()
      break
    case 'help':
      showHelp()
      break
    case 'clearData':
      confirmClearData()
      break
    case 'generateTestData':
      await generateRandomData()
      break
    case 'exportDesensitizedData':
      exportDesensitizedData()
      break
    // 移动端/小屏专属命令路由
    case 'statistics':
      showStatistics()
      break
    case 'annualFeeRemind':
      manualCheckAnnualFees()
      break
  }
}

const viewDetails = (row) => {
  currentCard.value = { ...row }
  detailsVisible.value = true
}

const showStatistics = () => {
  statisticsVisible.value = true
}

const manualCheckAnnualFees = async () => {
  const now = new Date()
  const warningCards = []
  const overdueCards = []
  const unqualifiedCards = []

  cardData.value.forEach(card => {
    // 如果是未达标的卡片
    if (card.isQualified === '2' && card.nextAnnualFeeCollectionTime) {
      const dueDate = new Date(card.nextAnnualFeeCollectionTime)
      const diffDays = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24))
      if (diffDays > 0) {  // 只显示还未到期的未达标卡片
        unqualifiedCards.push({...card, diffDays})
      }
    }

    // 检查年费时间
    if (!card.nextAnnualFeeCollectionTime || card.isQualified === '3') return

    const dueDate = new Date(card.nextAnnualFeeCollectionTime)
    const diffDays = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24))

    if (diffDays <= BACKUP_CONSTANTS.ANNUAL_FEE_CHECK_DAYS && diffDays > 0 && card.isQualified !== '2') {
      warningCards.push(card)
    } else if (diffDays <= 0 && diffDays > -60) {
      overdueCards.push(card)
    }
  })

  if (warningCards.length > 0 || overdueCards.length > 0 || unqualifiedCards.length > 0) {
    let message = '<div class="manual-check-container" style="max-height: 400px; overflow-y: auto;">'

    if (unqualifiedCards.length > 0) {
      message += '<div style="margin-bottom: 16px;">'
      message += '<h3 class="manual-check-section-title unqualified" style="margin-bottom: 8px;">年费尚未达标</h3>'
      message += '<ul style="list-style-type: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 16px;">'
      unqualifiedCards.forEach(card => {
        message += `<li class="manual-check-card-item unqualified">
          <div class="manual-check-card-title">${card.bank.replace(/\(.*?\)/g, "").trim()} - ${card.alias}</div>
          <div class="manual-check-card-desc">距离年费收取还有 ${card.diffDays} 天</div>
        </li>`
      })
      message += '</ul></div>'
    }

    if (warningCards.length > 0) {
      message += '<div style="margin-bottom: 16px;">'
      message += '<h3 class="manual-check-section-title warning" style="margin-bottom: 8px;">即将到期年费提醒</h3>'
      message += '<ul style="list-style-type: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 16px;">'
      warningCards.forEach(card => {
        message += `<li class="manual-check-card-item warning">
          <div class="manual-check-card-title">${card.bank.replace(/\(.*?\)/g, "").trim()} - ${card.alias}</div>
          <div class="manual-check-card-desc">将在 ${Math.ceil((new Date(card.nextAnnualFeeCollectionTime) - now) / (1000 * 60 * 60 * 24))} 天后收取年费</div>
        </li>`
      })
      message += '</ul></div>'
    }

    if (overdueCards.length > 0) {
      message += '<div>'
      message += '<h3 class="manual-check-section-title overdue" style="margin-bottom: 8px;">已过期年费提醒</h3>'
      message += '<ul style="list-style-type: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 16px;">'
      overdueCards.forEach(card => {
        message += `<li class="manual-check-card-item overdue">
          <div class="manual-check-card-title">${card.bank.replace(/\(.*?\)/g, "").trim()} - ${card.alias}</div>
          <div class="manual-check-card-desc">已过期 ${Math.ceil((now - new Date(card.nextAnnualFeeCollectionTime)) / (1000 * 60 * 60 * 24))} 天</div>
        </li>`
      })
      message += '</ul></div>'
    }

    message += '</div>'

    try {
      await ElMessageBox.alert(
        message,
        '',
        {
          confirmButtonText: '知道了',
          dangerouslyUseHTMLString: true,
          customClass: 'annual-fee-dialog',
          showClose: false
        }
      )
    } catch (e) {
    }
  } else {
    ElMessage({
      type: 'success',
      message: '太好了！目前没有需要担心的年费问题',
      duration: 3000
    })
  }
}

const generateRandomData = async () => {
  const mockData = generateMockData(50)
  cardData.value = mockData
  resetSearchForm(false)
  quickSearchQuery.value = ''
  clearSelection()
  ElMessage.success('成功生成 50 条测试数据')
  await persistSyncedMutation({ replace: true })
}

// 批量操作相关函数
const handleSelectionChange = (selection) => {
  selectedRows.value = selection
}

const clearSelection = () => {
  selectedRows.value = []
  if (creditCardTableRef.value && creditCardTableRef.value.clearSelection) {
    creditCardTableRef.value.clearSelection()
  }
  if (creditCardCardListRef.value && creditCardCardListRef.value.clearSelection) {
    creditCardCardListRef.value.clearSelection()
  }
}

const toggleSelectAll = () => {
  if (viewMode.value === 'table') {
    if (creditCardTableRef.value && creditCardTableRef.value.toggleSelectAll) {
      creditCardTableRef.value.toggleSelectAll()
    }
  } else {
    if (selectedRows.value.length === tableData.value.length) {
      selectedRows.value = []
    } else {
      selectedRows.value = [...tableData.value]
    }
  }
}

const handleBatchDelete = async (rows) => {
  try {
    const idsToDelete = rows.map(row => row.id)
    cardData.value = cardData.value.filter(card => !idsToDelete.includes(card.id))
    await persistSyncedMutation({ deletedCardIds: idsToDelete })
    clearSelection()
    ElMessage.success(`成功删除 ${rows.length} 张信用卡`)
  } catch (error) {
    ElMessage.error('批量删除失败')
  }
}

const handleBatchUpdateStatus = async ({ rows, status }) => {
  try {
    const idsToUpdate = rows.map(row => row.id)
    cardData.value.forEach(card => {
      if (idsToUpdate.includes(card.id)) {
        card.isQualified = status
        card.lastModifyTime = getCurrentTimestamp()
      }
    })
    await persistSyncedMutation()
    clearSelection()
    const statusText = status === '1' ? '达标' : '未达标'
    ElMessage.success(`成功将 ${rows.length} 张信用卡标记为${statusText}`)
  } catch (error) {
    ElMessage.error('批量更新状态失败')
  }
}

const handleBatchUpdateAnnualFee = (rows) => {
  if (!rows || rows.length === 0) {
    ElMessage.warning('请先选择要更新的信用卡')
    return
  }
  batchAnnualFeeTargetIds.value = rows.map(row => row.id).filter(Boolean)
  resetBatchAnnualFeeForm()
  batchAnnualFeeDialogVisible.value = true
}

const handleBatchUpdateValidity = (rows) => {
  if (!rows || rows.length === 0) {
    ElMessage.warning('请先选择要更新的信用卡')
    return
  }
  batchValidityTargetIds.value = rows.map(row => row.id).filter(Boolean)
  resetBatchValidityForm()
  batchValidityDialogVisible.value = true
}

const confirmBatchAnnualFeeUpdate = async () => {
  const form = batchAnnualFeeForm.value
  const shouldUpdateNextAnnualFee = form.updateNextAnnualFee && !(form.updateStatus && form.isQualified === '3')
  const hasAnyUpdate = form.updateAnnualFee || form.updateStatus || shouldUpdateNextAnnualFee

  if (!hasAnyUpdate) {
    ElMessage.warning('请至少选择一项年费信息')
    return
  }

  if (form.updateAnnualFee) {
    const fee = Number(form.annualFee)
    if (!Number.isFinite(fee) || fee < 0) {
      ElMessage.warning('请输入有效的年费金额')
      return
    }
  }

  if (shouldUpdateNextAnnualFee && !form.nextAnnualFeeCollectionTime) {
    ElMessage.warning('请选择下次年费收取时间')
    return
  }

  const targetIds = new Set(batchAnnualFeeTargetIds.value)
  if (targetIds.size === 0) {
    ElMessage.warning('没有可更新的信用卡')
    batchAnnualFeeDialogVisible.value = false
    return
  }

  try {
    let updatedCount = 0
    const nextAnnualFeeTimestamp = shouldUpdateNextAnnualFee
      ? timestampFromDateInput(form.nextAnnualFeeCollectionTime)
      : null

    cardData.value.forEach(card => {
      if (!targetIds.has(card.id)) return

      if (form.updateAnnualFee) {
        card.annualFee = Number(form.annualFee)
      }
      if (form.updateStatus) {
        card.isQualified = form.isQualified
        if (form.isQualified === '3') {
          card.nextAnnualFeeCollectionTime = null
        }
      }
      if (shouldUpdateNextAnnualFee) {
        card.nextAnnualFeeCollectionTime = nextAnnualFeeTimestamp
      }
      card.lastModifyTime = getCurrentTimestamp()
      updatedCount += 1
    })

    if (updatedCount === 0) {
      ElMessage.warning('没有匹配到可更新的信用卡')
      batchAnnualFeeDialogVisible.value = false
      return
    }

    await persistSyncedMutation()
    batchAnnualFeeDialogVisible.value = false
    batchAnnualFeeTargetIds.value = []
    clearSelection()
    ElMessage.success(`已批量更新 ${updatedCount} 张信用卡的年费信息`)
  } catch (error) {
    ElMessage.error('批量更新年费失败：' + error.message)
  }
}

const confirmBatchValidityUpdate = async () => {
  const valid = batchValidityForm.value.valid
  if (!valid) {
    ElMessage.warning('请选择新的有效期')
    return
  }

  const targetIds = new Set(batchValidityTargetIds.value)
  if (targetIds.size === 0) {
    ElMessage.warning('没有可更新的信用卡')
    batchValidityDialogVisible.value = false
    return
  }

  try {
    let updatedCount = 0
    cardData.value.forEach(card => {
      if (!targetIds.has(card.id)) return
      card.valid = valid
      card.lastModifyTime = getCurrentTimestamp()
      updatedCount += 1
    })

    if (updatedCount === 0) {
      ElMessage.warning('没有匹配到可更新的信用卡')
      batchValidityDialogVisible.value = false
      return
    }

    await persistSyncedMutation()
    batchValidityDialogVisible.value = false
    batchValidityTargetIds.value = []
    clearSelection()
    ElMessage.success(`已批量更新 ${updatedCount} 张信用卡的有效期`)
  } catch (error) {
    ElMessage.error('批量更新有效期失败：' + error.message)
  }
}

const confirmClearData = async () => {
  try {
    await ElMessageBox.confirm(
      '此操作将清除所有信用卡数据，是否继续？',
      '警告',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning',
      }
    )
    const deletedCardIds = cardData.value.map(card => card.id)
    cardData.value = []
    await persistSyncedMutation({ deletedCardIds, replace: true })
    ElMessage.success('所有数据已清除')
  } catch {
  }
}

const handleCardNumberVisibility = ({ id, isVisible }) => {
  cardData.value.find(card => card.id === id).showCardNumber = isVisible
}

const handleCvvVisibility = ({ id, isVisible }) => {
  cardData.value.find(card => card.id === id).showCVV = isVisible
}

const setAnnualFeeQualified = async (cardId) => {
  const card = cardData.value.find(c => c.id === cardId)
  if (card) {
    card.isQualified = '1'

    // 若有下次年费收取时间，则顺延一年
    if (card.nextAnnualFeeCollectionTime) {
      const nextDate = new Date(card.nextAnnualFeeCollectionTime)
      if (!isNaN(nextDate.getTime())) {
        nextDate.setFullYear(nextDate.getFullYear() + 1)
        card.nextAnnualFeeCollectionTime = nextDate.getTime()
      }
    }

    // 添加最后修改时间并保存
    card.lastModifyTime = getCurrentTimestamp()
    await persistSyncedMutation()
  }
}

const getRowClassName = ({ row }) => {
  // 如果未达标，显示警告样式（橙色）
  if (row.isQualified === '2') {
    return 'warning-row'
  }

  // 如果有下次年费收取时间且不是终免年费
  if (row.nextAnnualFeeCollectionTime && row.isQualified !== '3') {
    const now = new Date()
    const dueDate = new Date(row.nextAnnualFeeCollectionTime)
    const diffDays = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24))

    // 如果已超过年费收取期限，显示危险样式（红色）
    if (diffDays <= 0) {
      return 'danger-row'
    }
    // 如果即将收取年费，显示提醒样式（黄色）
    else if (diffDays <= 60) {
      return 'reminder-row'
    }
  }

  return ''
}

const handleDialogCancel = () => {
  creditCardData.value.dialogFormVisible = false
  creditCardData.value.data = {}
}

const showHelp = () => {
  helpPage.value?.showHelp()
}

const showWebDAVConfig = () => {
  webDAVConfig.value?.showDialog()
}

const handleWebDAVConfigSaved = async () => {
  try {
    await webdavSyncService.start(cardData.value, applySyncedCards, handleSyncStatusChanged)
  } catch (error) {
    syncStatus.value = {
      ...syncStatus.value,
      message: `云同步设置已保存，但启动同步失败：${error.message}`,
      type: 'warning',
      pending: true,
      isSyncing: false
    }
  }
}

// 显示数据迁移报告
const showMigrationReport = async (migrationInfo) => {
  if (!migrationInfo) return

  // 判断是否为测试环境（通过 hostname 或环境变量）
  const isTestEnv = window.location.hostname === 'localhost' ||
                     window.location.hostname === '127.0.0.1' ||
                     import.meta.env.DEV

  // 如果没有迁移，只在测试环境下提示
  if (!migrationInfo.migrated) {
    if (isTestEnv) {
      ElMessage({
        type: 'success',
        message: '✅ 数据已经是最新状态，无需处理',
        duration: 3000,
        showClose: true
      })
    }
    return
  }

  // 有迁移，显示详细弹窗
  const summary = migrationInfo.summary
  const details = migrationInfo.details || []
  const hasErrors = (summary?.errors || 0) > 0

  // 成功迁移属于后台兼容升级，不用打断用户；只有失败时才需要弹窗处理。
  if (!hasErrors) {
    if (isTestEnv) {
      ElMessage({
        type: 'success',
        message: `数据已自动整理完成，共处理 ${summary?.success || 0} 张卡片`,
        duration: 3000,
        showClose: true
      })
    }
    return
  }

  // 构建详细的HTML内容
  let htmlContent = '<div style="max-height: 70vh; overflow-y: auto;">'

  // 概览部分
  htmlContent += '<div style="margin-bottom: 20px; padding: 15px; background: #f0f9ff; border-radius: 8px; border-left: 4px solid #3b82f6;">'
  htmlContent += '<h3 style="margin: 0 0 10px 0; color: #1e40af;">📊 整理结果</h3>'
  htmlContent += `<p style="margin: 5px 0;"><strong>总卡片数:</strong> ${summary.total}</p>`
  htmlContent += `<p style="margin: 5px 0;"><strong>需要整理:</strong> ${summary.migrated}</p>`
  htmlContent += `<p style="margin: 5px 0;"><strong>已整理:</strong> <span style="color: #16a34a;">${summary.success}</span></p>`

  if (summary.errors > 0) {
    htmlContent += `<p style="margin: 5px 0;"><strong>失败数量:</strong> <span style="color: #dc2626;">${summary.errors}</span></p>`
  }
  htmlContent += '</div>'

  // 失败的卡片
  if (summary.errors > 0 && summary.errorDetails && summary.errorDetails.length > 0) {
    htmlContent += '<div style="margin-bottom: 20px;">'
    htmlContent += '<h3 style="color: #dc2626; margin-bottom: 10px;">❌ 未能整理的卡片</h3>'

    summary.errorDetails.forEach((error, index) => {
      htmlContent += '<div style="margin-bottom: 10px; padding: 12px; background: #fef2f2; border-radius: 6px; border-left: 4px solid #dc2626;">'
      htmlContent += `<p style="margin: 0 0 5px 0; font-weight: bold;">卡片 #${index + 1}</p>`
      htmlContent += `<p style="margin: 0; color: #666;">第 ${error.index + 1} 条卡片记录</p>`
      if (error.cardId) {
        htmlContent += `<p style="margin: 5px 0 0 0; color: #666;">卡片编号: ${error.cardId}</p>`
      }
      htmlContent += `<p style="margin: 5px 0 0 0; color: #dc2626;">原因: ${error.message}</p>`
      htmlContent += '</div>'
    })
    htmlContent += '</div>'
  }

  // 成功迁移的卡片详情（仅测试环境显示）
  if (isTestEnv && details.length > 0) {
    htmlContent += '<div style="margin-bottom: 20px;">'
    htmlContent += '<h3 style="color: #16a34a; margin-bottom: 10px;">✅ 已整理的卡片详情</h3>'
    htmlContent += '<p style="color: #666; font-size: 12px; margin-bottom: 10px;">以下列出本次整理的详细信息</p>'

    details.forEach((detail, idx) => {
      const cardInfo = detail.cardInfo
      const changes = detail.changes

      htmlContent += '<div style="margin-bottom: 15px; padding: 12px; background: #f0fdf4; border-radius: 6px; border-left: 4px solid #16a34a;">'
      htmlContent += `<h4 style="margin: 0 0 10px 0; color: #15803d;">卡片 #${idx + 1}</h4>`

      // 卡片基本信息
      htmlContent += '<div style="margin-bottom: 10px; padding: 8px; background: white; border-radius: 4px;">'
      if (cardInfo.bank) {
        htmlContent += `<p style="margin: 3px 0; font-size: 13px;"><strong>银行:</strong> ${getBankDisplayName(cardInfo.bank)}</p>`
      }
      if (cardInfo.alias) {
        htmlContent += `<p style="margin: 3px 0; font-size: 13px;"><strong>别名:</strong> ${cardInfo.alias}</p>`
      }
      if (cardInfo.cardNumber) {
        const masked = cardInfo.cardNumber.slice(0, 4) + ' **** **** ' + cardInfo.cardNumber.slice(-4)
        htmlContent += `<p style="margin: 3px 0; font-size: 13px;"><strong>卡号:</strong> ${masked}</p>`
      }
      htmlContent += '</div>'

      // 字段变更详情
      htmlContent += '<div style="margin-top: 10px;">'
      htmlContent += `<p style="margin: 0 0 8px 0; font-weight: bold; color: #15803d;">更新内容 (${changes.length}项):</p>`

      changes.forEach((change, changeIdx) => {
        htmlContent += '<div style="margin-bottom: 8px; padding: 8px; background: #fefce8; border-radius: 4px; font-size: 12px;">'
        htmlContent += `<p style="margin: 0 0 4px 0;"><strong>信息项:</strong> <code style="background: #fef9c3; padding: 2px 6px; border-radius: 3px;">${change.field}</code></p>`

        // 显示旧值
        if (change.oldValue === undefined) {
          htmlContent += '<p style="margin: 4px 0; color: #666;">原内容: <span style="color: #999; font-style: italic;">空</span></p>'
        } else {
          htmlContent += `<p style="margin: 4px 0; color: #666;">原内容: <code>${JSON.stringify(change.oldValue)}</code></p>`
        }

        // 显示新值
        if (change.newValue === undefined) {
          htmlContent += '<p style="margin: 4px 0; color: #666;">新内容: <span style="color: #999; font-style: italic;">已删除</span></p>'
        } else {
          htmlContent += `<p style="margin: 4px 0; color: #16a34a;">新内容: <code>${JSON.stringify(change.newValue)}</code></p>`
        }

        htmlContent += `<p style="margin: 4px 0 0 0; color: #854d0e; font-style: italic;">原因: ${change.reason}</p>`
        htmlContent += '</div>'
      })
      htmlContent += '</div>'
      htmlContent += '</div>'
    })
    htmlContent += '</div>'
  } else if (details.length > 0) {
    // 生产环境只显示简要信息
    htmlContent += '<div style="margin-bottom: 20px;">'
    htmlContent += '<h3 style="color: #16a34a; margin-bottom: 10px;">✅ 已整理的卡片</h3>'

    details.forEach((detail, idx) => {
      const cardInfo = detail.cardInfo
      const changes = detail.changes

      htmlContent += '<div style="margin-bottom: 10px; padding: 10px; background: #f0fdf4; border-radius: 6px;">'
      htmlContent += `<p style="margin: 0; font-weight: bold;">卡片 #${idx + 1}</p>`
      if (cardInfo.bank) {
        htmlContent += `<p style="margin: 5px 0 0 0; font-size: 13px; color: #666;">${getBankDisplayName(cardInfo.bank)}`
        if (cardInfo.alias) htmlContent += ` - ${cardInfo.alias}`
        htmlContent += '</p>'
      }
      htmlContent += `<p style="margin: 5px 0 0 0; font-size: 13px; color: #16a34a;">${changes.length} 项内容已更新</p>`
      htmlContent += '</div>'
    })
    htmlContent += '</div>'
  }

  htmlContent += '</div>'

  // 显示弹窗
  try {
    await ElMessageBox.alert(
      htmlContent,
      '数据已整理完成',
      {
        confirmButtonText: '我知道了',
        dangerouslyUseHTMLString: true,
        customClass: 'migration-report-dialog',
        showClose: true,
        closeOnClickModal: false,
        closeOnPressEscape: false,
        distinguishCancelAndClose: true
      }
    )
  } catch (error) {
    // 用户关闭弹窗，无需额外处理
  }
}

// 键盘快捷键配置
const shortcuts = {
  'ctrl+n': addCreditCard,
  'ctrl+shift+n': generateRandomData,
  'ctrl+h': showHelp,
  'ctrl+t': () => showTableCustomDialog.value = true,
  'ctrl+s': showStatistics,
  'ctrl+shift+c': confirmClearData,
  'ctrl+shift+w': showWebDAVConfig,
  'f1': showHelp,
  'escape': () => {
    // 关闭所有弹窗
    creditCardData.value.dialogFormVisible = false
    deleteDialogVisible.value = false
    showTableCustomDialog.value = false
    detailsVisible.value = false
    statisticsVisible.value = false
  }
}

// 初始化快捷键
useKeyboardShortcuts(shortcuts)

watch(
  () => [batchAnnualFeeForm.value.updateStatus, batchAnnualFeeForm.value.isQualified],
  ([updateStatus, isQualified]) => {
    if (updateStatus && isQualified === '3') {
      batchAnnualFeeForm.value.updateNextAnnualFee = false
      batchAnnualFeeForm.value.nextAnnualFeeCollectionTime = ''
    }
  }
)

onUnmounted(() => {
  if (syncCountdownTimer) {
    clearInterval(syncCountdownTimer)
  }
  webdavSyncService.stop()
})

// 安全功能状态
const showPasswordSetup = ref(false)
const showPasswordVerify = ref(false)
const showForgotPasswordDialog = ref(false)
const showPasswordRecovery = ref(false)

// 延迟执行标记：锁定状态下跳过的年费与迁移提示
const pendingMigrationInfo = ref(null)
const needsInitialChecks = ref(false)

// 自动锁定功能
const { isLocked, remainingTime, hasPassword, unlockApp, lockApp, initAfterPasswordSet, updateActivity, resetLockTimer } = useAutoLock()
provide('autoLock', { isLocked, remainingTime, hasPassword, unlockApp, lockApp, initAfterPasswordSet, updateActivity, resetLockTimer })

// 密码设置完成
const handlePasswordSet = () => {
  initAfterPasswordSet()
}

// 密码验证成功
const handlePasswordVerified = async () => {
  unlockApp()
  showPasswordVerify.value = false

  // 执行锁定期间延迟的年费与迁移提示
  if (needsInitialChecks.value) {
    needsInitialChecks.value = false
    if (cardData.value && cardData.value.length > 0) {
      await checkAnnualFeeQualified()
      await manualCheckAnnualFees()
    }
    if (pendingMigrationInfo.value) {
      await nextTick()
      await showMigrationReport(pendingMigrationInfo.value)
      pendingMigrationInfo.value = null
    }
  }
}

// 处理忘记密码选项
const handleForgotPasswordOption = (option) => {
  if (option === 'reset') {
    handleResetAllData()
  } else if (option === 'recover') {
    showPasswordRecovery.value = true
  }
}

// 重置所有数据
const handleResetAllData = async () => {
  try {
    await ElMessageBox.confirm(
      '此操作将清除所有数据，包括信用卡信息和云同步配置。确定继续吗？',
      '警告',
      {
        confirmButtonText: '确定清除',
        cancelButtonText: '取消',
        type: 'error',
        zIndex: 200010
      }
    )

    const success = PasswordManager.clearAllAppData()
    if (success) {
      ElMessage.success({ message: '数据已清除，请设置新密码', zIndex: 200010 })
      showPasswordSetup.value = true
    } else {
      ElMessage.error({ message: '数据清除失败', zIndex: 200010 })
    }
  } catch {
    ElMessage.info({ message: '已取消操作', zIndex: 200010 })
  }
}

// 找回密码成功
const handleRecoverySuccess = () => {
  showPasswordSetup.value = true
}

const closeAllDialogsForLock = () => {
  creditCardData.value.dialogFormVisible = false
  deleteDialogVisible.value = false
  showTableCustomDialog.value = false
  detailsVisible.value = false
  statisticsVisible.value = false
  batchAnnualFeeDialogVisible.value = false
  batchValidityDialogVisible.value = false
  showPasswordSetup.value = false
  showForgotPasswordDialog.value = false
  showPasswordRecovery.value = false

  helpPage.value?.hideHelp?.()
  webDAVConfig.value?.closeDialog?.()
}

// 手动锁定应用
const handleLockApp = () => {
  lockApp()
  closeAllDialogsForLock()
  showPasswordVerify.value = true
}

// 监听锁定状态
watch(() => isLocked.value, (locked) => {
  if (locked) {
    closeAllDialogsForLock()
    showPasswordVerify.value = true
  }
})

/**
 * 🔧 开发测试：导出脱敏数据
 * 将卡号、有效期、CVV随机化处理后复制到剪贴板
 */
const exportDesensitizedData = async () => {
  try {
    if (cardData.value.length === 0) {
      ElMessage.warning('没有数据可导出')
      return
    }

    // 生成随机卡号（16位数字）
    const generateRandomCardNumber = () => {
      const groups = []
      for (let i = 0; i < 4; i++) {
        groups.push(Math.floor(1000 + Math.random() * 9000).toString())
      }
      return groups.join(' ')
    }

    // 生成随机有效期（MM/YY格式，未来1-5年）
    const generateRandomValid = () => {
      const month = String(Math.floor(1 + Math.random() * 12)).padStart(2, '0')
      const year = String(new Date().getFullYear() % 100 + Math.floor(1 + Math.random() * 5)).padStart(2, '0')
      return `${month}/${year}`
    }

    // 生成随机CVV（3位数字）
    const generateRandomCVV = () => {
      return String(Math.floor(100 + Math.random() * 900))
    }

    // 处理数据，脱敏敏感字段
    const desensitizedData = cardData.value.map(card => ({
      ...card,
      cardNumber: generateRandomCardNumber(),  // 随机卡号
      valid: generateRandomValid(),            // 随机有效期
      cvv: generateRandomCVV()                 // 随机CVV
    }))

    // 构建导出数据
    const exportPayload = {
      version: '1.2.0',
      timestamp: new Date().toISOString().slice(0, 19).replace('T', ' '),
      totalCards: desensitizedData.length,
      note: '⚠️ 此数据已脱敏处理：卡号、有效期、CVV已随机化',
      cards: desensitizedData
    }

    const jsonStr = JSON.stringify(exportPayload, null, 2)

    // 复制到剪贴板
    await navigator.clipboard.writeText(jsonStr)

    ElMessage.success(`已复制 ${desensitizedData.length} 张卡片的脱敏数据到剪贴板`)
  } catch (error) {
    console.error('导出脱敏数据失败:', error)
    ElMessage.error('复制失败，请手动复制')
  }
}

onMounted(() => {
  // 检查是否需要设置密码
  if (!PasswordManager.hasPassword()) {
    showPasswordSetup.value = true
  } else if (PasswordManager.isAppLocked() || PasswordManager.shouldAutoLock()) {
    showPasswordVerify.value = true
  }
})
</script>

<style lang="scss">
@use './styles/app.scss';
@use './styles/responsive.scss';

// 全局弹窗样式
.annual-fee-dialog{
  width: 720px !important;
  max-width: 95vw !important;
}

// 删除确认框特殊样式
.delete-confirm-dialog {
  width: auto !important;
  min-width: 420px !important;

  .el-message-box__header {
    display: none !important;
  }

  .el-message-box__content {
    padding: 20px !important;
  }

  .el-message-box__btns {
    border-top: 1px solid #ebeef5;
    padding: 12px 20px !important;
    display: flex !important;
    justify-content: center !important;
    gap: 12px !important;

    button {
      margin-left: 0 !important;
      min-width: 100px !important;
    }

    .el-button--primary {
      background-color: #f56c6c !important;
      border-color: #f56c6c !important;

      &:hover {
        background-color: #f78989 !important;
        border-color: #f78989 !important;
      }
    }
  }
}

.annual-fee-check-dialog {
  .el-message-box {
    width: 800px;
    max-width: 95vw;
  }

  .el-message-box__header {
    padding-bottom: 0;
  }

  .el-message-box__content {
    padding: 0;
  }

  .el-message-box__btns {
    padding: 12px 16px;
    border-top: 1px solid #DCDFE6;
  }
}

.batch-update-form {
  display: flex;
  flex-direction: column;
  gap: 16px;

  .el-alert {
    margin-bottom: 2px;
  }

  .batch-field-row {
    display: flex;
    width: 100%;
    align-items: center;
    gap: 12px;
  }

  .batch-field-column {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .batch-input-number {
    width: 100%;
  }
}

/* 主题与安全集成顶栏胶囊舱样式 */
.theme-toggle-container {
  display: flex;
  align-items: center;
  margin-top: 12px;
  justify-content: center;
  padding: 4px 8px;
  border-radius: 30px;
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);

  /* 默认亮色模式：洁白轻透太空舱质感 */
  background: rgba(255, 255, 255, 0.88) !important;
  border: 1px solid rgba(86, 114, 190, 0.22) !important;
  box-shadow: 0 4px 16px rgba(86, 114, 190, 0.08), inset 0 1px 0 rgba(255, 255, 255, 0.7) !important;

  @media (min-width: 768px) {
    margin-top: 0;
    margin-left: 16px;
  }
}

/* 顶栏控制按钮-主题切换 */
.theme-toggle-btn {
  width: 32px !important;
  height: 32px !important;
  padding: 0 !important;
  display: inline-flex !important;
  align-items: center !important;
  justify-content: center !important;
  transition: all 0.25s cubic-bezier(0.25, 0.8, 0.25, 1) !important;
  border: none !important;
  background-color: rgba(0, 168, 180, 0.12) !important;
  color: #007780 !important;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.05) !important;
  cursor: pointer !important;

  :deep(.el-icon) {
    font-size: 14px !important;
  }

  &:hover {
    background-color: #007780 !important;
    color: #ffffff !important;
    transform: translateY(-1px) scale(1.05) !important;
    box-shadow: 0 4px 12px rgba(0, 168, 180, 0.3) !important;
  }
}



@media (max-width: 768px) {
  .theme-toggle-btn {
    width: 28px !important;
    height: 28px !important;

    :deep(.el-icon) {
      font-size: 12px !important;
    }
  }
}

.button-container {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px 14px;
  position: relative;
}

.toolbar-actions {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  min-width: 0;
  justify-self: center;
}

.view-mode-selector {
  justify-self: start;
}

.theme-toggle-container {
  justify-self: end;
}

.button-group {
  min-width: 0;
}

.more-actions {
  flex: 0 0 auto;
}

.sync-status-bar {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
  max-width: 860px;
  padding: 0;
  line-height: 1;

  .sync-status-pill {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    max-width: min(720px, 58vw);
    min-width: 0;
    padding: 5px 12px;
    border: 1px solid rgba(64, 158, 255, 0.28);
    border-radius: 999px;
    background: rgba(64, 158, 255, 0.08);
    color: var(--el-color-primary);
    overflow: hidden;
    white-space: nowrap;
  }

  .sync-state {
    flex: 0 0 auto;
    font-size: 13px;
    font-weight: 700;
  }

  .sync-meta {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    font-size: 12px;
    color: var(--el-text-color-secondary);
  }

  .sync-status-pill.is-success {
    background: rgba(103, 194, 58, 0.10);
    border-color: rgba(103, 194, 58, 0.32);
    color: var(--el-color-success);
  }

  .sync-status-pill.is-warning {
    background: rgba(230, 162, 60, 0.10);
    border-color: rgba(230, 162, 60, 0.34);
    color: var(--el-color-warning);
  }

  .sync-status-pill.is-danger {
    background: rgba(245, 108, 108, 0.10);
    border-color: rgba(245, 108, 108, 0.34);
    color: var(--el-color-danger);
  }

  .el-button {
    flex: 0 0 auto;
  }
}

@media (max-width: 1200px) {
  .button-container {
    grid-template-columns: 1fr;
  }

  .toolbar-actions,
  .view-mode-selector,
  .theme-toggle-container {
    justify-content: center;
    justify-self: center;
    margin-left: 0;
  }
}

@media (max-width: 900px) {
  .sync-status-bar {
    max-width: 100%;

    .sync-status-pill {
      max-width: calc(100vw - 170px);
    }
  }

  .toolbar-actions {
    flex-wrap: wrap;
  }
}

html.dark .sync-status-bar {
  .sync-status-pill {
    background: rgba(0, 242, 254, 0.08);
    border-color: rgba(0, 242, 254, 0.24);
    color: rgba(114, 236, 255, 0.92);
  }

  .sync-status-pill.is-success {
    background: rgba(103, 194, 58, 0.10);
    border-color: rgba(103, 194, 58, 0.26);
    color: rgba(149, 221, 119, 0.94);
  }

  .sync-status-pill.is-warning {
    background: rgba(230, 162, 60, 0.10);
    border-color: rgba(230, 162, 60, 0.28);
    color: rgba(239, 190, 104, 0.94);
  }

  .sync-status-pill.is-danger {
    background: rgba(245, 108, 108, 0.10);
    border-color: rgba(245, 108, 108, 0.28);
    color: rgba(248, 139, 139, 0.94);
  }

  .sync-meta {
    color: rgba(226, 232, 240, 0.72);
  }
}

:global(.main-more-dropdown .el-dropdown-menu__item) {
  display: flex;
  align-items: center;
  gap: 6px;
}

:global(.main-more-dropdown .danger-dropdown-item) {
  color: var(--el-color-danger);
}

/* 迁移报告弹窗样式 */
:deep(.migration-report-dialog) {
  max-width: 900px;

  .el-message-box__header {
    padding: 20px 20px 15px;
  }

  .el-message-box__title {
    font-size: 20px;
    font-weight: 600;
  }

  .el-message-box__content {
    padding: 10px 20px;
    max-height: calc(80vh - 120px);
    overflow-y: auto;
  }

  code {
    background: #f1f5f9;
    padding: 2px 6px;
    border-radius: 3px;
    font-family: 'Courier New', monospace;
    font-size: 12px;
  }
}
</style>
