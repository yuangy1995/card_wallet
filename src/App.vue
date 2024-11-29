<template>
  <div class="main_body">
    <div class="headers">
      <SearchForm
        v-model="formSearch"
        :options="creditCardData.options"
        :label-width="labelWidth"
      />
    </div>
    <div class="button-container">
      <el-button type="primary" @click="addCreditCard">
        <el-icon><Plus /></el-icon>新增信用卡
      </el-button>
      <el-button type="success" @click="exportData">
        <el-icon><Download /></el-icon>导出数据
      </el-button>
      <el-button type="warning" @click="importData">
        <el-icon><Upload /></el-icon>导入数据
      </el-button>
      <el-button @click="handleSort">
        <el-icon><Sort /></el-icon>排序
      </el-button>
    </div>

    <CreditCardTable
      :table-data="tableData"
      @edit="editCreditCard"
      @delete="deleteCreditCard"
      @card-number-visibility="handleCardNumberVisibility"
      @cvv-visibility="handleCvvVisibility"
    />

    <credit-card-dialog
      v-model:visible="creditCardData.dialogFormVisible"
      :mode="status"
      :initial-data="creditCardData.data"
      @submit="confirmAdd"
      @cancel="handleDialogCancel"
    />

    <sort-dialog
      v-model:visible="sortDialogVisible"
      v-model="sortValue"
      @confirm="handleSortConfirm"
    />

    <!-- 排序框 -->
    <el-dialog v-model="sortData.dialogFormVisible" title="选择排序方式" width="30%" draggable>
      <el-radio-group v-model="sortData.value">
        <el-radio v-for="item in sortData.options" :label="item" size="large">{{ item }}</el-radio>
      </el-radio-group>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="sortData.dialogFormVisible = false">取消</el-button>
          <el-button type="primary" @click="oneKeySortConfirm">
            确定
          </el-button>
        </span>
      </template>
    </el-dialog>
    <!-- 表格自定义框 -->
    <el-dialog v-model="tableCustom.dialogFormVisible" title="选择表格显示内容" width="30%" draggable>
      <el-checkbox v-for="(item, index) in creditCardData.options.tableCustomData" v-model="item.checked"
        :label="item.checked" :key="index" size="large">
        {{ item.label }}
      </el-checkbox>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="tableCustom.dialogFormVisible = false">取消</el-button>
          <el-button type="primary" @click="tableCustomConfirm">
            确定
          </el-button>
        </span>
      </template>
    </el-dialog>
    <!-- 查看详情弹窗 -->
    <el-dialog v-model="detailsVisible" title="信用卡详情" center width="800px" class="card-details-dialog">
      <el-tabs>
        <el-tab-pane label="总览">
          <el-descriptions :column="2" border>
            <!-- 基本信息 -->
            <el-descriptions-item label="国家">{{ currentCard.country }}</el-descriptions-item>
            <el-descriptions-item label="银行">{{ currentCard.bank }}</el-descriptions-item>
            <el-descriptions-item label="卡片别名">{{ currentCard.alias }}</el-descriptions-item>
            <el-descriptions-item label="等级">{{ currentCard.level }}</el-descriptions-item>
            <el-descriptions-item label="币种">{{ currentCard.type }}</el-descriptions-item>
            <el-descriptions-item label="额度">{{ currentCard.limit }}</el-descriptions-item>
            
            <!-- 卡片信息 -->
            <el-descriptions-item label="卡号">{{ currentCard.cardNumber }}</el-descriptions-item>
            <el-descriptions-item label="有效期">{{ currentCard.valid }}</el-descriptions-item>
            <el-descriptions-item label="CVV码">{{ currentCard.cvv }}</el-descriptions-item>
            <el-descriptions-item label="账单日">{{ currentCard.accountBillDate }}</el-descriptions-item>
            <el-descriptions-item label="还款日">{{ currentCard.dueDate }}</el-descriptions-item>
            <el-descriptions-item label="年费">{{ currentCard.annualFee }}</el-descriptions-item>

            <!-- 年费信息 -->
            <el-descriptions-item label="年费达标状态" :span="2">
              <el-tag v-if="currentCard.isQualified === '1'" type="success">已达标</el-tag>
              <el-tag v-if="currentCard.isQualified === '2'" type="danger">未达标</el-tag>
              <el-tag v-if="currentCard.isQualified === '3'" type="info">终免年费</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="下次年费收取时间" :span="2">{{ currentCard.nextAnnualFeeCollectionTime }}</el-descriptions-item>
            <el-descriptions-item label="上次提额日期" :span="2">{{ currentCard.lastTime }}</el-descriptions-item>

            <!-- 其他信息 -->
            <el-descriptions-item label="权益" :span="2">
              <div class="details-content">{{ currentCard.equity || '暂无权益信息' }}</div>
            </el-descriptions-item>
            <el-descriptions-item label="备注" :span="2">
              <div class="details-content">{{ currentCard.remark || '暂无备注信息' }}</div>
            </el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>

        <el-tab-pane label="基本信息">
          <el-descriptions :column="2" border>
            <el-descriptions-item label="国家">{{ currentCard.country }}</el-descriptions-item>
            <el-descriptions-item label="银行">{{ currentCard.bank }}</el-descriptions-item>
            <el-descriptions-item label="卡片别名">{{ currentCard.alias }}</el-descriptions-item>
            <el-descriptions-item label="等级">{{ currentCard.level }}</el-descriptions-item>
            <el-descriptions-item label="币种">{{ currentCard.type }}</el-descriptions-item>
            <el-descriptions-item label="额度">{{ currentCard.limit }}</el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>
        
        <el-tab-pane label="卡片信息">
          <el-descriptions :column="2" border>
            <el-descriptions-item label="卡号">{{ currentCard.cardNumber }}</el-descriptions-item>
            <el-descriptions-item label="有效期">{{ currentCard.valid }}</el-descriptions-item>
            <el-descriptions-item label="CVV码">{{ currentCard.cvv }}</el-descriptions-item>
            <el-descriptions-item label="账单日">{{ currentCard.accountBillDate }}</el-descriptions-item>
            <el-descriptions-item label="还款日">{{ currentCard.dueDate }}</el-descriptions-item>
            <el-descriptions-item label="年费">{{ currentCard.annualFee }}</el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>

        <el-tab-pane label="年费信息">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="年费达标状态">
              <el-tag v-if="currentCard.isQualified === '1'" type="success">已达标</el-tag>
              <el-tag v-if="currentCard.isQualified === '2'" type="danger">未达标</el-tag>
              <el-tag v-if="currentCard.isQualified === '3'" type="info">终免年费</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="下次年费收取时间">{{ currentCard.nextAnnualFeeCollectionTime }}</el-descriptions-item>
            <el-descriptions-item label="上次提额日期">{{ currentCard.lastTime }}</el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>

        <el-tab-pane label="其他信息">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="权益">
              <div class="details-content">{{ currentCard.equity || '暂无权益信息' }}</div>
            </el-descriptions-item>
            <el-descriptions-item label="备注">
              <div class="details-content">{{ currentCard.remark || '暂无备注信息' }}</div>
            </el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>
      </el-tabs>

      <template #footer>
        <div class="dialog-footer">
          <el-button @click="detailsVisible = false">关闭</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script>
import { creditCardOptions } from '@/config/creditCardOptions'
import { ElNotification } from 'element-plus'
import SecureField from './components/common/SecureField.vue'
import SearchForm from './components/search/SearchForm.vue'
import CreditCardTable from './components/table/CreditCardTable.vue'
import CreditCardDialog from './components/dialog/CreditCardDialog.vue'
import SortDialog from './components/dialog/SortDialog.vue'
import { Plus, Download, Upload, Sort } from '@element-plus/icons-vue'

export default {
  components: {
    Plus,
    Download,
    Upload,
    Sort,
    SearchForm,
    CreditCardTable,
    CreditCardDialog,
    SortDialog,
  },
  data() {
    return {
      cardData: [],
      labelWidth: '80px',
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
        isQualified:"",
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
      detailsVisible: false,
      currentCard: {},
      cvvVisibility: {}, // CVV显示控制
      cvvTimer: null, // CVV显示定时器
      cardNumberVisibility: {}, // 卡号显示控制
      cardNumberTimer: null, // 卡号显示定时器
      sortDialogVisible: false,
      sortValue: '1',
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
    //通知程序
    notic(title, message, type, duration, html) {
      ElNotification({
        title: title,
        message: message,
        dangerouslyUseHTMLString: html ? html : false,
        duration: duration ? duration : 2500,
        type: type,
      })
    },
    //清空所有数据
    deleteAllData() {
      this.cardData = [];
      //清除localStorage的存储数据
      localStorage.removeItem("cardData");
      localStorage.removeItem("tableCustom");
      this.notic('Success', '数据已全部清空！', 'success');
    },
    //添加卡片
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
    //编辑卡片
    editCreditCard(row) {
      this.status = 'edit';
      this.creditCardData.dialogFormVisible = true;
      this.creditCardData.data = Object.assign({}, row);
    },
    confirmAdd(data) {
      if (this.status == 'add') {
        this.notic('添加成功', '该卡片已被添加！', 'success');
        this.creditCardData.dialogFormVisible = false;
        this.cardData.push(Object.assign({}, data));
      } else if (this.status == 'edit') {
        this.cardData.splice(this.cardData.findIndex(item => item.id == data.id), 1, Object.assign({}, data));
        this.notic('修改成功', '该卡片已被修改！', 'success');
        this.creditCardData.dialogFormVisible = false;
      }
    },
    deleteData(index, row) {
      this.cardData.splice(this.cardData.findIndex(item => item.id == row.id), 1);
      this.notic('删除成功', '该卡片已被删除！', 'success');
    },
    //导出数据
    exportData() {
      let val = Object.assign([], this.cardData);
      val = JSON.stringify(val);
      const blob = new Blob([val], { type: 'text/plain;charset=utf-8' });
      saveAs(blob, '信用卡管理数据.json');
      this.notic('Success', '数据导出成功！', 'success');
    },
    importData2() {
      //模拟点击input
      document.getElementById('importFile').click();
    },
    //导入数据
    importData() {
      let file = document.getElementById('importFile').files[0];
      let reader = new FileReader();
      reader.readAsText(file);
      reader.onload = (e) => {
        let val = JSON.parse(e.target.result);
        //根据creditCardData.data里面的key，对比val里面的key，如果creditCardData.data里面的key在val里面没有，就在val里面添加这个key，并且赋值为空
        for (let key in this.creditCardData.data) {
          if (!val[0].hasOwnProperty(key)) {
            val.forEach(item => {
              item[key] = '';
            })
          }
        }
        //判断导入的数据是否符合要求
        if (val instanceof Array) {
          this.cardData = val;
          this.notic('Success', '数据导入成功！', 'success');
        } else {
          this.notic('Error', '数据不符合要求，导入失败！', 'error');
        }
      }
    },
    //时间戳处理函数，有两个参数，第一个是时间戳，第二个是要返回的时间格式，有所有格式组合
    timestampToTime(timestamp, format) {
      let date = new Date(timestamp);
      let Y = date.getFullYear();
      let M = (date.getMonth() + 1 < 10 ? '0' + (date.getMonth() + 1) : date.getMonth() + 1);
      let D = date.getDate() + ' ';
      let h = date.getHours();
      let m = date.getMinutes();
      let s = date.getSeconds();
      if (format == 'Y-M-D h:m:s') {
        return Y + '-' + M + '-' + D + ' ' + h + ':' + m + ':' + s;
      } else if (format == 'Y-M-D') {
        return Y + '-' + M + '-' + D;
      } else if (format == 'h:m:s') {
        return h + ':' + m + ':' + s;
      } else if (format == 'Y-M') {
        return Y + '-' + M;
      } else if (format == 'M-D') {
        return M + '-' + D;
      } else if (format == 'h:m') {
        return h + ':' + m;
      } else if (format == 'm:s') {
        return m + ':' + s;
      } else if (format == 'Y') {
        return Y;
      } else if (format == 'M') {
        return M;
      } else if (format == 'D') {
        return D;
      } else if (format == 'h') {
        return h;
      } else if (format == 'm') {
        return m;
      } else if (format == 's') {
        return s;
      }
    },
    //计算两个日期之间相差的天数
    getDays(dateString1, dateString2) {
      var startDate = Date.parse(dateString1);
      var endDate = Date.parse(dateString2);
      var days = (endDate - startDate) / (1 * 24 * 60 * 60 * 1000);
      //将天数向上取整
      days = Math.ceil(days);
      return days;
    },
    //一键排序，点击按钮后，弹出一个对话框
    oneKeySort() {
      this.sortData.dialogFormVisible = true;
    },
    //一键排序确认
    oneKeySortConfirm() {
      //根据sortData.value的值来判断按照哪个字段排序
      if (this.sortData.value == '国家') {
        this.cardData.sort((a, b) => {
          return a.country.localeCompare(b.country);
        })
      } else if (this.sortData.value == '银行') {
        this.cardData.sort((a, b) => {
          return a.bank.localeCompare(b.bank);
        })
      } else if (this.sortData.value == '等级') {
        this.cardData.sort((a, b) => {
          return a.level.localeCompare(b.level);
        })
      } else if (this.sortData.value == '币种') {
        this.cardData.sort((a, b) => {
          return a.type.localeCompare(b.type);
        })
      } else if (this.sortData.value == '本年度年费是否达标') {
        this.cardData.sort((a, b) => {
          return a.isQualified - b.isQualified;
        })
      }
      this.sortData.dialogFormVisible = false;
    },
    //根据本年度年费是否达标，不达标的每张卡弹出提示
    oneCheck() {
      let notQualified = this.cardData.filter(item => item.isQualified == '2');
      let str = '';
      notQualified.forEach(item => {
        str += item.alias + '、';
      })
      str = str.slice(0, str.length - 1);
      if (str.length > 0) {
        this.notic('本年度年费未达标', str + '的年费未达标，请及时处理！', 'warning', 9999999999);
      } else {
        this.notic('本年度年费未达标', '本年度卡片年费已经全部达标！', 'success', 9999999999);
      }
      //3秒后执行twoCheck函数
      setTimeout(() => {
        this.twoCheck();
      }, 1000);
    },
    //根据填写的下次年费收取时间，跟当前的时间进行比对，如果时间差小于等于60天，则弹出提示
    twoCheck() {
      let nowTime = new Date().getTime();
      let nextAnnualFeeCollectionTime = this.cardData.filter(item => {
        let time = new Date(item.nextAnnualFeeCollectionTime).getTime();
        let days = this.getDays(nowTime, time);
        if (days <= 60) {
          return true;
        }
      });
      let str = '';
      nextAnnualFeeCollectionTime.forEach(item => {
        str += item.alias + '、';
      })
      str = str.slice(0, str.length - 1);
      if (str.length > 0) {
        this.notic('下次年费收取时间', str + '的下次年费收取时间距离现在不足60天，请及时处理！', 'warning', 9999999999);
      } else {
        this.notic('下次年费收取时间', '暂无不到60天内即将收取年费的卡片！', 'success', 5000);
      }
    },
    //表格自定义
    tableCustoms() {
      this.tableCustom.dialogFormVisible = true;
    },
    //表格自定义确认
    tableCustomConfirm() {
      //遍历tableCustomData，生成userData.tableCustom的数据格式为{country: true, ...}
      this.creditCardData.options.tableCustomData.forEach(item => {
        this.userData.tableCustom[item.value] = item.checked;
      })
      this.tableCustom.dialogFormVisible = false;
    },
    //信用卡统计
    creditCardStatistics() {
      //展示所有卡片数量，国家类型有几个，各个级别的卡片有多少张，各个币种的卡片有多少张，有多少种银行类别
      let allCardNumber = this.cardData.length;
      let countryType = [];
      let levelType = [];
      let currencyType = [];
      let bankType = [];
      this.cardData.forEach(item => {
        if (countryType.indexOf(item.country) == -1) {
          countryType.push(item.country);
        }
        if (levelType.indexOf(item.level) == -1) {
          levelType.push(item.level);
        }
        if (currencyType.indexOf(item.type) == -1) {
          currencyType.push(item.type);
        }
        if (bankType.indexOf(item.bank) == -1) {
          bankType.push(item.bank);
        }
      })
      //统计人民币总额度，每个银行的人民币额度只计算一次
      let totalLimitCNY = 0;
      let bankList = [];
      this.cardData.forEach(item => {
        if (item.type == '人民币(CNY)' && bankList.indexOf(item.bank) == -1) {
          totalLimitCNY += item.limit ? Number(item.limit) : 0;
          bankList.push(item.bank);
        }
      })
      //对统计结果进行展示，每个类型换行展示
      this.notic('信用卡统计',
        `所有卡片数量：${allCardNumber}张<br/>
        国家类型有：${countryType.length}种<br/>
          卡等级有：${levelType.length}种<br/>
            币种有：${currencyType.length}种<br/>
        银行类别有：${bankType.length}种<br/>
        人民币总额度：${totalLimitCNY}元<br/>`,
        'success',
        9999999999,
        true);
    },
    //账单日补全
    accountBillDateCompletion(_accountBillDate, dateType) {
      let date = new Date();
      let y = date.getFullYear();
      let m = (date.getMonth() + 1 < 10 ? '0' + (date.getMonth() + 1) : date.getMonth() + 1);
      // return `${y}-${m}-${_accountBillDate}`;
      if (date.getDate() < _accountBillDate) {
        if (dateType == "now") {
          return `${y}-${m}-${_accountBillDate}`;//本期账单日
        } else {
          return `${y}-${(Number(m) + 1) < 10 ? '0' + (Number(m) + 1) : (Number(m) + 1)}-${_accountBillDate}`;//下期账单日
        }
      } else {
        let date = new Date();
        let y = date.getFullYear();
        let m = (date.getMonth() + 2 < 10 ? '0' + (date.getMonth() + 2) : date.getMonth() + 2);
        if (dateType == "now") {
          return `${y}-${m}-${_accountBillDate}`;//本期账单日
        } else {
          return `${y}-${(Number(m) + 1) < 10 ? '0' + (Number(m) + 1) : (Number(m) + 1)}-${_accountBillDate}`;//下期账单日
        }
      }
    },
    //还款日补全
    dueDateCompletion(_accountBillDate, _dueDate, dateType) {
      if (!_accountBillDate || !_dueDate) {
        return '';
      } else {
        let date = new Date();
        let y = date.getFullYear();
        let m = (date.getMonth() + 1 < 10 ? '0' + (date.getMonth() + 1) : date.getMonth() + 1);
        let dueDate = "";
        //本期免息期计算公式：通常情况下，信用卡的本期免息期是从今天开始计算，1.如果今天是账单日或者没有过这个月的账单日，那么本期免息期是从今天到这期账单的还款日，2.如果今天过了这个月的账单日，那么本期免息期是从今天到下期账单的还款日
        if (date.getDate() < _accountBillDate) {
          if (_accountBillDate > _dueDate) {
            dueDate = `${y}-${Number(m) + 1}-${_dueDate}`;
          } else {
            dueDate = `${y}-${m}-${_dueDate}`;
          }
          //用dueDate和accountBillDate计算本期免息期
          let days = this.getDays(accountBillDate, dueDate);
          return days;
        } else {
          let date = new Date();
          let y = date.getFullYear();
          let m = (date.getMonth() + 2 < 10 ? '0' + (date.getMonth() + 2) : date.getMonth() + 2);
          if (_accountBillDate > _dueDate) {
            dueDate = `${y}-${Number(m) + 1}-${_dueDate}`;
          } else {
            dueDate = `${y}-${m}-${_dueDate}`;
          }
          //用dueDate和accountBillDate计算本期免息期
          let days = this.getDays(accountBillDate, dueDate);
          return days;
        }
      }
    },
    //本期免息期计算
    interestFreePeriodCalculation(_accountBillDate, _dueDate) {
      //如果两个参数任意一个为空，就返回空，否则就计算本期免息期
      if (!_accountBillDate || !_dueDate) {
        return '';
      } else {
        let date = new Date();
        let y = date.getFullYear();
        let m = (date.getMonth() + 1 < 10 ? '0' + (date.getMonth() + 1) : date.getMonth() + 1);
        let accountBillDate = `${y}-${m}-${date.getDate()}`;
        let dueDate = "";
        //本期免息期计算公式：通常情况下，信用卡的本期免息期是从今天开始计算，1.如果今天是账单日或者没有过这个月的账单日，那么本期免息期是从今天到这期账单的还款日，2.如果今天过了这个月的账单日，那么本期免息期是从今天到下期账单的还款日
        if (date.getDate() < _accountBillDate) {
          if (_accountBillDate > _dueDate) {
            dueDate = `${y}-${Number(m) + 1}-${_dueDate}`;
          } else {
            dueDate = `${y}-${m}-${_dueDate}`;
          }
          //用dueDate和accountBillDate计算本期免息期
          let days = this.getDays(accountBillDate, dueDate);
          return days;
        } else {
          let date = new Date();
          let y = date.getFullYear();
          let m = (date.getMonth() + 2 < 10 ? '0' + (date.getMonth() + 2) : date.getMonth() + 2);
          if (_accountBillDate > _dueDate) {
            dueDate = `${y}-${Number(m) + 1}-${_dueDate}`;
          } else {
            dueDate = `${y}-${m}-${_dueDate}`;
          }
          //用dueDate和accountBillDate计算本期免息期
          let days = this.getDays(accountBillDate, dueDate);
          return days;
        }
      }
    },
    //上期账单还款剩余日计算
    preDueDateDayCalculation(_accountBillDate, _dueDate) {
      //如果两个参数任意一个为空，就返回空，否则就计算上期账单还款剩余日
      let preDueDateDay = this.dueDateCompletion(_accountBillDate, _dueDate, 'now');
      let date = this.timestampToTime(new Date(), 'Y-M-D');
      let days = this.getDays(date, preDueDateDay);
      if (days > 0) {
        return days + "天";
      } else if (days == 0) {
        return '今天到期！';
      } else if (days < 0) {
        return "已过最后还款期限，请注意是否逾期！";
      }
    },
    //查看详情
    viewDetails(row) {
      this.currentCard = { ...row };
      this.detailsVisible = true;
    },
    //处理卡号显示状态变化
    handleCardNumberVisibility({ id, isVisible }) {
      this.cardNumberVisibility[id] = isVisible;
    },
    
    // 处理CVV显示状态变化
    handleCvvVisibility({ id, isVisible }) {
      this.cvvVisibility[id] = isVisible;
    },
    handleDialogCancel() {
      this.creditCardData.dialogFormVisible = false;
    },
    handleSort() {
      this.sortDialogVisible = true;
    },
    handleSortConfirm(value) {
      const sortFunctions = {
        '1': (a, b) => a.creditLimit - b.creditLimit,
        '2': (a, b) => b.creditLimit - a.creditLimit,
        '3': (a, b) => a.annualFee - b.annualFee,
        '4': (a, b) => b.annualFee - a.annualFee,
        '5': (a, b) => a.billDay - b.billDay,
        '6': (a, b) => b.billDay - a.billDay,
        '7': (a, b) => a.repaymentDay - b.repaymentDay,
        '8': (a, b) => b.repaymentDay - a.repaymentDay
      }
      this.cardData.sort(sortFunctions[value])
    }
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
