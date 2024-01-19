<template>
  <div class="main_body">
    <div class="headers">
      <el-form :inline="true" :model="formSearch" label-width="80px">
        <el-row>
          <el-form-item label="国家">
            <el-select v-model="formSearch.country" placeholder="请选择国家" filterable allow-create clearable>
              <el-option v-for="(item, index) in creditCardData.options.countryData" :key="index"
                :label="`${item.chineseName}(${item.name})`" :value="item.chineseName" />
            </el-select>
          </el-form-item>
          <el-form-item label="银行">
            <el-select v-model="formSearch.bank" placeholder="请选择银行" filterable allow-create clearable>
              <el-option v-for="item in creditCardData.options.bankList" :key="item.name" :label="item.name"
                :value="item.chineseName" />
            </el-select>
          </el-form-item>
          <el-form-item label="卡号">
            <el-input v-model="formSearch.cardNumber" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="等级">
            <el-select v-model="formSearch.level" placeholder="请选择等级" filterable clearable>
              <el-option v-for="item in creditCardData.options.cardLevel" :key="item.name" :label="item.name"
                :value="item.chineseName" />
            </el-select>
          </el-form-item>
          <el-form-item label="额度">
            <el-input v-model="formSearch.limit" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="年费达标">
            <el-select v-model="formSearch.isQualified" placeholder="请选择" filterable clearable>
              <el-option v-for="item in creditCardData.options.isQualified" :key="item.name" :label="item.name"
                :value="item.value" />
            </el-select>
          </el-form-item>
        </el-row>
        <el-row>
          <el-form-item label="币种">
            <el-select v-model="formSearch.type" placeholder="请选择币种" filterable clearable>
              <el-option v-for="item in creditCardData.options.currencyList" :key="item.name" :label="item.name"
                :value="item.chineseName" />
            </el-select>
          </el-form-item>
          <el-form-item label="cvv码">
            <el-input v-model="formSearch.cvv" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="卡片别名">
            <el-input v-model="formSearch.alias" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="权益">
            <el-input v-model="formSearch.equity" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="备注">
            <el-input v-model="formSearch.remark" autocomplete="off" clearable />
          </el-form-item>
        </el-row>
      </el-form>
    </div>
    <div class="buttons">
      <el-button type="primary" @click="addCreditCard">新增信用卡</el-button>
      <el-button type="primary" @click="oneKeySort">一键排序</el-button>
      <el-button type="primary" @click="oneCheck">一键检测年费达标情况</el-button>
      <el-button type="primary" @click="tableCustoms">表格自定义</el-button>
      <el-button type="primary" @click="creditCardStatistics">信用卡数据统计</el-button>
      <el-button type="primary" @click="exportData">导出数据</el-button>
      <el-button type="primary" @click="importData2">导入数据</el-button>
      <input v-show="false" type="file" name="upfile" id="importFile" accept=".json" style="width: 0px;"
        @change="importData" />

      <el-popconfirm title="你确定要清除所有数据?" @confirm="deleteAllData">
        <template #reference>
          <el-button size="small" type="danger" style="margin-left: 20px;">清除所有数据</el-button>
        </template>
      </el-popconfirm>

    </div>
    <el-scrollbar height="1000px">
      <el-table :data="tableData" border height="1000px" style="width: 100%">
        <el-table-column type="index" label="序号" width="60" align="center" fixed />
        <el-table-column v-if="userData.tableCustom.country" prop="country" label="国家" width="130" align="center" fixed/>
        <el-table-column v-if="userData.tableCustom.bank" prop="bank" label="银行" width="150" align="center" fixed />
        <el-table-column v-if="userData.tableCustom.alias" prop="alias" label="卡片别名" width="200" align="center" fixed/>
        <el-table-column v-if="userData.tableCustom.level" prop="level" label="等级" width="110" align="center" />
        <el-table-column v-if="userData.tableCustom.type" prop="type" label="币种" width="150" align="center" />
        <el-table-column v-if="userData.tableCustom.annualFee" prop="annualFee" label="年费" width="90" align="center" />
        <el-table-column v-if="userData.tableCustom.cardNumber" prop="cardNumber" label="卡号" width="180" align="center" fixed/>
        <el-table-column v-if="userData.tableCustom.valid" prop="valid" label="有效期" width="80" align="center" />
        <el-table-column v-if="userData.tableCustom.cvv" prop="cvv" label="cvv码" width="70" align="center" />
        <el-table-column v-if="userData.tableCustom.limit" prop="limit" label="额度" width="100" align="center" />
        <el-table-column v-if="userData.tableCustom.isQualified" prop="isQualified" label="本年度年费是否达标" width="160"
          align="center">
          <template #default="scope">
            <el-tag v-if="scope.row.isQualified === '1'" type="success">已达标</el-tag>
            <el-tag v-if="scope.row.isQualified === '2'" type="danger">未达标</el-tag>
            <el-tag v-if="scope.row.isQualified === '3'" type="info">终免年费</el-tag>
          </template>
        </el-table-column>
        <el-table-column v-if="userData.tableCustom.nextAnnualFeeCollectionTime" prop="nextAnnualFeeCollectionTime"
          label="下次年费收取时间" width="150" align="center" />
        <el-table-column v-if="userData.tableCustom.lastTime" prop="lastTime" label="上次提额日期" width="170" align="center" />
        <el-table-column v-if="userData.tableCustom.lastDays" prop="lastTime" label="距离上次提额多少天" width="170"
          align="center">
          <template #default="scope">
            <span v-if="scope.row.lastTime">
              {{ getDays(scope.row.lastTime, new Date()) + '天' }}
            </span>
          </template>
        </el-table-column>
        <el-table-column v-if="userData.tableCustom.nowDueDate" prop="dueDate" label="上期还款日" width="110" align="center">
          <!-- 补全上期还款日 -->
          <template #default="scope">
            <span v-if="scope.row.accountBillDate && scope.row.dueDate">
              {{ dueDateCompletion(scope.row.accountBillDate, scope.row.dueDate, 'now') }}
            </span>
            <span v-if="!scope.row.accountBillDate && scope.row.dueDate">
              {{ scope.row.dueDate }}
            </span>
          </template>
        </el-table-column>
        <el-table-column v-if="userData.tableCustom.preDueDateDay" prop="limit" label="上期账单还款剩余天数" width="200"
          align="center">
          <!-- 根据上期账单还款日期和上期还款日计算上期账单还款剩余天数 -->
          <template #default="scope">
            <span v-if="scope.row.dueDate">
              {{ preDueDateDayCalculation(scope.row.accountBillDate, scope.row.dueDate) }}
            </span>
            <span v-else></span>
          </template>
        </el-table-column>
        <el-table-column v-if="userData.tableCustom.nowAccountBillDate" prop="accountBillDate" label="本期账单日" width="110"
          align="center">
          <!-- 补全本期账单日 -->
          <template #default="scope">
            <span v-if="scope.row.accountBillDate">
              {{ accountBillDateCompletion(scope.row.accountBillDate, 'now') }}
            </span>
            <span v-else></span>
          </template>
        </el-table-column>
        <el-table-column v-if="userData.tableCustom.nextDueDate" prop="dueDate" label="本期还款日" width="110" align="center">
          <!-- 补全本期还款日 -->
          <template #default="scope">
            <span v-if="scope.row.accountBillDate && scope.row.dueDate">
              {{ dueDateCompletion(scope.row.accountBillDate, scope.row.dueDate) }}
            </span>
            <span v-if="!scope.row.accountBillDate && scope.row.dueDate">
              {{ scope.row.dueDate }}
            </span>
          </template>
        </el-table-column>
        <el-table-column v-if="userData.tableCustom.interestFreePeriod" prop="dueDate" label="本期免息期" width="110"
          align="center">
          <!-- 根据账单日和还款日计算本期免息期 -->
          <template #default="scope">
            <span v-if="scope.row.accountBillDate && scope.row.dueDate">
              {{ interestFreePeriodCalculation(scope.row.accountBillDate, scope.row.dueDate) + '天' }}
            </span>
            <span v-else></span>
          </template>
        </el-table-column>
        <el-table-column v-if="userData.tableCustom.nextAccountBillDate" prop="accountBillDate" label="下期账单日" width="110"
          align="center">
          <!-- 补全下期账单日 -->
          <template #default="scope">
            <span v-if="scope.row.accountBillDate">
              {{ accountBillDateCompletion(scope.row.accountBillDate) }}
            </span>
            <span v-else></span>
          </template>
        </el-table-column>
        <el-table-column v-if="userData.tableCustom.equity" prop="equity" label="权益" width="350" align="center"
          show-overflow-tooltip />
        <el-table-column v-if="userData.tableCustom.remark" prop="remark" label="备注" width="350" align="center"
          show-overflow-tooltip />
        <el-table-column label="操作" width="150" align="center" fixed="right">
          <template #default="scope">
            <el-button size="small" @click="cardEdit(scope.$index, scope.row)">编辑</el-button>
            <el-popconfirm title="你确定要删除?" @confirm="deleteData(scope.$index, scope.row)">
              <template #reference>
                <el-button size="small" type="danger">删除</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-scrollbar>

    <!-- 添加信用卡 -->
    <el-dialog v-model="creditCardData.dialogFormVisible" title="新增信用卡" center width="600px">
      <el-scrollbar height="700px">
        <el-form :model="creditCardData.data">
          <el-form-item label="国家">
            <el-select v-model="creditCardData.data.country" placeholder="请选择国家" filterable allow-create>
              <el-option v-for="(item, index) in creditCardData.options.countryData" :key="index"
                :label="`${item.chineseName}(${item.name})`" :value="item.chineseName" />
            </el-select>
          </el-form-item>
          <el-form-item label="银行">
            <el-select v-model="creditCardData.data.bank" placeholder="请选择银行" filterable allow-create>
              <el-option v-for="item in creditCardData.options.bankList" :key="item.name" :label="item.name"
                :value="item.chineseName" />
            </el-select>
          </el-form-item>
          <el-form-item label="卡号">
            <el-input v-model="creditCardData.data.cardNumber" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="等级">
            <el-select v-model="creditCardData.data.level" placeholder="请选择等级" filterable>
              <el-option v-for="item in creditCardData.options.cardLevel" :key="item.name" :label="item.name"
                :value="item.chineseName" />
            </el-select>
          </el-form-item>
          <el-form-item label="卡片别名">
            <el-input v-model="creditCardData.data.alias" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="额度">
            <el-input type="number" v-model="creditCardData.data.limit" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="币种">
            <el-select v-model="creditCardData.data.type" placeholder="请选择币种" filterable>
              <el-option v-for="item in creditCardData.options.currencyList" :key="item.name" :label="item.name"
                :value="item.chineseName" />
            </el-select>
          </el-form-item>
          <el-form-item label="cvv码">
            <el-input v-model="creditCardData.data.cvv" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="有效期">
            <el-date-picker v-model="creditCardData.data.valid" type="month" placeholder="选择卡片到期时间"
              value-format="YYYY-MM" />
          </el-form-item>
          <el-form-item label="年费">
            <el-input type="number" v-model="creditCardData.data.annualFee" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="账单日">
            <el-input type="number" v-model="creditCardData.data.accountBillDate" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="还款日">
            <el-input type="number" v-model="creditCardData.data.dueDate" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="本年度消费是否达标">
            <el-radio-group v-model="creditCardData.data.isQualified">
              <el-radio :label="'2'" size="large">未达标</el-radio>
              <el-radio :label="'1'" size="large">已达标</el-radio>
              <el-radio :label="'3'" size="large">终免年费</el-radio>
            </el-radio-group>
          </el-form-item>
          <el-form-item label="下次年费收取时间">
            <el-date-picker v-model="creditCardData.data.nextAnnualFeeCollectionTime" type="date" placeholder="选择下次年费收取时间"
              format="YYYY-MM-DD" value-format="YYYY-MM-DD" />
          </el-form-item>
          <el-form-item label="上次提额日期">
            <el-date-picker v-model="creditCardData.data.lastTime" type="date" placeholder="选择上次提额日期" format="YYYY-MM-DD"
              value-format="YYYY-MM-DD" />
          </el-form-item>
          <el-form-item label="备注">
            <el-input v-model="creditCardData.data.remark" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="权益">
            <!-- <el-tree-select v-model="creditCardData.data.equity" :data="creditCardData.options.cardType" multiple
              :render-after-expand="false" show-checkbox filterable /> -->
            <el-input v-model="creditCardData.data.equity" autocomplete="off" clearable :rows="3" type="textarea"
              show-word-limit />
          </el-form-item>
        </el-form>
      </el-scrollbar>

      <template #footer>
        <span class="dialog-footer">
          <el-button @click="creditCardData.dialogFormVisible = false">取消</el-button>
          <el-button type="primary" @click="confirmAdd(this.creditCardData.data)">确认</el-button>
        </span>
      </template>
    </el-dialog>
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
  </div>
</template>

<script>
import { ElNotification } from 'element-plus';

export default {
  data() {
    return {
      cardData: [],
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
          lastDays: true,
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
        valid: "",
        alias: "",
        annualFee: "",
        nextAnnualFeeCollectionTime: "",
        lastTime: "",
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
          isQualified: false,//本年度年费是否达标
          nextAnnualFeeCollectionTime: "",//下次年费收取时间
          lastTime: "",//距离上次提额多少天了
          equity: "",//权益
          remark: "",//备注
        },
        options: {
          //列出世界上绝大部分国家的中文和英文名字
          countryData: [
            { name: "China", chineseName: "中国" },
            { name: "Hong Kong", chineseName: "香港特别行政区" },
            { name: "Macau", chineseName: "澳门特别行政区" },
            { name: "Taiwan of China", chineseName: "台湾" },
            { name: "United States of America", chineseName: "美国" },
            { name: "United Kingdom of Great Britain and Northern Ireland", chineseName: "英国" },
            { name: "Singapore", chineseName: "新加坡" },
            { name: "Germany", chineseName: "德国" },
            { name: "Afghanistan", chineseName: "阿富汗" },
            { name: "Åland Islands", chineseName: "奥兰" },
            { name: "Albania", chineseName: "阿尔巴尼亚" },
            { name: "Algeria", chineseName: "阿尔及利亚" },
            { name: "American Samoa", chineseName: "美属萨摩亚" },
            { name: "Andorra", chineseName: "安道尔" },
            { name: "Angola", chineseName: "安哥拉" },
            { name: "Anguilla", chineseName: "安圭拉" },
            { name: "Antarctica", chineseName: "南极洲" },
            { name: "Antigua and Barbuda", chineseName: "安提瓜和巴布达" },
            { name: "Argentina", chineseName: "阿根廷" },
            { name: "Armenia", chineseName: "亚美尼亚" },
            { name: "Aruba", chineseName: "阿鲁巴" },
            { name: "Australia", chineseName: "澳大利亚" },
            { name: "Austria", chineseName: "奥地利" },
            { name: "Azerbaijan", chineseName: "阿塞拜疆" },
            { name: "The Bahamas", chineseName: "巴哈马" },
            { name: "Bahrain", chineseName: "巴林" },
            { name: "Bangladesh", chineseName: "孟加拉国" },
            { name: "Barbados", chineseName: "巴巴多斯" },
            { name: "Belarus", chineseName: "白俄罗斯" },
            { name: "Belgium", chineseName: "比利时" },
            { name: "Belize", chineseName: "伯利兹" },
            { name: "Benin", chineseName: "贝宁" },
            { name: "Bermuda", chineseName: "百慕大" },
            { name: "Bhutan", chineseName: "不丹" },
            { name: "Bolivia", chineseName: "玻利维亚" },
            { name: "Bonaire, Sint Eustatius and Saba", chineseName: "荷兰加勒比区" },
            { name: "Bosnia and Herzegovina", chineseName: "波黑" },
            { name: "Botswana", chineseName: "博茨瓦纳" },
            { name: "Bouvet Island", chineseName: "布韦岛" },
            { name: "Brazil", chineseName: "巴西" },
            { name: "British Indian Ocean Territory", chineseName: "英属印度洋领地" },
            { name: "British Virgin Islands", chineseName: "英属维尔京群岛" },
            { name: "Brunei", chineseName: "文莱" },
            { name: "Bulgaria", chineseName: "保加利亚" },
            { name: "Burkina Faso", chineseName: "布基纳法索" },
            { name: "Burundi", chineseName: "布隆迪" },
            { name: "Cambodia", chineseName: "柬埔寨" },
            { name: "Cameroon", chineseName: "喀麦隆" },
            { name: "Canada", chineseName: "加拿大" },
            { name: "Cape Verde", chineseName: "佛得角" },
            { name: "Cayman Islands", chineseName: "开曼群岛" },
            { name: "Central African Republic", chineseName: "中非" },
            { name: "Chad", chineseName: "乍得" },
            { name: "Chile", chineseName: "智利" },
            { name: "Christmas Island", chineseName: "圣诞岛" },
            { name: "Cocos (Keeling) Islands", chineseName: "科科斯（基林）群岛" },
            { name: "Colombia", chineseName: "哥伦比亚" },
            { name: "Comoros", chineseName: "科摩罗" },
            { name: "Democratic Republic of the Congo", chineseName: "刚果民主共和国" },
            { name: "Republic of the Congo", chineseName: "刚果共和国" },
            { name: "Cook Islands", chineseName: "库克群岛" },
            { name: "Costa Rica", chineseName: "哥斯达黎加" },
            { name: "Côte d'Ivoire", chineseName: "科特迪瓦" },
            { name: "Croatia", chineseName: "克罗地亚" },
            { name: "Cuba", chineseName: "古巴" },
            { name: "Curaçao", chineseName: "库拉索" },
            { name: "Cyprus", chineseName: "塞浦路斯" },
            { name: "Czech Republic", chineseName: "捷克" },
            { name: "Denmark", chineseName: "丹麦" },
            { name: "Djibouti", chineseName: "吉布提" },
            { name: "Dominica", chineseName: "多米尼克" },
            { name: "Dominican Republic", chineseName: "多米尼加" },
            { name: "Ecuador", chineseName: "厄瓜多尔" },
            { name: "Egypt", chineseName: "埃及" },
            { name: "El Salvador", chineseName: "萨尔瓦多" },
            { name: "England", chineseName: "英格兰" },
            { name: "Equatorial Guinea", chineseName: "赤道几内亚" },
            { name: "Eritrea", chineseName: "厄立特里亚" },
            { name: "Estonia", chineseName: "爱沙尼亚" },
            { name: "Eswatini", chineseName: "斯威士兰" },
            { name: "Ethiopia", chineseName: "埃塞俄比亚" },
            { name: "Falkland Islands", chineseName: "福克兰群岛" },
            { name: "Faroe Islands", chineseName: "法罗群岛" },
            { name: "Fiji", chineseName: "斐济" },
            { name: "Finland", chineseName: "芬兰" },
            { name: "France", chineseName: "法国" },
            { name: "French Guiana", chineseName: "法属圭亚那" },
            { name: "French Polynesia", chineseName: "法属波利尼西亚" },
            { name: "French Southern and Antarctic Lands", chineseName: "法属南部和南极领地" },
            { name: "Gabon", chineseName: "加蓬" },
            { name: "The Gambia", chineseName: "冈比亚" },
            { name: "Georgia", chineseName: "格鲁吉亚" },
            { name: "Ghana", chineseName: "加纳" },
            { name: "Gibraltar", chineseName: "直布罗陀" },
            { name: "Greece", chineseName: "希腊" },
            { name: "Greenland", chineseName: "格陵兰" },
            { name: "Grenada", chineseName: "格林纳达" },
            { name: "Guadeloupe", chineseName: "瓜德罗普" },
            { name: "Guam", chineseName: "关岛" },
            { name: "Guatemala", chineseName: "危地马拉" },
            { name: "Guernsey", chineseName: "根西" },
            { name: "Guinea", chineseName: "几内亚" },
            { name: "Guinea-Bissau", chineseName: "几内亚比绍" },
            { name: "Guyana", chineseName: "圭亚那" },
            { name: "Haiti", chineseName: "海地" },
            { name: "Heard Island and McDonald Islands", chineseName: "赫德岛和麦克唐纳群岛" },
            { name: "Honduras", chineseName: "洪都拉斯" },
            { name: "Hungary", chineseName: "匈牙利" },
            { name: "Iceland", chineseName: "冰岛" },
            { name: "India", chineseName: "印度" },
            { name: "Indonesia", chineseName: "印度尼西亚" },
            { name: "Iran", chineseName: "伊朗" },
            { name: "Iraq", chineseName: "伊拉克" },
            { name: "Ireland", chineseName: "爱尔兰" },
            { name: "Isle of Man", chineseName: "马恩岛" },
            { name: "Israel", chineseName: "以色列" },
            { name: "Italy", chineseName: "意大利" },
            { name: "Jamaica", chineseName: "牙买加" },
            { name: "Japan", chineseName: "日本" },
            { name: "Jersey", chineseName: "泽西" },
            { name: "Jordan", chineseName: "约旦" },
            { name: "Kazakhstan", chineseName: "哈萨克斯坦" },
            { name: "Kenya", chineseName: "肯尼亚" },
            { name: "Kiribati", chineseName: "基里巴斯" },
            { name: "Democratic People's Republic of Korea", chineseName: "朝鲜民主主义人民共和国" },
            { name: "Republic of Korea", chineseName: "大韩民国" },
            { name: "Kosovo", chineseName: "科索沃" },
            { name: "Kuwait", chineseName: "科威特" },
            { name: "Kyrgyzstan", chineseName: "吉尔吉斯斯坦" },
            { name: "Laos", chineseName: "老挝" },
            { name: "Latvia", chineseName: "拉脱维亚" },
            { name: "Lebanon", chineseName: "黎巴嫩" },
            { name: "Lesotho", chineseName: "莱索托" },
            { name: "Liberia", chineseName: "利比里亚" },
            { name: "Libya", chineseName: "利比亚" },
            { name: "Liechtenstein", chineseName: "列支敦士登" },
            { name: "Lithuania", chineseName: "立陶宛" },
            { name: "Luxembourg", chineseName: "卢森堡" },
            { name: "Madagascar", chineseName: "马达加斯加" },
            { name: "Malawi", chineseName: "马拉维" },
            { name: "Malaysia", chineseName: "马来西亚" },
            { name: "Maldives", chineseName: "马尔代夫" },
            { name: "Mali", chineseName: "马里" },
            { name: "Malta", chineseName: "马耳他" },
            { name: "Marshall Islands", chineseName: "马绍尔群岛" },
            { name: "Martinique", chineseName: "马提尼克" },
            { name: "Mauritania", chineseName: "毛里塔尼亚" },
            { name: "Mauritius", chineseName: "毛里求斯" },
            { name: "Mayotte", chineseName: "马约特" },
            { name: "Mexico", chineseName: "墨西哥" },
            { name: "Federated States of Micronesia", chineseName: "密克罗尼西亚联邦" },
            { name: "Moldova", chineseName: "摩尔多瓦" },
            { name: "Monaco", chineseName: "摩纳哥" },
            { name: "Mongolia", chineseName: "蒙古" },
            { name: "Montenegro", chineseName: "黑山" },
            { name: "Montserrat", chineseName: "蒙特塞拉特" },
            { name: "Morocco", chineseName: "摩洛哥" },
            { name: "Mozambique", chineseName: "莫桑比克" },
            { name: "Myanmar", chineseName: "缅甸" },
            { name: "Namibia", chineseName: "纳米比亚" },
            { name: "Nauru", chineseName: "瑙鲁" },
            { name: "Nepal", chineseName: "尼泊尔" },
            { name: "Netherlands", chineseName: "荷兰" },
            { name: "New Caledonia", chineseName: "新喀里多尼亚" },
            { name: "New Zealand", chineseName: "新西兰" },
            { name: "Nicaragua", chineseName: "尼加拉瓜" },
            { name: "Niger", chineseName: "尼日尔" },
            { name: "Nigeria", chineseName: "尼日利亚" },
            { name: "Niue", chineseName: "纽埃" },
            { name: "Norfolk Island", chineseName: "诺福克岛" },
            { name: "North Macedonia", chineseName: "北马其顿" },
            { name: "Northern Ireland", chineseName: "北爱尔兰" },
            { name: "Northern Mariana Islands", chineseName: "北马里亚纳群岛" },
            { name: "Norway", chineseName: "挪威" },
            { name: "Oman", chineseName: "阿曼" },
            { name: "Pakistan", chineseName: "巴基斯坦" },
            { name: "Palau", chineseName: "帕劳" },
            { name: "State of Palestine", chineseName: "巴勒斯坦" },
            { name: "Panama", chineseName: "巴拿马" },
            { name: "Papua New Guinea", chineseName: "巴布亚新几内亚" },
            { name: "Paraguay", chineseName: "巴拉圭" },
            { name: "Peru", chineseName: "秘鲁" },
            { name: "Philippines", chineseName: "菲律宾" },
            { name: "Pitcairn Islands", chineseName: "皮特凯恩群岛" },
            { name: "Poland", chineseName: "波兰" },
            { name: "Portugal", chineseName: "葡萄牙" },
            { name: "Puerto Rico", chineseName: "波多黎各" },
            { name: "Qatar", chineseName: "卡塔尔" },
            { name: "Réunion", chineseName: "留尼汪" },
            { name: "Romania", chineseName: "罗马尼亚" },
            { name: "Russian Federation", chineseName: "俄罗斯" },
            { name: "Rwanda", chineseName: "卢旺达" },
            { name: "Saint Barthélemy", chineseName: "圣巴泰勒米" },
            { name: "Saint Helena, Ascension and Tristan da Cunha", chineseName: "圣赫勒拿、阿森松和特里斯坦-达库尼亚" },
            { name: "Saint Kitts and Nevis", chineseName: "圣基茨和尼维斯" },
            { name: "Saint Lucia", chineseName: "圣卢西亚" },
            { name: "Saint Martin (French part)", chineseName: "法属圣马丁" },
            { name: "Saint Pierre and Miquelon", chineseName: "圣皮埃尔和密克隆" },
            { name: "Saint Vincent and the Grenadines", chineseName: "圣文森特和格林纳丁斯" },
            { name: "Samoa", chineseName: "萨摩亚" },
            { name: "San Marino", chineseName: "圣马力诺" },
            { name: "São Tomé and Príncipe", chineseName: "圣多美和普林西比" },
            { name: "Saudi Arabia", chineseName: "沙特阿拉伯" },
            { name: "Scotland", chineseName: "苏格兰" },
            { name: "Senegal", chineseName: "塞内加尔" },
            { name: "Serbia", chineseName: "塞尔维亚" },
            { name: "Seychelles", chineseName: "塞舌尔" },
            { name: "Sierra Leone", chineseName: "塞拉利昂" },
            { name: "Sint Maarten (Dutch part)", chineseName: "荷属圣马丁" },
            { name: "Slovakia", chineseName: "斯洛伐克" },
            { name: "Slovenia", chineseName: "斯洛文尼亚" },
            { name: "Solomon Islands", chineseName: "所罗门群岛" },
            { name: "Somalia", chineseName: "索马里" },
            { name: "South Africa", chineseName: "南非" },
            { name: "South Georgia and the South Sandwich Islands", chineseName: "南乔治亚和南桑威奇群岛" },
            { name: "South Sudan", chineseName: "南苏丹" },
            { name: "Spain", chineseName: "西班牙" },
            { name: "Sri Lanka", chineseName: "斯里兰卡" },
            { name: "Sudan", chineseName: "苏丹" },
            { name: "Suriname", chineseName: "苏里南" },
            { name: "Svalbard and Jan Mayen", chineseName: "斯瓦尔巴和扬马延" },
            { name: "Sweden", chineseName: "瑞典" },
            { name: "Switzerland", chineseName: "瑞士" },
            { name: "Syria", chineseName: "叙利亚" },
            { name: "Tajikistan", chineseName: "塔吉克斯坦" },
            { name: "Tanzania", chineseName: "坦桑尼亚" },
            { name: "Thailand", chineseName: "泰国" },
            { name: "Timor-Leste", chineseName: "东帝汶" },
            { name: "Togo", chineseName: "多哥" },
            { name: "Tokelau", chineseName: "托克劳" },
            { name: "Tonga", chineseName: "汤加" },
            { name: "Trinidad and Tobago", chineseName: "特立尼达和多巴哥" },
            { name: "Tunisia", chineseName: "突尼斯" },
            { name: "Turkey", chineseName: "土耳其" },
            { name: "Turkmenistan", chineseName: "土库曼斯坦" },
            { name: "Turks and Caicos Islands", chineseName: "特克斯和凯科斯群岛" },
            { name: "Tuvalu", chineseName: "图瓦卢" },
            { name: "Uganda", chineseName: "乌干达" },
            { name: "Ukraine", chineseName: "乌克兰" },
            { name: "United Arab Emirates", chineseName: "阿联酋" },
            { name: "United States Minor Outlying Islands", chineseName: "美国本土外小岛屿" },
            { name: "United States Virgin Islands", chineseName: "美属维尔京群岛" },
            { name: "Uruguay", chineseName: "乌拉圭" },
            { name: "Uzbekistan", chineseName: "乌兹别克斯坦" },
            { name: "Vanuatu", chineseName: "瓦努阿图" },
            { name: "Vatican City State", chineseName: "梵蒂冈" },
            { name: "Venezuela", chineseName: "委内瑞拉" },
            { name: "Vietnam", chineseName: "越南" },
            { name: "Wales", chineseName: "威尔士" },
            { name: "Wallis and Futuna", chineseName: "瓦利斯和富图纳" },
            { name: "Western Sahara", chineseName: "西撒哈拉" },
            { name: "Yemen", chineseName: "也门" },
            { name: "Zambia", chineseName: "赞比亚" },
            { name: "Zimbabwe", chineseName: "津巴布韦" },
          ],
          //列出世界上绝大部分银行的中文和英文名字
          bankList: [
            { name: "中国工商银行(Industrial and Commercial Bank of China)", chineseName: "中国工商银行(Industrial and Commercial Bank of China)" },
            { name: "中国农业银行(Agricultural Bank of China)", chineseName: "中国农业银行(Agricultural Bank of China)" },
            { name: "中国银行(Bank of China)", chineseName: "中国银行(Bank of China)" },
            { name: "中国建设银行(China Construction Bank)", chineseName: "中国建设银行(China Construction Bank)" },
            { name: "交通银行(Bank of Communications)", chineseName: "交通银行(Bank of Communications)" },
            { name: "中信银行(China CITIC Bank)", chineseName: "中信银行(China CITIC Bank)" },
            { name: "中国光大银行(China Everbright Bank)", chineseName: "中国光大银行(China Everbright Bank)" },
            { name: "华夏银行(Hua Xia Bank)", chineseName: "华夏银行(Hua Xia Bank)" },
            { name: "中国民生银行(China Minsheng Bank)", chineseName: "中国民生银行(China Minsheng Bank)" },
            { name: "广发银行(China Guangfa Bank)", chineseName: "广发银行(China Guangfa Bank)" },
            { name: "平安银行(Ping An Bank)", chineseName: "平安银行(Ping An Bank)" },
            { name: "招商银行(China Merchants Bank)", chineseName: "招商银行(China Merchants Bank)" },
            { name: "兴业银行(Industrial Bank)", chineseName: "兴业银行(Industrial Bank)" },
            { name: "上海浦东发展银行(Shanghai Pudong Development Bank)", chineseName: "上海浦东发展银行(Shanghai Pudong Development Bank)" },
            { name: "恒丰银行(Everbright Bank)", chineseName: "恒丰银行(Everbright Bank)" },
            { name: "浙商银行(Zhejiang Chouzhou Commercial Bank)", chineseName: "浙商银行(Zhejiang Chouzhou Commercial Bank)" },
            { name: "渤海银行(Bohai Bank)", chineseName: "渤海银行(Bohai Bank)" },
            { name: "中国邮政储蓄银行(China Postal Savings Bank)", chineseName: "中国邮政储蓄银行(China Postal Savings Bank)" },
            { name: "北京银行(Bank of Beijing)", chineseName: "北京银行(Bank of Beijing)" },
            { name: "天津银行(Bank of Tianjin)", chineseName: "天津银行(Bank of Tianjin)" },
            { name: "河北银行(Hebei Bank)", chineseName: "河北银行(Hebei Bank)" },
            { name: "邯郸银行(Handan Bank)", chineseName: "邯郸银行(Handan Bank)" },
            { name: "邢台银行(Xingtai Bank)", chineseName: "邢台银行(Xingtai Bank)" },
            { name: "张家口银行(Zhangjiakou Bank)", chineseName: "张家口银行(Zhangjiakou Bank)" },
            { name: "承德银行(Chengde Bank)", chineseName: "承德银行(Chengde Bank)" },
            { name: "沧州银行(Cangzhou Bank)", chineseName: "沧州银行(Cangzhou Bank)" },
            { name: "廊坊银行(Langfang Bank)", chineseName: "廊坊银行(Langfang Bank)" },
            { name: "衡水银行(Hengshui Bank)", chineseName: "衡水银行(Hengshui Bank)" },
            { name: "晋商银行(Shanxi Jinshang Bank)", chineseName: "晋商银行(Shanxi Jinshang Bank)" },
            { name: "晋城银行(Jincheng Bank)", chineseName: "晋城银行(Jincheng Bank)" },
            { name: "晋中银行(Jinzhong Bank)", chineseName: "晋中银行(Jinzhong Bank)" },
            { name: "阳泉市商业银行(Yangquan City Commercial Bank)", chineseName: "阳泉市商业银行(Yangquan City Commercial Bank)" },
            { name: "包商银行(Baoshang Bank)", chineseName: "包商银行(Baoshang Bank)" },
            { name: "内蒙古银行(Inner Mongolia Bank)", chineseName: "内蒙古银行(Inner Mongolia Bank)" },
            { name: "鄂尔多斯银行(Erdos Bank)", chineseName: "鄂尔多斯银行(Erdos Bank)" },
            { name: "大连银行(Dalian Bank)", chineseName: "大连银行(Dalian Bank)" },
            { name: "鞍山银行(Anshan Bank)", chineseName: "鞍山银行(Anshan Bank)" },
            { name: "抚顺银行(Fushun Bank)", chineseName: "抚顺银行(Fushun Bank)" },
            { name: "本溪市商业银行(Benxi City Commercial Bank)", chineseName: "本溪市商业银行(Benxi City Commercial Bank)" },
            { name: "丹东银行(Dandong Bank)", chineseName: "丹东银行(Dandong Bank)" },
            { name: "锦州银行(Jinzhou Bank)", chineseName: "锦州银行(Jinzhou Bank)" },
            { name: "营口银行(Yingkou Bank)", chineseName: "营口银行(Yingkou Bank)" },
            { name: "阜新银行(Fuxin Bank)", chineseName: "阜新银行(Fuxin Bank)" },
            { name: "辽阳银行(Liaoyang Bank)", chineseName: "辽阳银行(Liaoyang Bank)" },
            { name: "盘锦市商业银行(Panjin City Commercial Bank)", chineseName: "盘锦市商业银行(Panjin City Commercial Bank)" },
            { name: "葫芦岛银行(Huludao Bank)", chineseName: "葫芦岛银行(Huludao Bank)" },
            { name: "长春银行(Changchun Bank)", chineseName: "长春银行(Changchun Bank)" },
            { name: "吉林银行(Jilin Bank)", chineseName: "吉林银行(Jilin Bank)" },
            { name: "哈尔滨银行(Harbin Bank)", chineseName: "哈尔滨银行(Harbin Bank)" },
            { name: "龙江银行(Longjiang Bank)", chineseName: "龙江银行(Longjiang Bank)" },
            { name: "上海银行(Shanghai Bank)", chineseName: "上海银行(Shanghai Bank)" },
            { name: "南京银行(Nanjing Bank)", chineseName: "南京银行(Nanjing Bank)" },
            { name: "江苏银行(Jiangsu Bank)", chineseName: "江苏银行(Jiangsu Bank)" },
            { name: "苏州银行(Suzhou Bank)", chineseName: "苏州银行(Suzhou Bank)" },
            { name: "江苏长江商业银行(Jiangsu Changjiang Commercial Bank)", chineseName: "江苏长江商业银行(Jiangsu Changjiang Commercial Bank)" },
            { name: "杭州银行(Hangzhou Bank)", chineseName: "杭州银行(Hangzhou Bank)" },
            { name: "宁波银行(Ningbo Bank)", chineseName: "宁波银行(Ningbo Bank)" },
            { name: "温州银行(Wenzhou Bank)", chineseName: "温州银行(Wenzhou Bank)" },
            { name: "湖州银行(Huzhou Bank)", chineseName: "湖州银行(Huzhou Bank)" },
            { name: "绍兴银行(Shaoxing Bank)", chineseName: "绍兴银行(Shaoxing Bank)" },
            { name: "浙江稠州商业银行(Zhejiang Chouzhou Commercial Bank)", chineseName: "浙江稠州商业银行(Zhejiang Chouzhou Commercial Bank)" },
            { name: "金华银行(Jinhua Bank)", chineseName: "金华银行(Jinhua Bank)" },
            { name: "衢州银行(Quzhou Bank)", chineseName: "衢州银行(Quzhou Bank)" },
            { name: "台州银行(Taizhou Bank)", chineseName: "台州银行(Taizhou Bank)" },
            { name: "浙江泰隆商业银行(Zhejiang Tailong Commercial Bank)", chineseName: "浙江泰隆商业银行(Zhejiang Tailong Commercial Bank)" },
            { name: "福建海峡银行(Fujian Haixia Bank)", chineseName: "福建海峡银行(Fujian Haixia Bank)" },
            { name: "厦门银行(Xiamen Bank)", chineseName: "厦门银行(Xiamen Bank)" },
            { name: "泉州银行(Quanzhou Bank)", chineseName: "泉州银行(Quanzhou Bank)" },
            { name: "漳州银行(Zhangzhou Bank)", chineseName: "漳州银行(Zhangzhou Bank)" },
            { name: "龙岩银行(Longyan Bank)", chineseName: "龙岩银行(Longyan Bank)" },
            { name: "宁德银行(Ningde Bank)", chineseName: "宁德银行(Ningde Bank)" },
            { name: "南昌银行(Nanchang Bank)", chineseName: "南昌银行(Nanchang Bank)" },
            { name: "赣州银行(Ganzhou Bank)", chineseName: "赣州银行(Ganzhou Bank)" },
            { name: "上饶银行(Shangrao Bank)", chineseName: "上饶银行(Shangrao Bank)" },
            { name: "齐鲁银行(Qilu Bank)", chineseName: "齐鲁银行(Qilu Bank)" },
            { name: "青岛银行(Qingdao Bank)", chineseName: "青岛银行(Qingdao Bank)" },
            { name: "齐商银行(Qishang Bank)", chineseName: "齐商银行(Qishang Bank)" },
            { name: "枣庄银行(Zaozhuang Bank)", chineseName: "枣庄银行(Zaozhuang Bank)" },
            { name: "东营银行(Dongying Bank)", chineseName: "东营银行(Dongying Bank)" },
            { name: "烟台银行(Yantai Bank)", chineseName: "烟台银行(Yantai Bank)" },
            { name: "潍坊银行(Weifang Bank)", chineseName: "潍坊银行(Weifang Bank)" },
            { name: "济宁银行(Jining Bank)", chineseName: "济宁银行(Jining Bank)" },
            { name: "泰安市商业银行(Tai'an City Commercial Bank)", chineseName: "泰安市商业银行(Tai'an City Commercial Bank)" },
            { name: "威海市商业银行(Weihai City Commercial Bank)", chineseName: "威海市商业银行(Weihai City Commercial Bank)" },
            { name: "日照银行(Rizhao Bank)", chineseName: "日照银行(Rizhao Bank)" },
            { name: "莱商银行(Laishang Bank)", chineseName: "莱商银行(Laishang Bank)" },
            { name: "临商银行(Linshang Bank)", chineseName: "临商银行(Linshang Bank)" },
            { name: "德州银行(Dezhou Bank)", chineseName: "德州银行(Dezhou Bank)" },
            { name: "聊城银行(Liaocheng Bank)", chineseName: "聊城银行(Liaocheng Bank)" },
            { name: "滨州银行(Binzhou Bank)", chineseName: "滨州银行(Binzhou Bank)" },
            { name: "齐鲁商业银行(Qilu Commercial Bank)", chineseName: "齐鲁商业银行(Qilu Commercial Bank)" },
            { name: "郑州银行(Zhengzhou Bank)", chineseName: "郑州银行(Zhengzhou Bank)" },
            { name: "开封市商业银行(Kaifeng City Commercial Bank)", chineseName: "开封市商业银行(Kaifeng City Commercial Bank)" },
            { name: "洛阳银行(Luoyang Bank)", chineseName: "洛阳银行(Luoyang Bank)" },
            { name: "平顶山银行(Pingdingshan Bank)", chineseName: "平顶山银行(Pingdingshan Bank)" },
            { name: "安阳银行(Anyang Bank)", chineseName: "安阳银行(Anyang Bank)" },
            { name: "鹤壁银行(Hebi Bank)", chineseName: "鹤壁银行(Hebi Bank)" },
            { name: "新乡银行(Xinxiang Bank)", chineseName: "新乡银行(Xinxiang Bank)" },
            { name: "焦作市商业银行(Jiaozuo City Commercial Bank)", chineseName: "焦作市商业银行(Jiaozuo City Commercial Bank)" },
            { name: "濮阳银行(Puyang Bank)", chineseName: "濮阳银行(Puyang Bank)" },
            { name: "许昌银行(Xuchang Bank)", chineseName: "许昌银行(Xuchang Bank)" },
            { name: "漯河银行(Luohe Bank)", chineseName: "漯河银行(Luohe Bank)" },
            { name: "三门峡银行(Sanmenxia Bank)", chineseName: "三门峡银行(Sanmenxia Bank)" },
            { name: "南阳银行(Nanyang Bank)", chineseName: "南阳银行(Nanyang Bank)" },
            { name: "商丘银行(Shangqiu Bank)", chineseName: "商丘银行(Shangqiu Bank)" },
            { name: "信阳银行(Xinyang Bank)", chineseName: "信阳银行(Xinyang Bank)" },
            { name: "周口银行(Zhoukou Bank)", chineseName: "周口银行(Zhoukou Bank)" },
            { name: "驻马店银行(Zhumadian Bank)", chineseName: "驻马店银行(Zhumadian Bank)" },
            { name: "济源银行(Jiyuan Bank)", chineseName: "济源银行(Jiyuan Bank)" },
            { name: "武汉银行(Wuhan Bank)", chineseName: "武汉银行(Wuhan Bank)" },
            { name: "长沙银行(Changsha Bank)", chineseName: "长沙银行(Changsha Bank)" },
            { name: "广州银行(Guangzhou Bank)", chineseName: "广州银行(Guangzhou Bank)" },
            { name: "广州农村商业银行(Guangzhou Rural Commercial Bank)", chineseName: "广州农村商业银行(Guangzhou Rural Commercial Bank)" },
            { name: "深圳银行(Shenzhen Bank)", chineseName: "深圳银行(Shenzhen Bank)" },
            { name: "东莞银行(Dongguan Bank)", chineseName: "东莞银行(Dongguan Bank)" },
            { name: "中山银行(Zhongshan Bank)", chineseName: "中山银行(Zhongshan Bank)" },
            { name: "惠州银行(Huizhou Bank)", chineseName: "惠州银行(Huizhou Bank)" },
            { name: "珠海华润银行(Zhuhai Huarun Bank)", chineseName: "珠海华润银行(Zhuhai Huarun Bank)" },
            { name: "广西北部湾银行(Guangxi Beibu Gulf Bank)", chineseName: "广西北部湾银行(Guangxi Beibu Gulf Bank)" },
            { name: "北海银行(Beihai Bank)", chineseName: "北海银行(Beihai Bank)" },
            { name: "防城港市商业银行(Fangchenggang City Commercial Bank)", chineseName: "防城港市商业银行(Fangchenggang City Commercial Bank)" },
            { name: "钦州银行(Qinzhou Bank)", chineseName: "钦州银行(Qinzhou Bank)" },
            { name: "贵港银行(Guigang Bank)", chineseName: "贵港银行(Guigang Bank)" },
            { name: "玉林银行(Yulin Bank)", chineseName: "玉林银行(Yulin Bank)" },
            { name: "百色银行(Baise Bank)", chineseName: "百色银行(Baise Bank)" },
            { name: "贺州银行(Hezhou Bank)", chineseName: "贺州银行(Hezhou Bank)" },
            { name: "河池银行(Hechi Bank)", chineseName: "河池银行(Hechi Bank)" },
            { name: "南宁银行(Nanning Bank)", chineseName: "南宁银行(Nanning Bank)" },
            { name: "柳州银行(Liuzhou Bank)", chineseName: "柳州银行(Liuzhou Bank)" },
            { name: "桂林银行(Guilin Bank)", chineseName: "桂林银行(Guilin Bank)" },
            { name: "梧州银行(Wuzhou Bank)", chineseName: "梧州银行(Wuzhou Bank)" },
            { name: "东兴市商业银行(Dongxing City Commercial Bank)", chineseName: "东兴市商业银行(Dongxing City Commercial Bank)" },
            { name: "海口联合农村商业银行(Haikou United Rural Commercial Bank)", chineseName: "海口联合农村商业银行(Haikou United Rural Commercial Bank)" },
            { name: "海南银行(Hainan Bank)", chineseName: "海南银行(Hainan Bank)" },
            { name: "重庆银行(Chongqing Bank)", chineseName: "重庆银行(Chongqing Bank)" },
            { name: "成都银行(Chengdu Bank)", chineseName: "成都银行(Chengdu Bank)" },
            { name: "自贡银行(Zigong Bank)", chineseName: "自贡银行(Zigong Bank)" },
            { name: "攀枝花市商业银行(Panzhihua City Commercial Bank)", chineseName: "攀枝花市商业银行(Panzhihua City Commercial Bank)" },
            { name: "泸州市商业银行(Luzhou City Commercial Bank)", chineseName: "泸州市商业银行(Luzhou City Commercial Bank)" },
            { name: "德阳银行(Deyang Bank)", chineseName: "德阳银行(Deyang Bank)" },
            { name: "绵阳市商业银行(Mianyang City Commercial Bank)", chineseName: "绵阳市商业银行(Mianyang City Commercial Bank)" },
            { name: "广元市商业银行(Guangyuan City Commercial Bank)", chineseName: "广元市商业银行(Guangyuan City Commercial Bank)" },
            { name: "遂宁市商业银行(Suining City Commercial Bank)", chineseName: "遂宁市商业银行(Suining City Commercial Bank)" },
            { name: "内江市商业银行(Neijiang City Commercial Bank)", chineseName: "内江市商业银行(Neijiang City Commercial Bank)" },
            { name: "乐山市商业银行(Leshan City Commercial Bank)", chineseName: "乐山市商业银行(Leshan City Commercial Bank)" },
            { name: "南充市商业银行(Nanchong City Commercial Bank)", chineseName: "南充市商业银行(Nanchong City Commercial Bank)" },
            { name: "眉山市商业银行(Meishan City Commercial Bank)", chineseName: "眉山市商业银行(Meishan City Commercial Bank)" },
            { name: "宜宾市商业银行(Yibin City Commercial Bank)", chineseName: "宜宾市商业银行(Yibin City Commercial Bank)" },
            { name: "宁波东海银行(Ningbo Donghai Bank)", chineseName: "宁波东海银行(Ningbo Donghai Bank)" },
            { name: "汇丰银行(HSBC)", chineseName: "汇丰银行(HSBC)" },
            { name: "渣打银行(Standard Chartered Bank)", chineseName: "渣打银行(Standard Chartered Bank)" },
            { name: "花旗银行(Citibank)", chineseName: "花旗银行(Citibank)" },
            { name: "东亚银行(Bank of East Asia)", chineseName: "东亚银行(Bank of East Asia)" },
            { name: "永亨银行(Wing Hang Bank)", chineseName: "永亨银行(Wing Hang Bank)" },
            { name: "恒生银行(Hang Seng Bank)", chineseName: "恒生银行(Hang Seng Bank)" },
            { name: "大新银行(Dah Sing Bank)", chineseName: "大新银行(Dah Sing Bank)" },
            { name: "创兴银行(Chong Hing Bank)", chineseName: "创兴银行(Chong Hing Bank)" },
            { name: "星展银行(DBS Bank)", chineseName: "星展银行(DBS Bank)" },
            { name: "南洋商业银行(National Bank of Australia)", chineseName: "南洋商业银行(National Bank of Australia)" },
            { name: "澳新银行(ANZ Bank)", chineseName: "澳新银行(ANZ Bank)" },
            { name: "三菱东京日联银行(Bank of Tokyo-Mitsubishi UFJ)", chineseName: "三菱东京日联银行(Bank of Tokyo-Mitsubishi UFJ)" },
            { name: "三井住友银行(Sumitomo Mitsui Banking Corporation)", chineseName: "三井住友银行(Sumitomo Mitsui Banking Corporation)" },
            { name: "瑞穗银行(Mizuho Bank)", chineseName: "瑞穗银行(Mizuho Bank)" },
            { name: "日本三菱信用银行(Mitsubishi UFJ Trust and Banking Corporation)", chineseName: "日本三菱信用银行(Mitsubishi UFJ Trust and Banking Corporation)" },
            { name: "日本山口银行(Yamaguchi Bank)", chineseName: "日本山口银行(Yamaguchi Bank)" },
            { name: "日本埼玉银行(Saitama Bank)", chineseName: "日本埼玉银行(Saitama Bank)" },
            { name: "日本静冈银行(Shizuoka Bank)", chineseName: "日本静冈银行(Shizuoka Bank)" },
            { name: "日本爱媛银行(Ehime Bank)", chineseName: "日本爱媛银行(Ehime Bank)" },
            { name: "日本北都银行(Hokuto Bank)", chineseName: "日本北都银行(Hokuto Bank)" },
            { name: "日本北海道银行(Hokkaido Bank)", chineseName: "日本北海道银行(Hokkaido Bank)" },
            { name: "日本青岛银行(Aomori Bank)", chineseName: "日本青岛银行(Aomori Bank)" },
            { name: "日本山梨银行(Yamanashi Chuo Bank)", chineseName: "日本山梨银行(Yamanashi Chuo Bank)" },
            { name: "日本长野银行(Nagano Bank)", chineseName: "日本长野银行(Nagano Bank)" },
            { name: "日本富山银行(Hokuriku Bank)", chineseName: "日本富山银行(Hokuriku Bank)" },
            { name: "美国银行(Bank of America)", chineseName: "美国银行(Bank of America)" },
            { name: "摩根大通银行(J.P.Morgan Chase Bank)", chineseName: "摩根大通银行(J.P.Morgan Chase Bank)" },
            { name: "德意志银行(Deutsche Bank)", chineseName: "德意志银行(Deutsche Bank)" },
            { name: "法国兴业银行(BNP Paribas)", chineseName: "法国兴业银行(BNP Paribas)" },
            { name: "荷兰银行(ABN AMRO Bank)", chineseName: "荷兰银行(ABN AMRO Bank)" },
            { name: "瑞士银行(Swiss Bank)", chineseName: "瑞士银行(Swiss Bank)" },
            { name: "意大利联合圣保罗银行(Banco Unicredit)", chineseName: "意大利联合圣保罗银行(Banco Unicredit)" },
            { name: "巴克莱银行(Barclays Bank)", chineseName: "巴克莱银行(Barclays Bank)" },
            { name: "苏格兰皇家银行(Royal Bank of Scotland)", chineseName: "苏格兰皇家银行(Royal Bank of Scotland)" },
            { name: "法国巴黎银行(Banque Paribas)", chineseName: "法国巴黎银行(Banque Paribas)" },
            { name: "法国东方汇理银行(Banque Indosuez)", chineseName: "法国东方汇理银行(Banque Indosuez)" },
            { name: "法国外贸银行(Banque Nationale de Paris)", chineseName: "法国外贸银行(Banque Nationale de Paris)" },
            { name: "法国兴业银行(Banque Nationale de Paris)", chineseName: "法国兴业银行(Banque Nationale de Paris)" },
            { name: "法国巴黎银行(Banque Paribas)", chineseName: "法国巴黎银行(Banque Paribas)" },
            { name: "摩根士丹利国际银行(Morgan Stanley International Bank)", chineseName: "摩根士丹利国际银行(Morgan Stanley International Bank)" },
            { name: "美国富国银行(State Street Bank and Trust Company)", chineseName: "美国富国银行(State Street Bank and Trust Company)" },
            { name: "美国银行(Bank of America)", chineseName: "美国银行(Bank of America)" },
            { name: "华侨银行(OCBC)", chineseName: "华侨银行(OCBC)" },
            { name: "众安银行(ZA Bank)", chineseName: "众安银行(ZA Bank)" },
            { name: "招商永隆银行(CMB Wing Lung Bank Limited)", chineseName: "招商永隆银行(CMB Wing Lung Bank Limited)" }
          ],
          //列出卡片的等级
          cardLevel: [
            { name: "银联-普卡", chineseName: "银联-普卡" },
            { name: "银联-金卡", chineseName: "银联-金卡" },
            { name: "银联-白金卡", chineseName: "银联-白金卡" },
            { name: "银联-钻石卡", chineseName: "银联-钻石卡" },
            { name: "银联-黑钻卡", chineseName: "银联-黑钻卡" },
            { name: "银联 + VISA", chineseName: "银联 + VISA" },
            { name: "银联 + MasterCard", chineseName: "银联 + MasterCard" },
            { name: "银联 + JCB", chineseName: "银联 + JCB" },
            { name: "银联 + AE", chineseName: "银联 + AE" },
            { name: "VISA-普卡", chineseName: "VISA-普卡" },
            { name: "VISA-金卡", chineseName: "VISA-金卡" },
            { name: "VISA-白金卡", chineseName: "VISA-白金卡" },
            { name: "VISA-御玺卡", chineseName: "VISA-御玺卡" },
            { name: "VISA-无限卡", chineseName: "VISA-无限卡" },
            { name: "MasterCard-普卡", chineseName: "MasterCard-普卡" },
            { name: "MasterCard-金卡", chineseName: "MasterCard-金卡" },
            { name: "MasterCard-白金卡", chineseName: "MasterCard-白金卡" },
            { name: "MasterCard-钛金卡", chineseName: "MasterCard-钛金卡" },
            { name: "MasterCard-世界卡", chineseName: "MasterCard-世界卡" },
            { name: "MasterCard-世界之极卡", chineseName: "MasterCard-世界之极卡" },
            { name: "JCB-普卡", chineseName: "JCB-普卡" },
            { name: "JCB-金卡", chineseName: "JCB-金卡" },
            { name: "JCB-白金卡", chineseName: "JCB-白金卡" },
            { name: "JCB-御尊卡", chineseName: "JCB-御尊卡" },
            { name: "AE-经典-绿卡", chineseName: "AE-经典-绿卡" },
            { name: "AE-经典-红卡", chineseName: "AE-经典-红卡" },
            { name: "AE-经典-金卡", chineseName: "AE-经典-金卡" },
            { name: "AE-经典-蓝卡", chineseName: "AE-经典-蓝卡" },
            { name: "AE-经典-新贵白金卡", chineseName: "AE-经典-新贵白金卡" },
            { name: "AE-经典-clear卡", chineseName: "AE-经典-clear卡" },
            { name: "AE-经典-Explorer卡", chineseName: "AE-经典-Explorer卡" },
            { name: "AE-经典-Cash Magnet卡", chineseName: "AE-经典-Cash Magnet卡" },
            { name: "AE-经典-百夫长白金卡", chineseName: "AE-经典-百夫长白金卡" },
            { name: "AE-经典-百夫长黑金卡", chineseName: "AE-经典-百夫长黑金卡" },
            { name: "AE-蓝盒子-MEMBER卡", chineseName: "AE-蓝盒子-MEMBER卡" },
            { name: "AE-蓝盒子-SELECT卡", chineseName: "AE-蓝盒子-SELECT卡" },
            { name: "AE-蓝盒子-MAX卡", chineseName: "AE-蓝盒子-MAX卡" },
            { name: "AE-蓝盒子-ICON卡", chineseName: "AE-蓝盒子-ICON卡" },
          ],
          //列出世界上的几乎所有币种
          currencyList: [
            { name: "人民币(CNY)", chineseName: "人民币(CNY)" },
            { name: "人民币离岸(CNH)", chineseName: "人民币离岸(CNH)" },
            { name: "美元(USD)", chineseName: "美元(USD)" },
            { name: "欧元(EUR)", chineseName: "欧元(EUR)" },
            { name: "英镑(GBP)", chineseName: "英镑(GBP)" },
            { name: "日元(JPY)", chineseName: "日元(JPY)" },
            { name: "港币(HKD)", chineseName: "港币(HKD)" },
            { name: "澳元(AUD)", chineseName: "澳元(AUD)" },
            { name: "加元(CAD)", chineseName: "加元(CAD)" },
            { name: "瑞士法郎(CHF)", chineseName: "瑞士法郎(CHF)" },
            { name: "新加坡元(SGD)", chineseName: "新加坡元(SGD)" },
            { name: "瑞典克朗(SEK)", chineseName: "瑞典克朗(SEK)" },
            { name: "丹麦克朗(DKK)", chineseName: "丹麦克朗(DKK)" },
            { name: "挪威克朗(NOK)", chineseName: "挪威克朗(NOK)" },
            { name: "新西兰元(NZD)", chineseName: "新西兰元(NZD)" },
            { name: "泰铢(THB)", chineseName: "泰铢(THB)" },
            { name: "菲律宾比索(PHP)", chineseName: "菲律宾比索(PHP)" },
            { name: "印尼卢比(IDR)", chineseName: "印尼卢比(IDR)" },
            { name: "印度卢比(INR)", chineseName: "印度卢比(INR)" },
          ],
          //尽可能列出卡片的权益种类
          cardType: [
            // wonderfulConsumption: {},//精彩消费
            // foodTemptation: {},//美食诱惑
            // travelWithoutWorry: {},//旅行无忧
            // healthyLife: {},//健康生活
            // highQualityLife: {},//品质生活
            // carOwnerLife: {},//车主生活
            // creditsExchange: {},//积分兑换
            {
              value: "1",
              label: "消费精彩",
              children: [
                { value: "多倍积分", label: "多倍积分" },
                { value: "消费返现", label: "消费返现" },
              ]
            },
            {
              value: "2",
              label: "美食诱惑",
              children: [
                {
                  value: "餐饮饭票", label: "餐饮饭票", children: [
                    { value: "吉野家", label: "吉野家" },
                    { value: "肯德基", label: "肯德基" },
                    { value: "麦当劳", label: "麦当劳" },

                  ]
                },
                { value: "外卖优惠", label: "外卖优惠" },
              ]
            },
            {
              value: "3",
              label: "旅行无忧",
            },
            {
              value: "4",
              label: "健康生活",
            },
            {
              value: "5",
              label: "品质生活",
            },
            {
              value: "7",
              label: "车主生活",
            },
            {
              value: "7",
              label: "积分兑换",
            },
          ],
          //表格自定义数据
          tableCustomData: [
            { label: "国家", value: "country", checked: true },
            { label: "银行", value: "bank", checked: true },
            { label: "卡号", value: "cardNumber", checked: true },
            { label: "等级", value: "level", checked: true },
            { label: "别名", value: "alias", checked: true },
            { label: "额度", value: "limit", checked: true },
            { label: "币种", value: "type", checked: true },
            { label: "CVV", value: "cvv", checked: true },
            { label: "有效期", value: "valid", checked: true },
            { label: "年费", value: "annualFee", checked: true },
            { label: "上期还款日", value: "nowDueDate", checked: true },
            { label: "上期账单还款剩余天数", value: "preDueDateDay", checked: true },
            { label: "本期账单日", value: "nowAccountBillDate", checked: true },
            { label: "本期还款日", value: "nextDueDate", checked: true },
            { label: "下期账单日", value: "nextAccountBillDate", checked: true },
            { label: "本期免息期", value: "interestFreePeriod", checked: true },
            { label: "年费是否达标", value: "isQualified", checked: true },
            { label: "下次年费收取时间", value: "nextAnnualFeeCollectionTime", checked: true },
            { label: "距离上次提额多少天了", value: "lastTime", checked: true },
            { label: "权益", value: "equity", checked: true },
            { label: "备注", value: "remark", checked: true },
          ],
          //年费达标情况
          isQualified:[
            {name:"已达标",value:"1"},
            {name:"未达标",value:"2"},
            {name:"终免年费",value:"3"},
          ]
        }
      },
      sortData: {
        dialogFormVisible: false,
        value: '银行',
        options: ["国家", "银行", "等级", "币种", "本年度年费是否达标"]
      },
      tableCustom: {
        dialogFormVisible: false,
      }
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
      //返回formsearch中所有参数查询条件过滤后的数据
      return this.cardData.filter(item => {
        console.table(item)
        //如果formsearch中的参数为空，就返回所有数据
        if (this.formSearch.bank == '' &&
          this.formSearch.country == '' &&
          this.formSearch.type == '' &&
          this.formSearch.cardNumber == '' &&
          this.formSearch.level == '' &&
          this.formSearch.limit == '' &&
          this.formSearch.cvv == '' &&
          this.formSearch.alias == '' &&
          this.formSearch.valid == '' &&
          this.formSearch.annualFee == '' &&
          this.formSearch.nextAnnualFeeCollectionTime == '' &&
          this.formSearch.equity == '' &&
          this.formSearch.remark == '' &&
          this.formSearch.lastTime == '' &&
          this.formSearch.isQualified == '') {
          return true;
        } else {
          //如果formsearch中的参数不为空，就返回符合条件的数据
          return (item.bank.indexOf(this.formSearch.bank) != -1) &&
            (item.country.indexOf(this.formSearch.country) != -1) &&
            (item.type.indexOf(this.formSearch.type) != -1) &&
            (item.cardNumber.indexOf(this.formSearch.cardNumber) != -1) &&
            (item.level.indexOf(this.formSearch.level) != -1) &&
            (item.limit.indexOf(this.formSearch.limit) != -1) &&
            (item.cvv.indexOf(this.formSearch.cvv) != -1) &&
            (item.valid.indexOf(this.formSearch.valid) != -1) &&
            (item.alias.indexOf(this.formSearch.alias) != -1) &&
            (item.annualFee.indexOf(this.formSearch.annualFee) != -1) &&
            (item.equity.indexOf(this.formSearch.equity) != -1) &&
            (item.remark.indexOf(this.formSearch.remark) != -1) &&
            (item.isQualified.indexOf(this.formSearch.isQualified) != -1);
        }
      })
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
      this.creditCardData.data = {
        id: "",
        country: "",//国家
        bank: "",//银行
        cardNumber: "",//卡号
        alias: "",//卡片别名
        level: "",//等级
        limit: "",//额度
        type: "",//币种
        cvv: "",//cvv码
        valid: "",//有效期
        annualFee: "",//年费
        accountBillDate: "",//账单日
        dueDate: "",//还款日
        nextAnnualFeeCollectionTime: "",//下次年费收取时间
        isQualified: '2',//本年度年费是否达标
        lastTime: "",//距离上次提额多少天了
        equity: "",//权益
        remark: "",//备注
      };
      let id = Math.random().toString(16).slice(2);
      this.creditCardData.data.id = id;
      this.status = 'add';
      this.creditCardData.dialogFormVisible = true;
    },
    //编辑卡片
    cardEdit(index, row) {
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
          if (dateType == "now") {
            //如果账单日大于还款日，上期还款日月份需要加1
            if (_accountBillDate > _dueDate) {
              dueDate = `${y}-${Number(m) + 1}-${_dueDate}`;//上期还款日
            } else {
              dueDate = `${y}-${m}-${_dueDate}`;//上期还款日
            }
          } else {
            if (_accountBillDate > _dueDate) {
              dueDate = `${y}-${(Number(m) + 2) < 10 ? '0' + (Number(m) + 2) : (Number(m) + 2)}-${_dueDate}`;//本期还款日
            } else {
              dueDate = `${y}-${(Number(m) + 1) < 10 ? '0' + (Number(m) + 1) : (Number(m) + 1)}-${_dueDate}`;//本期还款日
            }
          }
          return dueDate;
        } else {
          let date = new Date();
          let y = date.getFullYear();
          let m = (date.getMonth() + 2 < 10 ? '0' + (date.getMonth() + 2) : date.getMonth() + 2);
          if (dateType == "now") {
            if (_accountBillDate > _dueDate) {
              dueDate = `${y}-${m}-${_dueDate}`;//上期还款日
            } else {
              dueDate = `${y}-${(Number(m) - 1) < 10 ? '0' + (Number(m) - 1) : (Number(m) - 1)}-${_dueDate}`;//上期还款日
            }
          } else {
            if (_accountBillDate > _dueDate) {
              dueDate = `${y}-${Number(m) + 1}-${_dueDate}`;//本期还款日
            } else {
              dueDate = `${y}-${m}-${_dueDate}`;//本期还款日
            }
          }
          return dueDate;
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
        let d = date.getDate();
        let accountBillDate = `${y}-${m}-${d}`;
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
  width: calc(100%);
  height: calc(100%);
  background-color: #5672be;
  padding: 20px;
  margin-bottom: 20px;
  align-content: center;
  position: fixed;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);

  .buttons {
    margin-bottom: 20px;
  }

  .headers {
    .el-form-item__content {
      width: 200px;
    }

    margin-bottom: 20px;
    /* 将查询条件加上边框，使其看起来更像一个表单，里面的项目都对齐 */
    border: 1px solid #ebeef5;
    padding: 20px;
    border-radius: 5px;
    background-color: #fff;

    .el-form-item {
      margin-bottom: 10px;
    }

  }
}
</style>
