<template>
  <div class="app-container">
    <div class="main_body">
      <div class="headers">
        <SearchForm v-model="formSearch" :options="creditCardData.options" :label-width="labelWidth" />
      </div>
      <div class="button-container">
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
        <el-button type="primary" @click="manualCheckAnnualFees">
          <el-icon>
            <Calendar />
          </el-icon>检测年费情况
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
      </div>

      <CreditCardTable :table-data="tableData" :visible-columns="visibleColumns" @edit="editCreditCard"
        @delete="deleteCard" @card-number-visibility="handleCardNumberVisibility" @cvv-visibility="handleCvvVisibility"
        @view-details="viewDetails" @annual-fee-qualified="setAnnualFeeQualified" :row-class-name="getRowClassName" />

      <CreditCardDialog v-model:visible="creditCardData.dialogFormVisible" :mode="status"
        :initial-data="creditCardData.data" @submit="confirmAdd" @cancel="handleDialogCancel" />

      <ImportExportDialog v-model:visible="importExportDialogVisible" :is-import="isImportMode" :data="cardData"
        @import="handleImportData" />

      <DeleteConfirmDialog v-model:visible="deleteDialogVisible" :card-info="cardToDelete" @confirm="confirmDelete" />

      <!-- 表格自定义框 -->
      <TableCustomDialog v-model:visible="showTableCustomDialog" :columns="tableCustomColumns"
        @confirm="handleTableCustomConfirm" />
      <!-- 查看详情弹窗 -->
      <CardDetailsDialog v-model:visible="detailsVisible" :card-info="currentCard" />
      <!-- 统计分析弹窗 -->
      <el-dialog v-model="statisticsVisible" title="信用卡统计分析" width="80%" :destroy-on-close="true">
        <el-scrollbar max-height="700px">
          <Statistics v-if="statisticsVisible" :card-data="cardData" />
        </el-scrollbar>

      </el-dialog>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Setting, Plus, Share, FolderOpened, TrendCharts, Calendar, Delete, Star } from '@element-plus/icons-vue'
import { creditCardOptions } from './config/creditCardOptions'
import SearchForm from './components/search/SearchForm.vue'
import CreditCardTable from './components/table/CreditCardTable.vue'
import TableCustomDialog from './components/dialog/TableCustomDialog.vue'
import CardDetailsDialog from './components/dialog/CardDetailsDialog.vue'
import CreditCardDialog from './components/dialog/CreditCardDialog.vue'
import ImportExportDialog from './components/dialog/ImportExportDialog.vue'
import DeleteConfirmDialog from './components/dialog/DeleteConfirmDialog.vue'
import Statistics from './components/Statistics.vue'
import { generateMockData } from './utils/mockData'

export default {
  name: 'App',
  components: {
    SearchForm,
    CreditCardTable,
    TableCustomDialog,
    CardDetailsDialog,
    CreditCardDialog,
    ImportExportDialog,
    DeleteConfirmDialog,
    Statistics,
    Setting,
    Plus,
    Share,
    FolderOpened,
    TrendCharts,
    Calendar,
    Delete,
    Star,
  },
  setup() {
    // 状态管理
    const cardData = ref([])
    const showTableCustomDialog = ref(false)
    const tableCustomColumns = ref(JSON.parse(JSON.stringify(creditCardOptions.tableCustomData)))
    const deleteDialogVisible = ref(false)
    const cardToDelete = ref({
      cardName: '',
      bankName: '',
      cardType: ''
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
    const formSearch = ref({
      bank: '',
      cardType: '',
      cardNumber: '',
      cardHolder: '',
      accountBillDate: '',
      dueDate: '',
      isQualified: '',
      nextAnnualFeeCollectionTime: '',
      lastTime: '',
    })
    const status = ref('add')
    const labelWidth = ref('120px')

    // 计算属性
    const visibleColumns = computed(() => {
      return tableCustomColumns.value
        .filter(item => item.checked)
        .map(item => item.value)
    })

    const tableData = computed(() => cardData.value)

    // 初始化数据
    onMounted(() => {
      // 加载列配置
      const savedColumns = localStorage.getItem('tableCustomColumns')
      if (savedColumns) {
        try {
          const parsed = JSON.parse(savedColumns)
          tableCustomColumns.value = parsed
          console.log('Loaded saved columns:', parsed)
        } catch (e) {
          console.error('Error loading saved columns:', e)
        }
      }

      // 加载卡片数据
      const storedData = localStorage.getItem('cardData')
      if (storedData) {
        cardData.value = JSON.parse(storedData)
      }
    })

    // 方法
    const handleTableCustomConfirm = (columns) => {
      console.log('Handling column confirmation:', columns)
      tableCustomColumns.value = columns
      localStorage.setItem('tableCustomColumns', JSON.stringify(columns))
      showTableCustomDialog.value = false
      ElMessage.success('列配置已保存')
    }

    const openTableCustom = () => {
      console.log('Opening custom table dialog')
      showTableCustomDialog.value = true
    }

    const confirmDelete = () => {
      if (cardToDelete.value) {
        cardData.value = cardData.value.filter(item => item.id !== cardToDelete.value.id)
        deleteDialogVisible.value = false
        cardToDelete.value = null
        ElMessage.success('删除成功')
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

    const confirmAdd = (data) => {
      if (status.value === 'add') {
        ElMessage.success('添加成功')
        creditCardData.value.dialogFormVisible = false
        cardData.value.push(Object.assign({}, data))
      } else if (status.value === 'edit') {
        const index = cardData.value.findIndex(item => item.id === data.id)
        if (index > -1) {
          cardData.value.splice(index, 1, Object.assign({}, data))
          ElMessage.success('修改成功')
          creditCardData.value.dialogFormVisible = false
        }
      }
    }

    const deleteCard = (row) => {
      deleteDialogVisible.value = true
      cardToDelete.value = {
        cardName: row.alias || `${row.bank} ${row.level}`,
        bankName: row.bank,
        cardType: row.type
      }
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
      ElMessage.success('导入成功')
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

        if (diffDays <= 60 && diffDays > 0 && card.isQualified !== '2') {
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
              <strong>${card.bank}${card.type}</strong>
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
              <strong>${card.bank}${card.type}</strong>
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
              <strong>${card.bank}${card.type}</strong>
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
          // 忽略弹窗关闭事件
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
      const mockData = generateMockData(15)
      cardData.value = [...cardData.value, ...mockData]
      ElMessage.success('已生成15条随机信用卡数据')
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
        localStorage.removeItem('cardData')
        ElMessage.success('所有数据已清除')
      } catch {
        // 用户取消操作
      }
    }

    const handleCardNumberVisibility = ({ id, isVisible }) => {
      console.log('Card number visibility changed:', id, isVisible)
    }

    const handleCvvVisibility = ({ id, isVisible }) => {
      console.log('CVV visibility changed:', id, isVisible)
    }

    const setAnnualFeeQualified = (cardId) => {
      const card = cardData.value.find(c => c.id === cardId)
      if (card) {
        card.isQualified = '1'
        // Save to localStorage or backend
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

    return {
      cardData,
      showTableCustomDialog,
      tableCustomColumns,
      deleteDialogVisible,
      cardToDelete,
      detailsVisible,
      currentCard,
      statisticsVisible,
      importExportDialogVisible,
      isImportMode,
      creditCardData,
      formSearch,
      status,
      labelWidth,
      visibleColumns,
      tableData,
      handleTableCustomConfirm,
      openTableCustom,
      confirmDelete,
      addCreditCard,
      editCreditCard,
      confirmAdd,
      deleteCard,
      exportData,
      importData,
      handleImportData,
      viewDetails,
      showStatistics,
      manualCheckAnnualFees,
      generateRandomData,
      confirmClearData,
      handleCardNumberVisibility,
      handleCvvVisibility,
      setAnnualFeeQualified,
      getRowClassName,
      handleDialogCancel,
    }
  },
}
</script>

<style lang="scss">
@use './styles/app.scss';

// 全局弹窗样式
.el-message-box {
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
</style>
