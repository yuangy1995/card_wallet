<template>
  <div class="app-container">
    <div class="main_body">
      <SearchForm
        v-model="searchForm"
        :options="creditCardOptions"
        class="search-form"
      />
      <div class="button-container">
        <!-- 自动锁定倒计时显示 -->
        <AutoLockCountdown class="countdown-display" />
        
        <el-button-group class="button-group mobile-responsive">
          <el-button type="primary" @click="addCreditCard">
            <el-icon>
              <Plus />
            </el-icon>新增信用卡
          </el-button>
          <el-button type="success" @click="exportData">
            <el-icon>
              <Share />
            </el-icon>导出数据
          </el-button>
          <el-button type="warning" @click="importData">
            <el-icon>
              <FolderOpened />
            </el-icon>导入数据
          </el-button>
          <el-button type="primary" @click="showStatistics">
            <el-icon>
              <TrendCharts />
            </el-icon>统计分析
          </el-button>
          <el-button type="warning" @click="manualCheckAnnualFees">
            <el-icon>
              <Calendar />
            </el-icon>检测年费情况
          </el-button>
          <el-button type="primary" @click="showWebDAVConfig">
            <el-icon>
              <Connection />
            </el-icon>WebDAV配置
          </el-button>
          <el-button @click="handleBackup">
            <el-icon>
              <Upload />
            </el-icon>云备份
          </el-button>
          <el-button type="warning" @click="showLocalBackup">
            <el-icon>
              <DocumentCopy />
            </el-icon>本地备份
          </el-button>
          <el-button type="info" @click="openTableCustom">
            <el-icon>
              <Setting />
            </el-icon>自定义列
          </el-button>
          <el-button type="danger" @click="confirmClearData">
            <el-icon>
              <Delete />
            </el-icon>清除所有数据
          </el-button>
          <el-button type="warning" @click="generateRandomData">
            <el-icon>
              <Star />
            </el-icon>生成随机数据
          </el-button>
          <el-button type="info" @click="showHelp">
            <el-icon>
              <QuestionFilled />
            </el-icon>使用帮助
          </el-button>
          <!-- 开发测试：导出脱敏数据 -->
          <el-button v-if="isDev" type="danger" @click="exportDesensitizedData">
            <el-icon>
              <CopyDocument />
            </el-icon>导出脱敏数据
          </el-button>
        </el-button-group>
        
      </div>

      <!-- 批量操作工具栏 -->
      <BatchOperationToolbar
        :selected-rows="selectedRows"
        :total-count="tableData.length"
        @batch-delete="handleBatchDelete"
        @batch-export="handleBatchExport"
        @batch-update-status="handleBatchUpdateStatus"
        @batch-update-annual-fee="handleBatchUpdateAnnualFee"
        @batch-update-validity="handleBatchUpdateValidity"
        @clear-selection="clearSelection"
        @toggle-select-all="toggleSelectAll"
      />

      <CreditCardTable 
        :table-data="tableData" 
        :visible-columns="visibleColumns" 
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

      <CreditCardDialog v-model:visible="creditCardData.dialogFormVisible" :mode="status"
        :initial-data="creditCardData.data" :existing-cards="cardData" @submit="confirmAdd" @cancel="handleDialogCancel" class="mobile-dialog mobile-form" />

      <ImportExportDialog v-model:visible="importExportDialogVisible" :is-import="isImportMode" :data="cardData"
        @import="handleImportData" class="mobile-dialog" />

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
      <WebDAVConfigDialog ref="webDAVConfig" />
      <BackupDialog ref="backup" @update="handleBackupUpdate" @showConfig="showWebDAVConfig" />
      <LocalBackupDialog v-model="localBackupVisible" @restore="handleLocalBackupRestore" ref="localBackup" />
      
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
    
    <FloatingLockButton
      @lock-app="handleLockApp"
      @show-password-settings="showPasswordSetup = true"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, defineAsyncComponent, watch, onUnmounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Delete,
  Setting,
  Plus,
  Share,
  FolderOpened,
  TrendCharts,
  Calendar,
  Star,
  QuestionFilled,
  Connection,
  Upload,
  DocumentCopy,
  CopyDocument
} from '@element-plus/icons-vue'
import CreditCardTable from '@/components/table/CreditCardTable.vue'
import BatchOperationToolbar from '@/components/toolbar/BatchOperationToolbar.vue'
// 懒加载组件
const CreditCardDialog = defineAsyncComponent(() => import('@/components/dialog/CreditCardDialog.vue'))
const DeleteConfirmDialog = defineAsyncComponent(() => import('@/components/dialog/DeleteConfirmDialog.vue'))
const ImportExportDialog = defineAsyncComponent(() => import('@/components/dialog/ImportExportDialog.vue'))
const TableCustomDialog = defineAsyncComponent(() => import('@/components/dialog/TableCustomDialog.vue'))
const CardDetailsDialog = defineAsyncComponent(() => import('@/components/dialog/CardDetailsDialog.vue'))
const Statistics = defineAsyncComponent(() => import('@/components/Statistics.vue'))
const HelpPage = defineAsyncComponent(() => import('@/components/help/HelpPage.vue'))
const WebDAVConfigDialog = defineAsyncComponent(() => import('@/components/dialog/WebDAVConfigDialog.vue'))
const BackupDialog = defineAsyncComponent(() => import('@/components/dialog/BackupDialog.vue'))
const LocalBackupDialog = defineAsyncComponent(() => import('@/components/dialog/LocalBackupDialog.vue'))

// 安全功能组件导入
import PasswordSetup from '@/components/security/PasswordSetup.vue'
import PasswordVerify from '@/components/security/PasswordVerify.vue'
import ForgotPassword from '@/components/security/ForgotPassword.vue'
import PasswordRecovery from '@/components/security/PasswordRecovery.vue'
import FloatingLockButton from '@/components/security/FloatingLockButton.vue'
import AutoLockCountdown from '@/components/security/AutoLockCountdown.vue'

import { creditCardOptions } from '@/config/creditCardOptions'
import SearchForm from '@/components/search/SearchForm.vue'
import { generateMockData } from '@/utils/mockData'
import { encryptData, decryptData } from '@/utils/encryption'
import { formatDate, daysBetween } from '@/utils/dateUtils'
import { getCurrentTimeFormatted } from '@/utils/dateFormatter'
import { BACKUP_CONSTANTS, STORAGE_KEYS } from '@/config/constants'
import { saveCardData, getCardData, saveBackupData, getBackupData, saveTableColumns, getTableColumns, CardDataStorage } from '@/utils/storage'
import { useDebouncedRef } from '@/composables/useDebounce'
import { useKeyboardShortcuts } from '@/composables/useKeyboardShortcuts'
import { useTheme } from '@/composables/useTheme'
import { useAutoLock } from '@/composables/useAutoLock'
import { PasswordManager } from '@/utils/passwordManager'
import { getBankDisplayName } from '@/utils/bankNameFormatter'

// 状态管理
const cardData = ref([])
const selectedRows = ref([])
const creditCardTableRef = ref(null)

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
const importExportDialogVisible = ref(false)
const isImportMode = ref(false)
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
const localBackupVisible = ref(false)
const localBackup = ref(null)
let backupTimer = null

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
const backup = ref(null)

// 计算属性 - 优化缓存
const visibleColumns = computed(() => {
  return tableCustomColumns.value
    .filter(item => item.checked)
    .map(item => item.value)
})

// 防抖搜索优化
const debouncedSearchForm = useDebouncedRef(searchForm, 300)

const tableData = computed(() => {
  console.log('Computing tableData, cardData length:', cardData.value.length)
  const filtered = cardData.value.filter(card => {
    // 币种匹配
    const matchType = !searchForm.value.type || 
                     (card.type && (searchForm.value.type.includes(card.type) ||
                     card.type.includes(searchForm.value.type)));
    
    // 银行匹配
    const matchBank = !searchForm.value.bank || 
                     (card.bank && (searchForm.value.bank.includes(card.bank) ||
                     card.bank.includes(searchForm.value.bank)));
    
    // 卡片等级匹配
    const matchLevel = !searchForm.value.level || 
                      (card.level && (searchForm.value.level.includes(card.level) ||
                      card.level.includes(searchForm.value.level)));
    
    // 年费达标状态匹配
    const matchStatus = !searchForm.value.isQualified || 
                       searchForm.value.isQualified.length === 0 || 
                       searchForm.value.isQualified.includes(card.isQualified);
    
    // 别名搜索
    const matchAlias = !searchForm.value.alias || 
                      (card.alias && card.alias.toLowerCase().includes(searchForm.value.alias.toLowerCase()));
    
    // 国家匹配
    const matchCountry = !searchForm.value.country || 
                        (card.country && (searchForm.value.country.includes(card.country) ||
                        card.country.includes(searchForm.value.country)));
    
    // 卡号匹配 - 去除空格和其他格式字符进行匹配
    const matchCardNumber = !searchForm.value.cardNumber || 
                           (card.cardNumber && 
                            card.cardNumber.replace(/[\s-]/g, '').includes(searchForm.value.cardNumber.replace(/[\s-]/g, '')));
    
    // 额度匹配
    const matchLimit = !searchForm.value.limit || 
                      (card.limit && card.limit.toString().includes(searchForm.value.limit));
    
    // 权益匹配
    const matchEquity = !searchForm.value.equity || 
                       (card.equity && card.equity.toLowerCase().includes(searchForm.value.equity.toLowerCase()));
    
    // 备注匹配
    const matchRemark = !searchForm.value.remark || 
                       (card.remark && card.remark.toLowerCase().includes(searchForm.value.remark.toLowerCase()));
    
    return matchType && matchBank && matchLevel && matchStatus && matchAlias && 
           matchCountry && matchCardNumber && matchLimit && matchEquity && matchRemark;
  });

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
  
  sorted.forEach(card => {
    const country = card.country || '';
    const bank = (card.bank || '').replace(/\(.*?\)/g, "").trim();
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
    }
  });
  
  // 第二遍遍历，生成显示数据
  sorted.forEach((card, index) => {
    const country = card.country || '';
    const bank = (card.bank || '').replace(/\(.*?\)/g, "").trim();
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
      } else {
        processedCard.limitRowSpan = 0;
        processedCard.showLimit = false;
      }
    } else {
      // 独立额度不合并
      processedCard.limitRowSpan = 1;
      processedCard.showLimit = true;
      currentSharedLimit = null; // 重置共享额度状态
    }
    
    grouped.push(processedCard);
  });

  console.log('Filtered and grouped tableData length:', grouped.length)
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

// 初始化数据
onMounted(async () => {
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
    cardData.value = result.data
    
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
    showMigrationReport(migrationInfo)
  } finally {
    hideLoading()
  }
})

// 检查年费达标状态
const checkAnnualFeeQualified = async () => {
  const now = new Date()
  const warningCards = cardData.value.filter(card => {
    // 排除终身免年费('3')、已经是未达标状态('2')、或没有年费收取时间的卡片
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
            <p style="margin: 0; line-height: 1.6; color: #666;">
              提示：如果您在去年将卡片设为已达标，但今年忘记修改状态且消费未达标，可能会遗漏年费情况。为避免年费损失，建议点击"是"来更新状态。
            </p>
          </div>
          <div style="width: 1px; background: #DCDFE6; margin: 16px 0;"></div>
          <div style="flex: 1; padding: 16px;">
            <h3 style="margin: 0 0 16px 0; color: #E6A23C;">待处理卡片列表</h3>
            <div style="max-height: 400px; overflow-y: auto;">
              <ul style="list-style-type: none; padding: 0; margin: 0;">
                ${warningCards.map(card => `
                  <li style="margin-bottom: 8px; padding: 12px; background: #f5f7fa; border-radius: 4px;">
                    <div style="font-weight: bold; margin-bottom: 4px;">
                      ${card.bank.replace(/\(.*?\)/g, "").trim()} - ${card.alias}
                    </div>
                    <div style="color: #666; font-size: 13px;">
                      下次年费收取时间：${card.nextAnnualFeeCollectionTime}
                    </div>
                    <div style="color: #E6A23C; font-size: 13px; margin-top: 4px;">
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
        saveCardData(cardData.value)
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
      localStorage.setItem('cardData', JSON.stringify(cardData.value))
      
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
    data.lastModifyTime = getCurrentTimeFormatted()
    
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
          cardData.value[idx].lastModifyTime = getCurrentTimeFormatted()
        }
      })
    }
    
    localStorage.setItem('cardData', JSON.stringify(cardData.value))
    
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

const exportData = () => {
  isImportMode.value = false
  importExportDialogVisible.value = true
}

const importData = () => {
  isImportMode.value = true
  importExportDialogVisible.value = true
}

const handleImportData = (data) => {
  cardData.value = data
  localStorage.setItem('cardData', JSON.stringify(data))
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
    let message = '<div style="max-height: 400px; overflow-y: auto;">'

    if (unqualifiedCards.length > 0) {
      message += '<div style="margin-bottom: 16px;">'
      message += '<h3 style="color: #E6A23C; margin-bottom: 8px;">年费尚未达标</h3>'
      message += '<ul style="list-style-type: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 16px;">'
      unqualifiedCards.forEach(card => {
        message += `<li style="margin: 0; padding: 12px; background: #fdf6ec; border-radius: 4px; flex: 0 1 calc(33.33% - 12px); min-width: 200px; box-sizing: border-box;">
          <strong>${card.bank.replace(/\(.*?\)/g, "").trim()}</strong><br />
          <strong>${card.alias}</strong>
          <div style="color: #666; margin-top: 4px;">距离年费收取还有 ${card.diffDays} 天</div>
        </li>`
      })
      message += '</ul></div>'
    }

    if (warningCards.length > 0) {
      message += '<div style="margin-bottom: 16px;">'
      message += '<h3 style="color: #E6A23C; margin-bottom: 8px;">即将到期年费提醒</h3>'
      message += '<ul style="list-style-type: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 16px;">'
      warningCards.forEach(card => {
        message += `<li style="margin: 0; padding: 12px; background: #fefce8; border-radius: 4px; flex: 0 1 calc(33.33% - 12px); min-width: 200px; box-sizing: border-box;">
          <strong>${card.bank.replace(/\(.*?\)/g, "").trim()}</strong><br />
          <strong>${card.alias}</strong>
          <div style="color: #666; margin-top: 4px;">将在 ${Math.ceil((new Date(card.nextAnnualFeeCollectionTime) - now) / (1000 * 60 * 60 * 24))} 天后收取年费</div>
        </li>`
      })
      message += '</ul></div>'
    }

    if (overdueCards.length > 0) {
      message += '<div>'
      message += '<h3 style="color: #F56C6C; margin-bottom: 8px;">已过期年费提醒</h3>'
      message += '<ul style="list-style-type: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 16px;">'
      overdueCards.forEach(card => {
        message += `<li style="margin: 0; padding: 12px; background: #fef0f0; border-radius: 4px; flex: 0 1 calc(33.33% - 12px); min-width: 200px; box-sizing: border-box;">
          <strong>${card.bank.replace(/\(.*?\)/g, "").trim()}</strong><br />
          <strong>${card.alias}</strong>
          <div style="color: #666; margin-top: 4px;">已过期 ${Math.ceil((now - new Date(card.nextAnnualFeeCollectionTime)) / (1000 * 60 * 60 * 24))} 天</div>
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

const generateRandomData = () => {
  const mockData = generateMockData(50)
  console.log('Generated mock data:', mockData.length, 'items')
  cardData.value = mockData
  console.log('cardData.value updated:', cardData.value.length, 'items')
  ElMessage.success('成功生成 50 条随机数据')
  saveCardData(cardData.value)
}

// 批量操作相关函数
const handleSelectionChange = (selection) => {
  selectedRows.value = selection
}

const clearSelection = () => {
  if (creditCardTableRef.value && creditCardTableRef.value.clearSelection) {
    creditCardTableRef.value.clearSelection()
  }
}

const toggleSelectAll = () => {
  if (creditCardTableRef.value && creditCardTableRef.value.toggleSelectAll) {
    creditCardTableRef.value.toggleSelectAll()
  }
}

const handleBatchDelete = async (rows) => {
  try {
    const idsToDelete = rows.map(row => row.id)
    cardData.value = cardData.value.filter(card => !idsToDelete.includes(card.id))
    saveCardData(cardData.value)
    clearSelection()
    ElMessage.success(`成功删除 ${rows.length} 张信用卡`)
  } catch (error) {
    ElMessage.error('批量删除失败')
  }
}

const handleBatchExport = (rows) => {
  try {
    const dataToExport = rows.map(row => {
      const { ...exportData } = row
      return exportData
    })
    
    const encryptedData = encryptData(JSON.stringify(dataToExport))
    const blob = new Blob([encryptedData], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    
    const link = document.createElement('a')
    link.href = url
    link.download = `credit_cards_batch_${getCurrentTimeFormatted()}.dat`
    link.click()
    
    URL.revokeObjectURL(url)
    ElMessage.success(`成功导出 ${rows.length} 张信用卡数据`)
  } catch (error) {
    ElMessage.error('批量导出失败')
  }
}

const handleBatchUpdateStatus = ({ rows, status }) => {
  try {
    const idsToUpdate = rows.map(row => row.id)
    cardData.value.forEach(card => {
      if (idsToUpdate.includes(card.id)) {
        card.isQualified = status
        card.lastModifyTime = getCurrentTimeFormatted()
      }
    })
    saveCardData(cardData.value)
    clearSelection()
    const statusText = status === '1' ? '达标' : '未达标'
    ElMessage.success(`成功将 ${rows.length} 张信用卡标记为${statusText}`)
  } catch (error) {
    ElMessage.error('批量更新状态失败')
  }
}

const handleBatchUpdateAnnualFee = (rows) => {
  ElMessage.info('批量更新年费功能待实现')
  // TODO: 实现批量更新年费对话框
}

const handleBatchUpdateValidity = (rows) => {
  ElMessage.info('批量更新有效期功能待实现')
  // TODO: 实现批量更新有效期对话框
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
    cardData.value = []
    localStorage.setItem('cardData', JSON.stringify([]))
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

const setAnnualFeeQualified = (cardId) => {
  const card = cardData.value.find(c => c.id === cardId)
  if (card) {
    card.isQualified = '1'
  
    // 添加最后修改时间
    card.lastModifyTime = getCurrentTimeFormatted()
    localStorage.setItem('cardData', JSON.stringify(cardData.value))
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
        message: '✅ 数据结构已是最新版本，无需迁移',
        duration: 3000,
        showClose: true
      })
    }
    return
  }
  
  // 有迁移，显示详细弹窗
  const summary = migrationInfo.summary
  const details = migrationInfo.details || []
  
  // 构建详细的HTML内容
  let htmlContent = '<div style="max-height: 70vh; overflow-y: auto;">'
  
  // 概览部分
  htmlContent += '<div style="margin-bottom: 20px; padding: 15px; background: #f0f9ff; border-radius: 8px; border-left: 4px solid #3b82f6;">'
  htmlContent += '<h3 style="margin: 0 0 10px 0; color: #1e40af;">📊 迁移概览</h3>'
  htmlContent += `<p style="margin: 5px 0;"><strong>总卡片数:</strong> ${summary.total}</p>`
  htmlContent += `<p style="margin: 5px 0;"><strong>需要迁移:</strong> ${summary.migrated}</p>`
  htmlContent += `<p style="margin: 5px 0;"><strong>成功迁移:</strong> <span style="color: #16a34a;">${summary.success}</span></p>`
  
  if (summary.errors > 0) {
    htmlContent += `<p style="margin: 5px 0;"><strong>失败数量:</strong> <span style="color: #dc2626;">${summary.errors}</span></p>`
  }
  htmlContent += '</div>'
  
  // 失败的卡片
  if (summary.errors > 0 && summary.errorDetails && summary.errorDetails.length > 0) {
    htmlContent += '<div style="margin-bottom: 20px;">'
    htmlContent += '<h3 style="color: #dc2626; margin-bottom: 10px;">❌ 迁移失败的卡片</h3>'
    
    summary.errorDetails.forEach((error, index) => {
      htmlContent += '<div style="margin-bottom: 10px; padding: 12px; background: #fef2f2; border-radius: 6px; border-left: 4px solid #dc2626;">'
      htmlContent += `<p style="margin: 0 0 5px 0; font-weight: bold;">卡片 #${index + 1}</p>`
      htmlContent += `<p style="margin: 0; color: #666;">索引: ${error.index}</p>`
      if (error.cardId) {
        htmlContent += `<p style="margin: 5px 0 0 0; color: #666;">ID: ${error.cardId}</p>`
      }
      htmlContent += `<p style="margin: 5px 0 0 0; color: #dc2626;">错误: ${error.message}</p>`
      htmlContent += '</div>'
    })
    htmlContent += '</div>'
  }
  
  // 成功迁移的卡片详情（仅测试环境显示）
  if (isTestEnv && details.length > 0) {
    htmlContent += '<div style="margin-bottom: 20px;">'
    htmlContent += '<h3 style="color: #16a34a; margin-bottom: 10px;">✅ 成功迁移的卡片详情</h3>'
    htmlContent += '<p style="color: #666; font-size: 12px; margin-bottom: 10px;">以下列出所有字段变更的详细信息</p>'
    
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
      htmlContent += `<p style="margin: 0 0 8px 0; font-weight: bold; color: #15803d;">变更字段 (${changes.length}个):</p>`
      
      changes.forEach((change, changeIdx) => {
        htmlContent += '<div style="margin-bottom: 8px; padding: 8px; background: #fefce8; border-radius: 4px; font-size: 12px;">'
        htmlContent += `<p style="margin: 0 0 4px 0;"><strong>字段:</strong> <code style="background: #fef9c3; padding: 2px 6px; border-radius: 3px;">${change.field}</code></p>`
        
        // 显示旧值
        if (change.oldValue === undefined) {
          htmlContent += '<p style="margin: 4px 0; color: #666;">旧值: <span style="color: #999; font-style: italic;">未定义</span></p>'
        } else {
          htmlContent += `<p style="margin: 4px 0; color: #666;">旧值: <code>${JSON.stringify(change.oldValue)}</code></p>`
        }
        
        // 显示新值
        if (change.newValue === undefined) {
          htmlContent += '<p style="margin: 4px 0; color: #666;">新值: <span style="color: #999; font-style: italic;">已删除</span></p>'
        } else {
          htmlContent += `<p style="margin: 4px 0; color: #16a34a;">新值: <code>${JSON.stringify(change.newValue)}</code></p>`
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
    htmlContent += '<h3 style="color: #16a34a; margin-bottom: 10px;">✅ 成功迁移的卡片</h3>'
    
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
      htmlContent += `<p style="margin: 5px 0 0 0; font-size: 13px; color: #16a34a;">${changes.length} 个字段已更新</p>`
      htmlContent += '</div>'
    })
    htmlContent += '</div>'
  }
  
  htmlContent += '</div>'
  
  // 显示弹窗
  try {
    await ElMessageBox.alert(
      htmlContent,
      '🔄 数据迁移完成',
      {
        confirmButtonText: '我知道了',
        dangerouslyUseHTMLString: true,
        customClass: 'migration-report-dialog',
        showClose: true,
        closeOnClickModal: false,
        closeOnPressEscape: false,
        distinguishCancelAndClose: true,
        callback: (action) => {
          console.log('迁移报告已关闭')
        }
      }
    )
  } catch (error) {
    // 用户关闭弹窗
    console.log('用户关闭了迁移报告')
  }
}

const handleBackup = () => {
  backup.value?.open(cardData.value)
}

const handleBackupUpdate = (data) => {
  cardData.value = data
  localStorage.setItem('cardData', JSON.stringify(data))
}

const autoBackup = () => {
  const backups = getBackupData()
  const newBackup = {
    timestamp: Date.now(),
    data: JSON.parse(JSON.stringify(cardData.value)),
    status: 'success'
  }
  
  backups.unshift(newBackup)
  // 只保留最近备份
  const updatedBackups = backups.slice(0, BACKUP_CONSTANTS.MAX_BACKUP_COUNT)
  saveBackupData(updatedBackups)
}

const resetAutoBackupTimer = () => {
  if (backupTimer) {
    clearTimeout(backupTimer)
  }
  backupTimer = setTimeout(() => {
    autoBackup()
  }, 60000) // 1分钟后自动备份
}

const handleLocalBackupRestore = (data) => {
  cardData.value = data
  localStorage.setItem('cardData', JSON.stringify(data))
}

const showLocalBackup = () => {
  localBackupVisible.value = true
  localBackup.value?.handleOpen()
}

// 键盘快捷键配置
const shortcuts = {
  'ctrl+n': addCreditCard,
  'ctrl+shift+n': generateRandomData,
  'ctrl+e': exportData,
  'ctrl+i': importData,
  'ctrl+h': showHelp,
  'ctrl+t': () => showTableCustomDialog.value = true,
  'ctrl+s': showStatistics,
  'ctrl+shift+c': confirmClearData,
  'ctrl+b': () => backup.value?.openDialog(),
  'ctrl+shift+b': () => localBackupVisible.value = true,
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
  cardData,
  () => {
    resetAutoBackupTimer()
  },
  { deep: true }
)

onUnmounted(() => {
  if (backupTimer) {
    clearTimeout(backupTimer)
  }
})

// 安全功能状态
const showPasswordSetup = ref(false)
const showPasswordVerify = ref(false)
const showForgotPasswordDialog = ref(false)
const showPasswordRecovery = ref(false)

// 自动锁定功能
const { isLocked, unlockApp, lockApp, initAfterPasswordSet } = useAutoLock()

// 密码设置完成
const handlePasswordSet = () => {
  initAfterPasswordSet()
  ElMessage.success('密码设置成功，安全功能已启用')
}

// 密码验证成功
const handlePasswordVerified = () => {
  unlockApp()
  showPasswordVerify.value = false
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
      '此操作将清除所有数据，包括信用卡信息、WebDAV配置和本地备份。确定继续吗？',
      '警告',
      {
        confirmButtonText: '确定清除',
        cancelButtonText: '取消',
        type: 'error'
      }
    )
    
    const success = PasswordManager.clearAllAppData()
    if (success) {
      ElMessage.success('数据已清除，请设置新密码')
      showPasswordSetup.value = true
    } else {
      ElMessage.error('数据清除失败')
    }
  } catch {
    ElMessage.info('已取消操作')
  }
}

// 找回密码成功
const handleRecoverySuccess = () => {
  showPasswordSetup.value = true
}

// 手动锁定应用
const handleLockApp = () => {
  lockApp()
  showPasswordVerify.value = true
}

// 监听锁定状态
watch(() => isLocked.value, (locked) => {
  if (locked) {
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
    
    console.log('📋 脱敏数据已复制到剪贴板，长度:', jsonStr.length, '字符')
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

/* 主题切换器样式 */
.theme-toggle-container {
  display: flex;
  align-items: center;
  margin-top: 12px;
  justify-content: center;
  
  @media (min-width: 768px) {
    margin-top: 0;
    margin-left: 16px;
  }
}

.button-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  position: relative;
  
  @media (min-width: 768px) {
    flex-direction: row;
    justify-content: space-between;
  }
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
