<template>
  <div class="main_body">
    <div class="buttons">
      <el-button type="primary" @click="addCreditCard">新增信用卡</el-button>
    </div>
    <el-scrollbar height="900px">
      <el-table :data="allData.cardData" border height="900" style="width: 100%">
        <el-table-column type="index" label="序号" width="60" align="center" />
        <el-table-column prop="country" label="国家" width="80" align="center" />
        <el-table-column prop="bank" label="银行" width="100" align="center" />
        <el-table-column prop="cardNumber" label="卡号" width="150" align="center" />
        <el-table-column prop="level" label="等级" width="100" align="center" />
        <el-table-column prop="limit" label="额度" width="100" align="center" />
        <el-table-column prop="cvv" label="cvv码" width="100" align="center" />
        <el-table-column prop="valid" label="有效期" width="100" align="center" />
        <el-table-column prop="annualFee" label="年费" width="100" align="center" />
        <el-table-column prop="NextAnnualFeeCollectionTime" label="下次年费收取时间" width="150" align="center" />
        <el-table-column prop="lastTime" label="距离上次提额多少天了" width="170" align="center" />
        <el-table-column prop="remark" label="备注" min-width="50%" align="center" show-overflow-tooltip />
        <el-table-column label="操作" width="150" align="center">
          <template #default="scope">
            <el-button size="small" @click="numberEdit(scope.$index, scope.row)">编辑</el-button>
            <el-popconfirm title="你确定要删除?" @confirm="numberDelete(scope.$index, scope.row)">
              <template #reference>
                <el-button size="small" type="danger">删除</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-scrollbar>
  </div>
</template>

<script>
export default {
  created() { },
  data() {
    return {
      allData: {
        cardData: [{
          id: "",//id
          country: "中国",//国家
          bank: "",//银行
          cardNumber: "",//卡号
          level: "",//等级
          limit: "",//额度
          cvv: "",//cvv码
          valid: "",//有效期
          annualFee: "",//年费
          NextAnnualFeeCollectionTime: "",//下次年费收取时间
          lastTime: "",//距离上次提额多少天了
          remark: "",//备注
        }]
      }
    }
  },
  methods: {
    addCreditCard() { },
  },
  watch: {},
}
</script>
<style>
.main_body {
  width: 1550px;
  height: 1000px;
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
}
</style>
