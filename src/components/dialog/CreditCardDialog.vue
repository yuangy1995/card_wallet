<template>
  <el-dialog
    v-model="dialogVisible"
    :title="title"
    center
    width="800px"
    class="card-details-dialog"
  >
    <el-descriptions :column="2" border>
      <!-- 基本信息 -->
      <el-descriptions-item label="🌏 国家">
        <el-select v-model="formData.country" placeholder="请选择国家" filterable allow-create>
          <el-option 
            v-for="(item, index) in options.countryData" 
            :key="index"
            :label="`${item.chineseName}(${item.name})`" 
            :value="item.chineseName" 
          />
        </el-select>
      </el-descriptions-item>
      <el-descriptions-item label="🏦 银行">
        <el-select v-model="formData.bank" placeholder="请选择银行" filterable allow-create>
          <el-option 
            v-for="item in options.bankList" 
            :key="item.name" 
            :label="item.name"
            :value="item.chineseName" 
          />
        </el-select>
      </el-descriptions-item>
      <el-descriptions-item label="📝 卡片别名">
        <el-input v-model="formData.alias" autocomplete="off" clearable />
      </el-descriptions-item>
      <el-descriptions-item label="⭐️ 等级">
        <el-select v-model="formData.level" placeholder="请选择等级" filterable>
          <el-option 
            v-for="item in options.cardLevel" 
            :key="item.name" 
            :label="item.name"
            :value="item.chineseName" 
          />
        </el-select>
      </el-descriptions-item>
      <el-descriptions-item label="💰 币种">
        <el-select v-model="formData.type" placeholder="请选择币种" filterable>
          <el-option 
            v-for="item in options.currencyList" 
            :key="item.name" 
            :label="item.name"
            :value="item.chineseName" 
          />
        </el-select>
      </el-descriptions-item>
      <el-descriptions-item label="💳 额度">
        <el-input type="number" v-model="formData.limit" autocomplete="off" clearable />
      </el-descriptions-item>

      <!-- 卡片信息 -->
      <el-descriptions-item label="🔢 卡号">
        <el-input v-model="formData.cardNumber" autocomplete="off" clearable />
      </el-descriptions-item>
      <el-descriptions-item label="📅 有效期">
        <el-date-picker 
          v-model="formData.valid" 
          type="month" 
          placeholder="选择卡片到期时间"
          value-format="YYYY-MM" 
          style="width: 100%" 
        />
      </el-descriptions-item>
      <el-descriptions-item label="🔐 CVV码">
        <el-input v-model="formData.cvv" autocomplete="off" clearable />
      </el-descriptions-item>
      <el-descriptions-item label="📊 账单日">
        <el-input type="number" v-model="formData.accountBillDate" autocomplete="off" clearable />
      </el-descriptions-item>
      <el-descriptions-item label="💸 还款日">
        <el-input type="number" v-model="formData.dueDate" autocomplete="off" clearable />
      </el-descriptions-item>
      <el-descriptions-item label="💵 年费">
        <el-input type="number" v-model="formData.annualFee" autocomplete="off" clearable />
      </el-descriptions-item>

      <!-- 年费信息 -->
      <el-descriptions-item label="✅ 年费达标状态" :span="2">
        <el-radio-group v-model="formData.isQualified">
          <el-radio label="2" size="large">未达标</el-radio>
          <el-radio label="1" size="large">已达标</el-radio>
          <el-radio label="3" size="large">终免年费</el-radio>
        </el-radio-group>
      </el-descriptions-item>
      <el-descriptions-item label="⏰ 下次年费收取时间" :span="2">
        <el-date-picker 
          v-model="formData.nextAnnualFeeCollectionTime" 
          type="date" 
          placeholder="选择下次年费收取时间"
          format="YYYY-MM-DD" 
          value-format="YYYY-MM-DD" 
          style="width: 100%" 
        />
      </el-descriptions-item>
      <el-descriptions-item label="📈 上次提额日期" :span="2">
        <el-date-picker 
          v-model="formData.lastTime" 
          type="date" 
          placeholder="选择上次提额日期" 
          format="YYYY-MM-DD"
          value-format="YYYY-MM-DD" 
          style="width: 100%" 
        />
      </el-descriptions-item>

      <!-- 其他信息 -->
      <el-descriptions-item label="🎁 权益" :span="2">
        <el-input 
          v-model="formData.equity" 
          type="textarea" 
          :rows="3" 
          placeholder="请输入权益信息" 
        />
      </el-descriptions-item>
      <el-descriptions-item label="📌 备注" :span="2">
        <el-input 
          v-model="formData.remark" 
          type="textarea" 
          :rows="3" 
          placeholder="请输入备注信息" 
        />
      </el-descriptions-item>
    </el-descriptions>

    <template #footer>
      <span class="dialog-footer">
        <el-button @click="handleCancel">取消</el-button>
        <el-button type="primary" @click="handleSubmit">确定</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script>
import { ref, computed } from 'vue'
import { ElMessage } from 'element-plus'

export default {
  name: 'CreditCardDialog',
  props: {
    visible: {
      type: Boolean,
      required: true
    },
    mode: {
      type: String,
      required: true,
      validator: (value) => ['add', 'edit'].includes(value)
    },
    initialData: {
      type: Object,
      default: () => ({})
    }
  },
  emits: ['update:visible', 'submit', 'cancel'],
  setup(props, { emit }) {
    // 对话框标题
    const title = computed(() => props.mode === 'add' ? '新增信用卡' : '编辑信用卡')

    // 对话框可见性
    const dialogVisible = computed({
      get: () => props.visible,
      set: (value) => emit('update:visible', value)
    })

    // 表单数据
    const formData = ref({
      country: '',
      bank: '',
      cardNumber: '',
      alias: '',
      level: '',
      limit: '',
      type: '',
      cvv: '',
      valid: '',
      annualFee: '',
      accountBillDate: '',
      dueDate: '',
      nextAnnualFeeCollectionTime: '',
      isQualified: '2',
      lastTime: '',
      equity: '',
      remark: ''
    })

    // 选项数据
    const options = {
      countryData: [
        { name: 'China', chineseName: '中国' },
        { name: 'United States', chineseName: '美国' },
        { name: 'Japan', chineseName: '日本' }
      ],
      bankList: [
        { name: '中国工商银行', chineseName: '工商银行' },
        { name: '中国建设银行', chineseName: '建设银行' },
        { name: '中国农业银行', chineseName: '农业银行' }
      ],
      cardLevel: [
        { name: '金卡', chineseName: '金卡' },
        { name: '白金卡', chineseName: '白金卡' },
        { name: '钻石卡', chineseName: '钻石卡' }
      ],
      currencyList: [
        { name: '人民币', chineseName: 'CNY' },
        { name: '美元', chineseName: 'USD' },
        { name: '日元', chineseName: 'JPY' }
      ]
    }

    // 处理取消
    const handleCancel = () => {
      dialogVisible.value = false
      emit('cancel')
    }

    // 处理提交
    const handleSubmit = () => {
      if (!formData.value.country || !formData.value.bank || !formData.value.cardNumber) {
        ElMessage.error('请填写必填项')
        return
      }
      emit('submit', { ...formData.value })
      dialogVisible.value = false
    }

    // 监听初始数据变化
    if (props.mode === 'edit' && props.initialData) {
      Object.assign(formData.value, props.initialData)
    }

    return {
      title,
      dialogVisible,
      formData,
      options,
      handleCancel,
      handleSubmit
    }
  }
}
</script>

<style scoped>
.card-details-dialog {
  :deep(.el-select),
  :deep(.el-date-picker) {
    width: 100%;
  }

  :deep(.el-dialog__body) {
    max-height: calc(90vh - 120px);
    overflow-y: auto;
    padding: 20px;
  }

  :deep(.el-descriptions__body) {
    width: 100%;
  }

  :deep(.el-descriptions__cell) {
    min-width: 120px;
  }

  :deep(.el-select-dropdown) {
    max-width: none;
  }

  :deep(.el-descriptions-item__container) {
    display: flex;
    align-items: center;
  }

  :deep(.el-descriptions-item__label) {
    width: 140px;
    flex-shrink: 0;
  }

  :deep(.el-descriptions-item__content) {
    flex: 1;
    position: relative;
  }

  /* 修复输入框和日期选择器的抖动 */
  :deep(.el-input) {
    width: 100%;
  }

  :deep(.el-input__wrapper) {
    padding-right: 30px !important;
  }

  :deep(.el-input__clear) {
    position: absolute;
    right: 8px;
    width: 16px;
    height: 16px;
  }

  /* 日期选择器特殊处理 */
  :deep(.el-date-editor.el-input) {
    width: 100%;

    .el-input__wrapper {
      padding-right: 38px !important;
    }

    .el-input__prefix {
      display: flex;
      align-items: center;
    }

    .el-input__suffix {
      position: absolute;
      right: 8px;
      height: 100%;
      display: flex;
      align-items: center;
    }
  }
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  padding: 10px 20px;
  background-color: var(--el-bg-color);
  border-top: 1px solid var(--el-border-color-lighter);
}
</style>
