<template>
  <div class="credit-card-table">
    <el-table 
      :data="tableData" 
      style="width: 100%" 
      border
      height="calc(100vh - 250px)"
    >
      <el-table-column type="index" label="序号" width="60" align="center" fixed />
      <el-table-column prop="country" label="国家" width="130" align="center" fixed />
      <el-table-column prop="bank" label="银行" width="150" align="center" fixed />
      <el-table-column prop="alias" label="别名" width="200" align="center" fixed />
      <el-table-column prop="level" label="等级" width="110" align="center" />
      <el-table-column prop="type" label="币种" width="150" align="center" />
      <el-table-column prop="annualFee" label="年费" width="90" align="center" />
      <el-table-column prop="cardNumber" label="💳 卡号" width="200" align="center">
        <template #default="{ row }">
          <secure-field 
            :value="row.cardNumber"
            :mask-start="4"
            :mask-end="12"
            @visibility-change="handleVisibilityChange"
          />
        </template>
      </el-table-column>
      <el-table-column prop="valid" label="有效期" width="80" align="center" />
      <el-table-column prop="cvv" label="🔒 CVV" width="120" align="center">
        <template #default="{ row }">
          <secure-field 
            :value="row.cvv"
            :mask-all="true"
            @visibility-change="handleVisibilityChange"
          />
        </template>
      </el-table-column>
      <el-table-column prop="limit" label="额度" width="100" align="center" />
      <el-table-column prop="nextAnnualFeeCollectionTime" label="下次年费收取时间" width="150" align="center" />
      <el-table-column prop="lastTime" label="最后更新时间" width="170" align="center" />
      <el-table-column prop="isQualified" label="年费达标" width="100" align="center">
        <template #default="{ row }">
          <el-tag v-if="row.isQualified === '1'" type="success">已达标</el-tag>
          <el-tag v-if="row.isQualified === '2'" type="danger">未达标</el-tag>
          <el-tag v-if="row.isQualified === '3'" type="info">终免年费</el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="equity" label="🎁 权益" width="200" align="center" show-overflow-tooltip />
      <el-table-column prop="remark" label="📌 备注" width="200" align="center" show-overflow-tooltip />
      <el-table-column fixed="right" label="操作" min-width="150" align="center">
        <template #default="{ row }">
          <el-button type="primary" size="small" @click="handleEdit(row)">编辑</el-button>
          <el-button type="danger" size="small" @click="handleDelete(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>
  </div>
</template>

<script>
import SecureField from '../common/SecureField.vue'
import { ElMessageBox } from 'element-plus'

export default {
  name: 'CreditCardTable',
  components: {
    SecureField
  },
  props: {
    // 表格数据
    tableData: {
      type: Array,
      required: true
    }
  },
  emits: ['edit', 'delete', 'visibility-change'],
  methods: {
    // 处理编辑按钮点击
    handleEdit(row) {
      this.$emit('edit', row)
    },
    // 处理删除按钮点击
    handleDelete(row) {
      ElMessageBox.confirm(
        '确定要删除这张信用卡吗？',
        '警告',
        {
          confirmButtonText: '确定',
          cancelButtonText: '取消',
          type: 'warning',
        }
      )
        .then(() => {
          this.$emit('delete', row)
        })
        .catch(() => {})
    },
    // 处理可见性变化
    handleVisibilityChange(visible) {
      this.$emit('visibility-change', visible)
    }
  }
}
</script>

<style scoped>
.credit-card-table {
  margin-top: 20px;
}

:deep(.el-table) {
  --el-table-border-color: var(--el-border-color-lighter);
  --el-table-border: 1px solid var(--el-table-border-color);
  border-top: var(--el-table-border);
  border-left: var(--el-table-border);
}

:deep(.el-table--border) {
  border-right: var(--el-table-border);
  border-bottom: var(--el-table-border);
}

:deep(.el-table .cell) {
  white-space: nowrap;
}

:deep(.el-table__body-wrapper) {
  overflow-x: auto !important;
}

:deep(.el-table__fixed-right) {
  height: 100% !important;
  bottom: 0 !important;
}

:deep(.el-table__fixed-right-patch) {
  background-color: var(--el-table-row-hover-bg-color);
}

/* 加粗滚动条 */
:deep(.el-table__body-wrapper::-webkit-scrollbar) {
  width: 12px;
  height: 12px;
}

:deep(.el-table__body-wrapper::-webkit-scrollbar-thumb) {
  background-color: var(--el-border-color);
  border-radius: 6px;
  border: 2px solid transparent;
  background-clip: padding-box;
}

:deep(.el-table__body-wrapper::-webkit-scrollbar-track) {
  background-color: var(--el-fill-color-light);
  border-radius: 6px;
}
</style>
