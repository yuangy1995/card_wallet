<template>
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

    <CreditCardTable 
      :table-data="tableData" 
      @edit="editCreditCard" 
      @delete="handleDelete"
      @card-number-visibility="handleCardNumberVisibility" 
      @cvv-visibility="handleCvvVisibility"
      @view-details="viewDetails"
      @annual-fee-qualified="setAnnualFeeQualified"
      :row-class-name="getRowClassName"
    />

    <credit-card-dialog v-model:visible="creditCardData.dialogFormVisible" :mode="status"
      :initial-data="creditCardData.data" @submit="confirmAdd" @cancel="handleDialogCancel" />

    <import-export-dialog v-model:visible="importExportDialogVisible" :is-import="isImportMode" :data="cardData"
      @import="handleImportData" />

    <delete-confirm-dialog v-model:visible="deleteDialogVisible" :card-info="cardToDelete" @confirm="confirmDelete" />


    <!-- 表格自定义框 -->
    <table-custom-dialog v-model:visible="tableCustom.dialogFormVisible"
      :columns="creditCardData.options.tableCustomData" :initial-selection="selectedTableColumns"
      @confirm="handleTableCustomConfirm" />
    <!-- 查看详情弹窗 -->
    <card-details-dialog v-model:visible="detailsVisible" :card-info="currentCard" />
    <!-- 统计分析弹窗 -->
    <el-dialog v-model="statisticsVisible" title="信用卡统计分析" width="80%" :destroy-on-close="true">
      <el-scrollbar max-height="700px">
        <Statistics v-if="statisticsVisible" :card-data="cardData" />
      </el-scrollbar>

    </el-dialog>
  </div>
</template>

<script>
import { creditCardOptions } from '@/config/creditCardOptions'
import { ElNotification, ElMessage, ElMessageBox } from 'element-plus'
import SearchForm from './components/search/SearchForm.vue'
import CreditCardTable from './components/table/CreditCardTable.vue'
import CreditCardDialog from './components/dialog/CreditCardDialog.vue'
import ImportExportDialog from './components/dialog/ImportExportDialog.vue'
import DeleteConfirmDialog from './components/dialog/DeleteConfirmDialog.vue'
import { Plus, Share, FolderOpened, TrendCharts, Calendar, Delete, Star } from '@element-plus/icons-vue'
import { predefinedNotifications } from './utils/notification'
import {
  timestampToTime,
  completeAccountBillDate,
  completeDueDate,
  calculateInterestFreePeriod,
  calculateRemainingDaysForPreviousBill,
  isNearAnnualFeeDate
} from './utils/dateCalculator'
import CardDetailsDialog from './components/dialog/CardDetailsDialog.vue'
import TableCustomDialog from './components/dialog/TableCustomDialog.vue'
import Statistics from './components/Statistics.vue'
import { generateMockData } from './utils/mockData'

export default {
  components: {
    Plus,
    FolderOpened,
    Share,
    TrendCharts,
    Calendar,
    Delete,
    Star,
    SearchForm,
    CreditCardTable,
    CreditCardDialog,
    ImportExportDialog,
    DeleteConfirmDialog,
    CardDetailsDialog,
    TableCustomDialog,
    Statistics
  },
  data() {
    return {
      cardData: [],
      labelWidth: '80px',
      detailsVisible: false,
      currentCard: {},
      userData: {
        tableCustom: {
          country: true,
          bank: true,
          cardNumber: true,
          level: true,
          alias: true,
          limit: true,
          type: true,
          cvv: true,
          valid: true,
          annualFee: true,
          nowDueDate: true,
          preDueDateDay: true,
          nowAccountBillDate: true,
          nextDueDate: true,
          nextAccountBillDate: true,
          interestFreePeriod: true,
          isQualified: true,
          nextAnnualFeeCollectionTime: true,
          lastTime: true,
          equity: true,
          remark: true,
        }
      },
      formSearch: {
        country: "",
        bank: "",
        type: "",
        cardNumber: "",
        level: "",
        limit: "",
        cvv: "",
        alias: "",
        annualFee: "",
        equity: "",
        remark: "",
        isQualified: "",
      },
      status: "add",
      creditCardData: {
        dialogFormVisible: false,
        data: {
          id: "",
          country: "",//国家
          bank: "",//银行
          cardNumber: "",//卡号
          level: "",//等级
          alias: "",//卡片别名
          limit: "",//额度
          type: "",//币种
          cvv: "",//cvv码
          valid: "",//有效期
          annualFee: "",//年费
          accountBillDate: "",//账单日
          dueDate: "",//还款日
          isQualified: '2',//本年度年费是否达标
          nextAnnualFeeCollectionTime: "",//下次年费收取时间
          lastTime: "",//距离上次提额多少天了
          equity: "",//权益
          remark: "",//备注
        },
        options: creditCardOptions // 使用导入的配置
      },
      sortData: {
        dialogFormVisible: false,
        value: '银行',
        options: ["国家", "银行", "等级", "币种", "本年度年费是否达标"]
      },
      tableCustom: {
        dialogFormVisible: false,
      },
      cvvVisibility: {}, // CVV显示控制
      cvvTimer: null, // CVV显示定时器
      cardNumberVisibility: {}, // 卡号显示控制
      cardNumberTimer: null, // 卡号显示定时器
      sortDialogVisible: false,
      sortValue: '1',
      importExportDialogVisible: false,
      isImportMode: false,
      deleteDialogVisible: false,
      cardToDelete: {},
      selectedTableColumns: [],
      statisticsVisible: false,
      rowClassMap: new Map(), // 存储需要特殊标记的行的样式
    }
  },
  created() {
    // 从localStorage中获取数据
    const storedData = localStorage.getItem('cardData')
    if (storedData) {
      this.cardData = JSON.parse(storedData)
    }
    
    // 从localStorage中获取表格自定义数据
    const storedTableCustom = localStorage.getItem('tableCustom')
    if (storedTableCustom) {
      this.userData.tableCustom = JSON.parse(storedTableCustom)
      this.selectedTableColumns = this.userData.tableCustom
    } else {
      this.selectedTableColumns = creditCardOptions.tableCustomData
    }

  },
  mounted() {
    // 在mounted时检查年费，确保DOM已经加载完成
    this.$nextTick(() => {
      this.checkAnnualFees()
    })
  },
  computed: {
    // 计算过滤条件后的表格数据
    tableData() {
      return this.cardData.filter(item => {
        // 检查每个搜索条件，如果搜索条件为空则跳过该条件
        const conditions = {
          bank: this.formSearch.bank,
          country: this.formSearch.country,
          type: this.formSearch.type,
          cardNumber: this.formSearch.cardNumber,
          level: this.formSearch.level,
          limit: this.formSearch.limit,
          cvv: this.formSearch.cvv,
          alias: this.formSearch.alias,
          annualFee: this.formSearch.annualFee,
          equity: this.formSearch.equity,
          remark: this.formSearch.remark,
          isQualified: this.formSearch.isQualified,
        };

        // 只检查非空的搜索条件
        return Object.entries(conditions).every(([key, value]) => {
          if (!value) return true; // 如果搜索条件为空，返回 true（不过滤）

          const itemValue = item[key]?.toString().toLowerCase() || '';
          const searchValue = value.toString().toLowerCase();
          return itemValue.includes(searchValue);
        });
      });
    },
  },
  methods: {
    notic(title, message, type, duration, html) {
      ElNotification({
        title: title,
        message: message,
        type: type,
        duration: duration,
        dangerouslyUseHTMLString: html
      })
    },
    handleStatisticsUpdated(statistics) {
      this.creditCardStatistics = statistics;
    },
    deleteAllData() {
      localStorage.removeItem('cardData');
      this.cardData = [];
      this.notic('成功', '数据已清空', 'success', 2000);
    },
    addCreditCard() {
      this.status = 'add';
      this.creditCardData.dialogFormVisible = true;
      this.creditCardData.data = {
        bank: "",
        country: "",
        type: "",
        cardNumber: "",
        level: "",
        limit: "",
        cvv: "",
        valid: "",
        accountBillDate: "",
        dueDate: "",
        alias: "",
        annualFee: "",
        equity: "",
        remark: "",
        isQualified: "",
        nextAnnualFeeCollectionTime: "",
        lastTime: "",
      };
    },
    editCreditCard(row) {
      this.status = 'edit';
      this.creditCardData.dialogFormVisible = true;
      this.creditCardData.data = Object.assign({}, row);
    },
    confirmAdd(data) {
      if (this.status == 'add') {
        this.notic('添加成功', '该卡片已被添加！', 'success', 2000);
        this.creditCardData.dialogFormVisible = false;
        this.cardData.push(Object.assign({}, data));
        predefinedNotifications.cardAdded()
      } else if (this.status == 'edit') {
        this.cardData.splice(this.cardData.findIndex(item => item.id == data.id), 1, Object.assign({}, data));
        this.notic('修改成功', '该卡片已被修改！', 'success', 2000);
        this.creditCardData.dialogFormVisible = false;
        predefinedNotifications.cardUpdated()
      }
    },
    handleDelete(row) {
      this.cardToDelete = row;
      this.deleteDialogVisible = true;
    },
    confirmDelete() {
      if (this.cardToDelete) {
        this.cardData = this.cardData.filter(card => card.id !== this.cardToDelete.id);
        predefinedNotifications.cardDeleted()
        this.cardToDelete = {};
      }
    },
    exportData() {
      this.isImportMode = false;
      this.importExportDialogVisible = true;
    },
    importData() {
      this.isImportMode = true;
      this.importExportDialogVisible = true;
    },
    handleImportData(data) {
      this.cardData = data;
      this.notic('成功', '数据导入成功！', 'success', 2000);
      predefinedNotifications.dataImported()
    },
    oneKeySort() {
      this.sortData.dialogFormVisible = true;
    },
    oneKeySortConfirm() {
      const sortKey = {
        '国家': 'country',
        '银行': 'bank',
        '等级': 'level',
        '币种': 'type',
        '本年度年费是否达标': 'isQualified'
      };
      const key = sortKey[this.sortData.value];
      if (!key) return;
      this.cardData.sort((a, b) => {
        if (a[key] === b[key]) return 0;
        return a[key] > b[key] ? 1 : -1;
      });
      this.sortData.dialogFormVisible = false;
      this.notic('成功', '排序完成', 'success', 2000);
    },

    twoCheck() {
      this.cardData.forEach(card => {
        if (card.nextAnnualFeeCollectionTime) {
          const nextAnnualFeeDate = new Date(card.nextAnnualFeeCollectionTime);
          if (isNearAnnualFeeDate(nextAnnualFeeDate)) {
            this.notic(
              '提醒',
              `${card.bank}的${card.alias || card.cardNumber}将在60天内收取年费`,
              'warning', 0, true
            );
          }
        }
      });
    },
    handleTableCustomConfirm(selectedColumns) {
      this.selectedTableColumns = selectedColumns
      this.creditCardData.options.tableCustomData.forEach(item => {
        item.checked = selectedColumns.includes(item.prop)
      })
      // 保存到本地存储
      localStorage.setItem('tableCustom', JSON.stringify(this.creditCardData.options.tableCustomData))
    },
    viewDetails(row) {
      this.currentCard = { ...row };
      this.detailsVisible = true;
    },
    handleCardNumberVisibility({ id, isVisible }) {
      const card = this.cardData.find(card => card.id === id)
      if (card) {
        if (isVisible) {
          this.notic('已显示卡号', '30秒后将自动隐藏', 'info', 3000)
        } else {
          this.notic('已隐藏卡号', '', 'info', 3000)
        }
      }
    },
    handleCvvVisibility({ id, isVisible }) {
      const card = this.cardData.find(card => card.id === id)
      if (card) {
        if (isVisible) {
          this.notic('已显示CVV', '30秒后将自动隐藏', 'info', 3000)
        } else {
          this.notic('已隐藏CVV', '', 'info', 3000)
        }
      }
    },
    handleDialogCancel() {
      this.creditCardData.dialogFormVisible = false;
    },
    showStatistics() {
      this.statisticsVisible = true
    },
    // 检查年费状态
    async checkAnnualFees() {
      const now = new Date()
      const warningCards = []
      const overdueCards = []
      
      // 清除之前的样式
      this.rowClassMap.clear()
      
      // 收集需要提醒的卡片
      for (const card of this.cardData) {
        if (!card.nextAnnualFeeCollectionTime) continue
        
        const dueDate = new Date(card.nextAnnualFeeCollectionTime)
        const diffDays = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24))
        
        if (diffDays <= 60 && diffDays > 0) {
          warningCards.push({ ...card, diffDays })
          this.rowClassMap.set(card.id, 'warning-row')
        } else if (diffDays <= 0 && diffDays > -60) {
          overdueCards.push({ ...card, diffDays })
          this.rowClassMap.set(card.id, 'danger-row')
        }
      }
      
      // 如果有需要提醒的卡片，显示汇总弹窗
      if (warningCards.length > 0 || overdueCards.length > 0) {
        // 构建提醒消息
        let message = '<div style="max-height: 400px; overflow-y: auto;">'
        
        if (warningCards.length > 0) {
          message += '<div style="margin-bottom: 16px;">'
          message += '<h3 style="color: #E6A23C; margin-bottom: 8px;">即将到期年费提醒</h3>'
          message += '<ul style="list-style-type: none; padding: 0; margin: 0;">'
          warningCards.sort((a, b) => a.diffDays - b.diffDays).forEach(card => {
            message += `<li style="margin-bottom: 8px; padding: 8px; background: #FDF6EC; border-radius: 4px;">
              <strong>${card.alias}</strong>
              <div style="color: #666; margin-top: 4px;">将在 ${card.diffDays} 天后收取年费</div>
            </li>`
          })
          message += '</ul></div>'
        }
        
        if (overdueCards.length > 0) {
          message += '<div>'
          message += '<h3 style="color: #F56C6C; margin-bottom: 8px;">已过期年费提醒</h3>'
          message += '<ul style="list-style-type: none; padding: 0; margin: 0;">'
          overdueCards.sort((a, b) => b.diffDays - a.diffDays).forEach(card => {
            message += `<li style="margin-bottom: 8px; padding: 8px; background: #FEF0F0; border-radius: 4px;">
              <strong>${card.alias}</strong>
              <div style="color: #666; margin-top: 4px;">已过期 ${-card.diffDays} 天</div>
            </li>`
          })
          message += '</ul></div>'
        }
        
        message += '</div>'
        
        try {
          await ElMessageBox.alert(
            message,
            '年费提醒',
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
    },
    // 手动检测年费情况
    async manualCheckAnnualFees() {
      const now = new Date()
      const warningCards = []
      const overdueCards = []
      
      // 清除之前的样式
      this.rowClassMap.clear()
      
      // 收集需要提醒的卡片
      for (const card of this.cardData) {
        if (!card.nextAnnualFeeCollectionTime) continue
        
        const dueDate = new Date(card.nextAnnualFeeCollectionTime)
        const diffDays = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24))
        
        if (diffDays <= 60 && diffDays > 0) {
          warningCards.push({ ...card, diffDays })
          this.rowClassMap.set(card.id, 'warning-row')
        } else if (diffDays <= 0 && diffDays > -60) {
          overdueCards.push({ ...card, diffDays })
          this.rowClassMap.set(card.id, 'danger-row')
        }
      }
      
      // 如果有需要提醒的卡片，显示汇总弹窗
      if (warningCards.length > 0 || overdueCards.length > 0) {
        // 构建提醒消息
        let message = '<div style="max-height: 400px; overflow-y: auto;">'
        
        if (warningCards.length > 0) {
          message += '<div style="margin-bottom: 16px;">'
          message += '<h3 style="color: #E6A23C; margin-bottom: 8px;">即将到期年费提醒</h3>'
          message += '<ul style="list-style-type: none; padding: 0; margin: 0;">'
          warningCards.sort((a, b) => a.diffDays - b.diffDays).forEach(card => {
            message += `<li style="margin-bottom: 8px; padding: 8px; background: #FDF6EC; border-radius: 4px;">
              <strong>${card.alias}</strong>
              <div style="color: #666; margin-top: 4px;">将在 ${card.diffDays} 天后收取年费</div>
            </li>`
          })
          message += '</ul></div>'
        }
        
        if (overdueCards.length > 0) {
          message += '<div>'
          message += '<h3 style="color: #F56C6C; margin-bottom: 8px;">已过期年费提醒</h3>'
          message += '<ul style="list-style-type: none; padding: 0; margin: 0;">'
          overdueCards.sort((a, b) => b.diffDays - a.diffDays).forEach(card => {
            message += `<li style="margin-bottom: 8px; padding: 8px; background: #FEF0F0; border-radius: 4px;">
              <strong>${card.alias}</strong>
              <div style="color: #666; margin-top: 4px;">已过期 ${-card.diffDays} 天</div>
            </li>`
          })
          message += '</ul></div>'
        }
        
        message += '</div>'
        
        try {
          await ElMessageBox.alert(
            message,
            '年费提醒',
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
    },
    // 设置年费已达标
    setAnnualFeeQualified(cardId) {
      const card = this.cardData.find(c => c.id === cardId)
      if (card) {
        // 更新下次年费收取时间
        const currentDate = new Date(card.nextAnnualFeeCollectionTime)
        currentDate.setFullYear(currentDate.getFullYear() + 1)
        card.nextAnnualFeeCollectionTime = currentDate.toISOString().split('T')[0]
        
        // 设置年费达标状态
        card.isQualified = '1' // 1表示已达标
        
        // 清除行样式
        this.rowClassMap.delete(cardId)
        
        // 保存数据
        this.saveData()
        
        ElMessage.success('年费达标状态已更新')
        
        // 重新检查年费状态
        this.checkAnnualFees()
      }
    },

    // 获取行的类名
    getRowClassName({ row }) {
      return this.rowClassMap.get(row.id)
    },
    // 确认清除数据
    async confirmClearData() {
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
        this.clearAllData()
      } catch {
        // 用户取消操作
      }
    },

    // 清除所有数据
    clearAllData() {
      // 清除信用卡数据
      this.cardData = []
      // 清除本地存储
      localStorage.removeItem('cardData')
      // 清除行样式映射
      this.rowClassMap.clear()
      
      ElMessage({
        type: 'success',
        message: '所有数据已清除',
        duration: 2000
      })
    },
    // 生成随机数据
    generateRandomData() {
      const mockData = generateMockData(15)
      this.cardData = [...this.cardData, ...mockData]
      ElMessage.success('已生成15条随机信用卡数据')
    },
  },
  watch: {
    //监听cardData的变化，如果变化了，就把cardData存到localStorage里面
    'cardData': {
      handler: function (val, oldVal) {
        localStorage.setItem('cardData', JSON.stringify(val));
      },
      deep: true
    },
    //监听creditCardData.data.cardNumber的变化，每新增4个字符就在后面加一个空格
    'creditCardData.data.cardNumber': {
      handler: function (val, oldVal) {
        if (val.length == 4 || val.length == 9 || val.length == 14 || val.length == 19) {
          this.creditCardData.data.cardNumber = val + ' ';
        }
      },
      deep: true
    },
    //监听formSearch.cardNumber的变化，每新增4个字符就在后面加一个空格
    'formSearch.cardNumber': {
      handler: function (val, oldVal) {
        if (val.length == 4 || val.length == 9 || val.length == 14 || val.length == 19) {
          this.formSearch.cardNumber = val + ' ';
        }
      },
      deep: true
    },
    //监听表格自定义数据的变化，有变化就存储到localStorage里面
    "userData.tableCustom": {
      handler: function (val, oldVal) {
        localStorage.setItem('tableCustom', JSON.stringify(val));
      },
      deep: true
    }
  },
}
</script>

<style lang="scss">
@import '@/styles/app.scss';
</style>
