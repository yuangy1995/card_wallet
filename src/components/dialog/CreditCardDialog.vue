<template>
  <el-dialog
    v-model="dialogVisible"
    :title="title"
    center
    top="5vh"
    width="800px"
    class="card-details-dialog"
    :close-on-click-modal="false"
    draggable
  >
    <el-form ref="formRef" :model="formData" :rules="rules" label-width="120px">
      <!-- 基本信息 -->
      <el-descriptions :column="2" border>
        <el-descriptions-item label="🌏 国家">
          <el-form-item prop="country">
            <el-select 
              v-model="formData.country" 
              placeholder="请选择国家" 
              filterable 
              allow-create
              clearable
            >
              <el-option 
                v-for="(item, index) in options.countryData" 
                :key="index"
                :label="`${item.chineseName}(${item.name})`" 
                :value="item.chineseName" 
              />
            </el-select>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="🏦 银行">
          <el-form-item prop="bank">
            <el-select 
              v-model="formData.bank" 
              placeholder="请选择银行" 
              filterable 
              allow-create
              clearable
            >
              <el-option 
                v-for="item in options.bankList" 
                :key="item.name" 
                :label="item.name"
                :value="item.chineseName" 
              />
            </el-select>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="💳 卡号">
          <el-form-item prop="cardNumber">
            <el-input 
              v-model="formData.cardNumber" 
              placeholder="请输入卡号"
              maxlength="19"
              :formatter="formatCardNumber"
              :parser="parseCardNumber"
              clearable
              autocomplete="off"
            >
              <template #append>
                <el-tooltip content="信用卡号通常为16位数字，某些卡可能为13-19位">
                  <el-icon><QuestionFilled /></el-icon>
                </el-tooltip>
              </template>
            </el-input>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="📝 卡片别名">
          <el-form-item prop="alias">
            <el-input 
              v-model="formData.alias" 
              placeholder="为卡片起个好记的名字"
              clearable 
              autocomplete="off"
            />
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="⭐️ 等级">
          <el-form-item prop="level">
            <el-select 
              v-model="formData.level" 
              placeholder="请选择等级" 
              filterable
              clearable
            >
              <el-option 
                v-for="item in options.cardLevel" 
                :key="item.name" 
                :label="item.name"
                :value="item.chineseName" 
              />
            </el-select>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="💰 币种">
          <el-form-item prop="type">
            <el-select 
              v-model="formData.type" 
              placeholder="请选择币种" 
              filterable
              clearable
            >
              <el-option 
                v-for="item in options.currencyList" 
                :key="item.name" 
                :label="`${item.name}(${item.chineseName})`"
                :value="item.chineseName" 
              />
            </el-select>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="🔒 CVV">
          <el-form-item prop="cvv">
            <el-input 
              v-model="formData.cvv" 
              placeholder="请输入CVV"
              maxlength="4"
              show-password
              autocomplete="off"
            >
              <template #append>
                <el-tooltip content="CVV通常为卡片背面的3位数字，美国运通卡为正面4位数字">
                  <el-icon><QuestionFilled /></el-icon>
                </el-tooltip>
              </template>
            </el-input>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="📅 有效期">
          <el-form-item prop="valid">
            <el-date-picker
              v-model="formData.valid"
              type="month"
              placeholder="选择有效期"
              format="MM/YY"
              value-format="MM/YY"
              :clearable="true"
              :picker-options="validDateOptions"
            />
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="🔗 银行额度共享">
          <el-form-item prop="isSharedLimit">
            <el-radio-group v-model="formData.isSharedLimit" @change="handleLimitSharingChange">
              <el-radio :value="true" size="large">是</el-radio>
              <el-radio :value="false" size="large">否</el-radio>
            </el-radio-group>
            <div style="color: #909399; font-size: 12px; margin-top: 4px;">
              {{ formData.isSharedLimit ? '该银行所有卡片共享同一额度总额' : '每张卡片拥有独立的信用额度' }}
            </div>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="💵 额度">
          <el-form-item prop="limit">
            <el-input-number
              v-model="formData.limit"
              :min="0"
              :precision="2"
              :step="1000"
              :formatter="value => formatCurrency(value, formData.type)"
              :parser="value => parseCurrency(value)"
              style="width: 100%"
            />
            <div v-if="formData.isSharedLimit && existingSharedLimitCard" 
                 style="color: #E6A23C; font-size: 12px; margin-top: 4px;">
              检测到同银行已有共享额度卡片，修改额度将同步更新所有共享卡片
            </div>
          </el-form-item>
        </el-descriptions-item>

        <!-- 卡片信息 -->
        <el-descriptions-item label="📊 账单日">
          <el-form-item prop="accountBillDate">
            <el-input 
              v-model="formData.accountBillDate" 
              placeholder="请输入账单日(1-31)"
              type="number"
              min="1"
              max="31"
              autocomplete="off" 
              clearable 
            />
          </el-form-item>
        </el-descriptions-item>
        <el-descriptions-item label="💸 还款日">
          <el-form-item prop="dueDate">
            <el-input 
              v-model="formData.dueDate" 
              placeholder="请输入还款日(1-31)"
              type="number"
              min="1"
              max="31"
              autocomplete="off" 
              clearable 
            />
          </el-form-item>
        </el-descriptions-item>
        
        <el-descriptions-item label="📋 账单日消费计入" :span="2">
          <el-form-item prop="billingDaySpendingToNextBill">
            <el-radio-group v-model="formData.billingDaySpendingToNextBill">
              <el-radio :value="false" size="large">当期账单</el-radio>
              <el-radio :value="true" size="large">下期账单</el-radio>
            </el-radio-group>
            <div style="color: #909399; font-size: 12px; margin-top: 4px;">
              {{ formData.billingDaySpendingToNextBill ? '账单日当天的消费将计入下期账单，免息期更长' : '账单日当天的消费将计入当期账单，免息期较短' }}
            </div>
          </el-form-item>
        </el-descriptions-item>
        <el-descriptions-item label="💵 年费">
          <el-input 
            v-model="formData.annualFee" 
            placeholder="请输入年费"
            type="number"
            autocomplete="off" 
            clearable 
          />
        </el-descriptions-item>

        <!-- 年费信息 -->
        <el-descriptions-item label="✅ 年费达标状态" :span="2">
          <el-radio-group v-model="formData.isQualified">
            <el-radio :value="'2'" size="large">未达标</el-radio>
            <el-radio :value="'1'" size="large">已达标</el-radio>
            <el-radio :value="'3'" size="large">终免年费</el-radio>
          </el-radio-group>
        </el-descriptions-item>
        <el-descriptions-item label="⏰ 下次年费收取时间" :span="2">
          <el-date-picker 
            v-model="formData.nextAnnualFeeCollectionTime" 
            type="date" 
            :placeholder="formData.isQualified === '3' ? '终身免年费卡不收年费，无需选择' : '选择下次年费收取时间'"
            format="YYYY-MM-DD" 
            value-format="YYYY-MM-DD" 
            style="width: 100%" 
            :disabled="formData.isQualified === '3'"
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
            autocomplete="off"
          />
        </el-descriptions-item>
        <el-descriptions-item label="📌 备注" :span="2">
          <el-input 
            v-model="formData.remark" 
            type="textarea" 
            :rows="3" 
            placeholder="请输入备注信息" 
            autocomplete="off"
          />
        </el-descriptions-item>
      </el-descriptions>
    </el-form>

    <template #footer>
      <span class="dialog-footer">
        <el-button @click="handleCancel">取消</el-button>
        <el-button type="primary" @click="handleSubmit">确定</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script>
import { ref, computed, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { creditCardOptions } from '@/config/creditCardOptions'
import { QuestionFilled } from '@element-plus/icons-vue'

// 信用卡类型识别
const CARD_TYPES = {
  visa: {
    pattern: /^4/,
    name: '维萨卡'
  },
  mastercard: {
    pattern: /^5[1-5]/,
    name: '万事达卡'
  },
  amex: {
    pattern: /^3[47]/,
    name: '美国运通卡'
  },
  discover: {
    pattern: /^6(?:011|5)/,
    name: '发现卡'
  },
  unionpay: {
    pattern: /^62/,
    name: '银联卡'
  },
  jcb: {
    pattern: /^35/,
    name: 'JCB卡'
  }
}

function getCardType(cardNumber) {
  const cleanNumber = cardNumber.replace(/\D/g, '')
  for (const [type, info] of Object.entries(CARD_TYPES)) {
    if (info.pattern.test(cleanNumber)) {
      return info.name
    }
  }
  return '未知卡片'
}

// 验证卡号
const validateCardNumber = (rule, value, callback) => {
  if (!value) {
    return callback(new Error('请输入卡号'))
  }
  
  // 移除所有非数字字符
  const cardNumber = String(value).replace(/\D/g, '')
  
  // 验证长度
  if (cardNumber.length < 13 || cardNumber.length > 19) {
    return callback(new Error('卡号长度必须在13-19位之间'))
  }
  
  callback()
}

// 验证CVV
const validateCVV = (rule, value, callback) => {
  if (!value) {
    return callback()
  }
  const cvv = String(value).replace(/\D/g, '')
  if (!/^\d{3,4}$/.test(cvv)) {
    return callback(new Error('CVV必须为3-4位数字'))
  }
  callback()
}

// 格式化货币
function formatCurrency(value, currency) {
  if (!value) return ''
  const currencySymbols = {
    'CNY': '¥',
    'USD': '$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'HKD': 'HK$',
    'MOP': 'MOP$',
    'TWD': 'NT$',
    'SGD': 'S$',
    'AUD': 'A$',
    'CAD': 'C$',
    'CHF': 'CHF',
    'THB': '฿'
  }
  const symbol = currencySymbols[currency] || ''
  return `${symbol}${value.toLocaleString()}`
}

// 验证日期范围（1-31）
function validateDateRange(rule, value, callback) {
  if (!value) {
    return callback() // 空值允许
  }
  const num = parseInt(value)
  if (isNaN(num) || num < 1 || num > 31) {
    callback(new Error('请输入1-31之间的数字'))
  } else {
    callback()
  }
}

export default {
  name: 'CreditCardDialog',
  components: {
    QuestionFilled
  },
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
    },
    existingCards: {
      type: Array,
      default: () => []
    }
  },
  emits: ['update:visible', 'submit', 'cancel'],
  setup(props, { emit }) {
    const formRef = ref(null)
    const cardType = ref('')
    
    // 表单验证规则
    const rules = {
      country: [{ required: true, message: '请选择国家', trigger: 'change' }],
      bank: [{ required: true, message: '请选择银行', trigger: 'change' }],
      cardNumber: [
        { required: true, message: '请输入卡号', trigger: 'blur' },
        { validator: validateCardNumber, trigger: 'blur' }
      ],
      cvv: [
        { validator: validateCVV, trigger: 'blur' }
      ],
      valid: [{ required: true, message: '请选择有效期', trigger: 'change' }],
      limit: [
        { required: true, message: '请输入额度', trigger: 'blur' },
        { type: 'number', min: 0, message: '额度必须大于等于0', trigger: 'blur' }
      ],
      type: [{ required: true, message: '请选择币种', trigger: 'change' }],
      annualFee: [
        { required: true, message: '请输入年费', trigger: 'blur' },
        { type: 'number', min: 0, message: '年费必须大于等于0', trigger: 'blur' }
      ],
      accountBillDate: [
        { validator: validateDateRange, trigger: 'blur' }
      ],
      dueDate: [
        { validator: validateDateRange, trigger: 'blur' }
      ]
    }

    // 格式化卡号
    const formatCardNumber = (value) => {
      if (!value) return ''
      value = String(value).replace(/\D/g, '')
      const groups = value.match(/\d{1,4}/g)
      const formatted = groups ? groups.join(' ') : value
      
      // 更新卡片类型
      cardType.value = getCardType(value)
      
      return formatted
    }

    // 解析卡号
    const parseCardNumber = (value) => {
      return String(value).replace(/\s/g, '')
    }

    // 解析货币
    const parseCurrency = (value) => {
      if (typeof value === 'string') {
        return Number(value.replace(/[^\d.-]/g, ''))
      }
      return value
    }

    // 有效期选项
    const validDateOptions = {
      disabledDate(time) {
        return time.getTime() < Date.now()
      }
    }

    // 对话框标题
    const title = computed(() => {
      const baseTitle = props.mode === 'add' ? '新增信用卡' : '编辑信用卡'
      return cardType.value ? `${baseTitle} (${cardType.value})` : baseTitle
    })

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
      type: 'CNY',
      limit: 0,
      cvv: '',
      valid: '',
      annualFee: 0,
      accountBillDate: '',
      dueDate: '',
      nextAnnualFeeCollectionTime: '',
      isQualified: '2',
      lastTime: '',
      equity: '',
      remark: '',
      isSharedLimit: true, // 默认共享额度
      billingDaySpendingToNextBill: true // 默认账单日消费计入下期账单
    })

    // 检查是否存在同银行的卡片
    const existingSharedLimitCard = ref(null)

    // 监听初始数据变化
    watch(
      () => props.initialData,
      (newVal) => {
        if (props.mode === 'edit' && newVal) {
          // 深拷贝初始数据
          const data = JSON.parse(JSON.stringify(newVal))
          
          // 处理特殊字段的格式转换
          if (data.valid) {
            // 如果是老格式（YYYY-MM-DD 或 YYYY-MM），转换为 MM/YY
            if (!/^\d{2}\/\d{2}$/.test(data.valid)) {
              try {
                const date = new Date(data.valid)
                if (!isNaN(date.getTime())) {
                  data.valid = `${String(date.getMonth() + 1).padStart(2, '0')}/${String(date.getFullYear() % 100).padStart(2, '0')}`
                }
              } catch (error) {
                console.error('有效期格式转换失败:', error)
                data.valid = ''
              }
            }
          }
          
          // 确保数值类型字段正确
          data.limit = Number(data.limit) || 0
          data.annualFee = Number(data.annualFee) || 0
          // 统一账单日和还款日的数据类型为String
          data.accountBillDate = data.accountBillDate ? String(data.accountBillDate) : ''
          data.dueDate = data.dueDate ? String(data.dueDate) : ''
          
          // 更新表单数据
          formData.value = data
          
          // 更新卡片类型
          if (data.cardNumber) {
            cardType.value = getCardType(data.cardNumber)
          }
        }
      },
      { immediate: true, deep: true }
    )

    // 处理额度共享变化
    const handleLimitSharingChange = (isShared) => {
      if (isShared && formData.value.country && formData.value.bank) {
        checkExistingSharedLimit()
      } else {
        existingSharedLimitCard.value = null
      }
    }

    // 检查同银行现有卡片的额度
    const checkExistingSharedLimit = () => {
      if (!formData.value.country || !formData.value.bank) return
      
      const currentCountry = formData.value.country
      const currentBank = formData.value.bank.replace(/\(.*?\)/g, "").trim()
      
      // 查找同国家同银行的已有卡片（排除当前编辑的卡片）
      const existingCard = props.existingCards.find(card => {
        const cardBank = (card.bank || '').replace(/\(.*?\)/g, "").trim()
        return card.country === currentCountry && 
               cardBank === currentBank && 
               card.isSharedLimit === true &&
               card.id !== formData.value.id
      })
      
      if (existingCard) {
        existingSharedLimitCard.value = existingCard
        // 只在新增模式下自动设置已有共享额度，编辑模式下不自动覆盖以允许用户修改
        if (props.mode === 'add') {
          formData.value.limit = existingCard.limit
          formData.value.type = existingCard.type
        }
      } else {
        existingSharedLimitCard.value = null
      }
    }

    // 监听国家和银行变化，当选择共享额度时自动检查
    watch([() => formData.value.country, () => formData.value.bank], () => {
      if (formData.value.isSharedLimit) {
        checkExistingSharedLimit()
      }
    })

    // 监听年费达标状态变化
    watch(() => formData.value.isQualified, (newVal) => {
      if (newVal === '3') {
        // 选择终身免年费时，清空下次年费收取时间
        formData.value.nextAnnualFeeCollectionTime = ''
      }
    })

    // 监听 visible 变化，当对话框关闭时重置表单
    watch(
      () => props.visible,
      (newVal) => {
        if (!newVal) {
          // 重置表单数据
          formData.value = {
            country: '',
            bank: '',
            cardNumber: '',
            alias: '',
            level: '',
            type: 'CNY',
            limit: 0,
            cvv: '',
            valid: '',
            annualFee: 0,
            accountBillDate: '',
            dueDate: '',
            nextAnnualFeeCollectionTime: '',
            isQualified: '2',
            lastTime: '',
            equity: '',
            remark: '',
            isSharedLimit: true,
            billingDaySpendingToNextBill: true
          }
          // 重置相关状态
          existingSharedLimitCard.value = null
          cardType.value = ''
          // 重置表单验证
          if (formRef.value) {
            formRef.value.resetFields()
          }
        }
      }
    )

    // 选项数据
    const options = {
      countryData: creditCardOptions.countryData,
      bankList: creditCardOptions.bankList,
      cardLevel: creditCardOptions.cardLevel,
      currencyList: [
        { name: '人民币', chineseName: 'CNY' },
        { name: '美元', chineseName: 'USD' },
        { name: '日元', chineseName: 'JPY' },
        { name: '欧元', chineseName: 'EUR' },
        { name: '英镑', chineseName: 'GBP' },
        { name: '港币', chineseName: 'HKD' },
        { name: '澳门币', chineseName: 'MOP' },
        { name: '新台币', chineseName: 'TWD' },
        { name: '新加坡元', chineseName: 'SGD' },
        { name: '澳大利亚元', chineseName: 'AUD' },
        { name: '加拿大元', chineseName: 'CAD' },
        { name: '瑞士法郎', chineseName: 'CHF' },
        { name: '泰铢', chineseName: 'THB' }
      ]
    }

    // 处理取消
    const handleCancel = () => {
      dialogVisible.value = false
      emit('cancel')
    }

    // 处理提交
    const handleSubmit = () => {
      formRef.value.validate((valid) => {
        if (!valid) return
        if(!formData.value.id){
          formData.value.id = crypto.randomUUID();
        }
        // 处理提交数据
        const submitData = { ...formData.value }
        
        // 保持有效期为 MM/YY 格式存储
        // 不再转换为 YYYY-MM-DD 格式
        emit('submit', submitData)
        dialogVisible.value = false
      })
    }

    return {
      formRef,
      title,
      dialogVisible,
      formData,
      options,
      rules,
      cardType,
      formatCardNumber,
      parseCardNumber,
      formatCurrency,
      parseCurrency,
      validDateOptions,
      handleCancel,
      handleSubmit,
      handleLimitSharingChange,
      existingSharedLimitCard
    }
  }
}
</script>

<style scoped>
.card-details-dialog {
  :deep(.el-descriptions__cell) {
    .el-form-item {
      margin-bottom: 0;
      width: 100%;

      .el-form-item__content {
        margin-left: 0 !important;
      }
    }
  }
  
  :deep(.el-descriptions__cell.is-left) {
    white-space: nowrap;
    overflow: visible;
  }

  :deep(.el-descriptions-item__container) {
    display: flex;
    align-items: center;
    width: 100%;
  }

  :deep(.el-descriptions-item__content) {
    flex: 1;
    min-width: 0;
    white-space: nowrap;
    overflow: visible;
  }
  
  .el-select,
  .el-input,
  .el-input-number,
  .el-date-picker {
    width: 100%;
  }
  
  :deep(.el-input-group__append) {
    padding: 0 10px;
    cursor: help;
  }
}

.dialog-footer {
  padding: 20px;
  text-align: right;
  background-color: var(--el-bg-color);
  border-top: 1px solid var(--el-border-color-lighter);
}
</style>
