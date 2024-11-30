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
      <el-button type="info" @click="showStatistics">
        <el-icon>
          <TrendCharts />
        </el-icon>统计分析
      </el-button>
    </div>

    <CreditCardTable :table-data="tableData" @edit="editCreditCard" @delete="handleDelete"
      @card-number-visibility="handleCardNumberVisibility" @cvv-visibility="handleCvvVisibility"
      @view-details="viewDetails" />

    <credit-card-dialog v-model:visible="creditCardData.dialogFormVisible" :mode="status"
      :initial-data="creditCardData.data" @submit="confirmAdd" @cancel="handleDialogCancel" />


    <import-export-dialog v-model:visible="importExportDialogVisible" :is-import="isImportMode" :data="cardData"
      @import="handleImportData" />

    <delete-confirm-dialog v-model:visible="deleteDialogVisible" :card-info="cardToDelete" @confirm="confirmDelete" />


    <!-- 表格自定义框 -->
    <table-custom-dialog v-model:visible="tableCustom.dialogFormVisible"
      :columns="creditCardData.options.tableCustomData" :initial-selection="selectedTableColumns"
      @confirm="handleTableCustomConfirm" />
    <!-- 统计信息 -->
    <credit-card-statistics :card-data="cardData" @statistics-updated="handleStatisticsUpdated" />
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
import { ElNotification } from 'element-plus'
import SearchForm from './components/search/SearchForm.vue'
import CreditCardTable from './components/table/CreditCardTable.vue'
import CreditCardDialog from './components/dialog/CreditCardDialog.vue'
import ImportExportDialog from './components/dialog/ImportExportDialog.vue'
import DeleteConfirmDialog from './components/dialog/DeleteConfirmDialog.vue'
import { Plus, Share, FolderOpened, TrendCharts } from '@element-plus/icons-vue'
import { predefinedNotifications } from './utils/notification'
import CreditCardStatistics from './components/statistics/CreditCardStatistics.vue'
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

export default {
  components: {
    Plus,
    FolderOpened,
    Share,
    TrendCharts,
    SearchForm,
    CreditCardTable,
    CreditCardDialog,
    ImportExportDialog,
    DeleteConfirmDialog,
    CardDetailsDialog,
    TableCustomDialog,
    CreditCardStatistics,
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
    }
  },
  created() {
    //如果本地存储中有数据，就用本地存储中的数据
    if (localStorage.getItem("cardData")) {
      this.cardData = JSON.parse(localStorage.getItem("cardData"));
      this.notic('Success', '浏览器数据加载成功！', 'success', 3000);
    }
    setTimeout(() => {
      if (localStorage.getItem("tableCustom")) {
        this.userData.tableCustom = JSON.parse(localStorage.getItem("tableCustom"));
        this.notic('Success', '用户配置加载成功！', 'success', 4000);
      }
    }, 300);

    //5秒后执行oneCheck函数
    setTimeout(() => {
      this.oneCheck();
    }, 3000);
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
    oneCheck() {
      const unqualifiedCards = this.cardData.filter(card => card.isQualified === '2');
      if (unqualifiedCards.length > 0) {
        unqualifiedCards.forEach(card => {
          this.notic(
            '提醒',
            `${card.bank}的${card.alias || card.cardNumber}本年度年费未达标`,
            'warning', 0, true
          );
        });
      }
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
<style>
.main_body {
  width: 100vw;
  height: 100vh;
  background-color: #5672be;
  padding: 20px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  position: fixed;
  left: 0;
  top: 0;

  .headers {
    background-color: #fff;
    padding: 15px;
    border-radius: 5px;
    margin-bottom: 10px;
    flex-shrink: 0;

    .search-row {
      display: flex;
      flex-wrap: nowrap;
      justify-content: space-between;
      margin-bottom: 15px;

      &:last-child {
        margin-bottom: 0;
      }

      .el-form-item {
        flex: 1;
        margin-right: 15px;
        margin-bottom: 0;

        &:last-child {
          margin-right: 0;
        }
      }
    }

    :deep(.el-form-item__content) {
      width: 100%;
      display: flex;
    }

    :deep(.el-select),
    :deep(.el-input) {
      width: 100%;
    }
  }

  .button-container {
    background-color: #fff;
    padding: 10px;
    border-radius: 5px;
    margin-bottom: 10px;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 10px;
  }

  .table-container {
    flex: 1;
    overflow: hidden;
    background-color: #fff;
    border-radius: 5px;
    padding: 2px;

    :deep(.el-table) {
      height: 100%;
    }

    :deep(.el-table__header) {
      th {
        background-color: #f5f7fa;
      }
    }

    :deep(.el-table__body-wrapper) {
      overflow-y: auto;
    }
  }
}

/* 针对不同分辨率的布局调整 */
@media screen and (min-width: 3840px) {
  .main_body {
    padding: 30px;

    .headers {
      padding: 20px;
    }

    .button-container {
      padding: 15px;
    }
  }
}

@media screen and (max-width: 1920px) {
  .main_body {
    padding: 15px;

    .headers {
      padding: 12px;
    }

    .button-container {
      padding: 8px;
    }
  }
}

.dialog-footer {
  text-align: center;
}

:deep(.el-descriptions) {
  padding: 10px;

  .el-descriptions__header {
    margin-bottom: 15px;
  }

  .el-descriptions__label {
    width: 120px;
    font-weight: bold;
    color: #606266;
  }

  .el-descriptions__content {
    color: #333;
  }

  .el-tag {
    font-weight: normal;
  }
}

/* 表单验证样式 */
:deep(.el-form-item.is-error) {

  .el-input__wrapper,
  .el-textarea__wrapper {
    box-shadow: 0 0 0 1px #f56c6c;
  }
}

/* 对话框底部样式 */
.dialog-footer {
  border-top: 1px solid #ebeef5;
  padding: 15px 20px;
  text-align: right;
  margin: 0 -20px -20px;

  .el-button {
    padding: 9px 20px;
    font-size: 14px;
    border-radius: 4px;
    margin-left: 10px;

    &--default {
      border-color: #dcdfe6;

      &:hover {
        border-color: #c6e2ff;
        color: #5672be;
        background-color: #ecf5ff;
      }
    }

    &--primary {
      background-color: #5672be;
      border-color: #5672be;

      &:hover {
        background-color: #4a63a8;
        border-color: #4a63a8;
      }
    }
  }
}

/* 新增信用卡对话框样式 */
:deep(.el-dialog) {
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);

  .el-dialog__header {
    margin: 0;
    padding: 20px;
    border-bottom: 1px solid #ebeef5;

    .el-dialog__title {
      font-size: 18px;
      font-weight: 600;
      color: #303133;
    }
  }

  .el-dialog__body {
    padding: 20px;
  }
}

/* 描述列表样式 */
:deep(.el-descriptions) {
  padding: 0;
  margin-bottom: 10px;

  .el-descriptions__header {
    margin-bottom: 15px;
  }

  .el-descriptions__label {
    width: 120px;
    font-weight: bold;
    background-color: #f5f7fa;
    padding: 12px 15px;
  }

  .el-descriptions__content {
    padding: 8px 12px;

    .el-input,
    .el-select,
    .el-date-picker {
      width: 100%;
    }

    .el-input__wrapper,
    .el-select__wrapper {
      box-shadow: none;
      border: 1px solid #dcdfe6;
      border-radius: 4px;

      &:hover {
        border-color: #5672be;
      }

      &.is-focus {
        border-color: #5672be;
        box-shadow: 0 0 0 1px #5672be;
      }
    }

    .el-textarea__inner {
      min-height: 80px;
      resize: vertical;
      border: 1px solid #dcdfe6;
      border-radius: 4px;
      padding: 8px 12px;

      &:hover {
        border-color: #5672be;
      }

      &:focus {
        border-color: #5672be;
        box-shadow: 0 0 0 1px #5672be;
      }
    }

    .el-radio-group {
      display: flex;
      gap: 15px;
      padding: 4px 0;

      .el-radio {
        margin-right: 0;

        .el-radio__label {
          color: #606266;
        }
      }
    }
  }
}

/* 表格自定义框样式 */
:deep(.el-checkbox) {
  margin-bottom: 10px;
}

/* 查看详情弹窗样式 */
.card-details-dialog {
  :deep(.el-dialog__body) {
    padding: 0 20px 20px;
  }

  :deep(.el-tabs__header) {
    margin-bottom: 15px;
  }

  :deep(.el-tabs__item) {
    font-size: 14px;
    padding: 0 15px;
    height: 40px;
    line-height: 40px;
  }

  :deep(.el-descriptions) {
    padding: 0;
    margin-bottom: 10px;

    .el-descriptions__header {
      margin-bottom: 15px;
    }

    .el-descriptions__label {
      width: 120px;
      font-weight: bold;
      background-color: #f5f7fa;
    }

    .el-descriptions__content {
      color: #333;
      line-height: 1.6;
    }

    .el-tag {
      font-weight: normal;
    }
  }

  .details-content {
    padding: 8px;
    line-height: 1.6;
    white-space: pre-wrap;
    min-height: 60px;
  }
}

.dialog-footer {
  text-align: center;
  padding-top: 10px;
}
</style>
