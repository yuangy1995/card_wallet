<template>
  <el-dialog
    v-model="dialogVisible"
    :title="title"
    center
    top="5vh"
    width="900px"
    class="card-details-dialog"
    :close-on-click-modal="false"
    draggable
  >
    <el-form ref="formRef" :model="formData" :rules="rules" label-width="120px">
      <!-- 彻底拦截并隔离浏览器流氓自动填充的伪装输入框 -->
      <input type="text" style="position: absolute; top: -9999px; left: -9999px; width: 0; height: 0; opacity: 0;" />
      <input type="password" style="position: absolute; top: -9999px; left: -9999px; width: 0; height: 0; opacity: 0;" />

      <el-descriptions :column="2" border>
        <el-descriptions-item label="卡类别" :span="2">
          <el-form-item prop="cardCategory">
            <el-radio-group v-model="formData.cardCategory">
              <el-radio-button
                v-for="item in options.cardCategory"
                :key="item.value"
                :value="item.value"
              >
                {{ item.label }}
              </el-radio-button>
            </el-radio-group>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="国家">
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
                :label="item.chineseName"
                :value="item.chineseName"
              />
            </el-select>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="银行">
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

        <el-descriptions-item label="卡号">
          <el-form-item prop="cardNumber">
            <el-input
              v-model="formData.cardNumber"
              placeholder="请输入卡号"
              maxlength="19"
              :formatter="formatCardNumber"
              :parser="parseCardNumber"
              clearable
              autocomplete="new-password"
              :readonly="cardNumberReadOnly"
              @focus="cardNumberReadOnly = false"
              @blur="cardNumberReadOnly = true"
            >
              <template #append>
                <el-tooltip content="银行卡号通常为13-19位数字">
                  <el-icon><QuestionFilled /></el-icon>
                </el-tooltip>
              </template>
            </el-input>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="卡片别名">
          <el-form-item prop="alias">
            <el-input
              v-model="formData.alias"
              placeholder="为卡片起个好记的名字"
              clearable
              autocomplete="new-password"
            />
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="等级">
          <el-form-item prop="level">
            <div class="card-level-picker">
              <el-cascader
                v-model="formData.level"
                :options="options.cardLevelGroups"
                :props="{ emitPath: false }"
                placeholder="请选择卡组织和等级"
                clearable
              />
              <span class="card-level-preview">
                {{ formData.level ? `预览：${formData.level}` : '预览：—' }}
              </span>
            </div>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="币种">
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
                :label="item.name"
                :value="item.chineseName"
              >
                <div style="display: flex; justify-content: space-between; align-items: center; width: 100%;">
                  <span>{{ item.name }}</span>
                  <span style="color: var(--el-text-color-secondary); font-size: 12px; margin-left: 20px;">{{ item.value }}</span>
                </div>
              </el-option>
            </el-select>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="CVV">
          <el-form-item prop="cvv">
            <el-input
              v-model="formData.cvv"
              placeholder="请输入CVV"
              maxlength="4"
              show-password
              autocomplete="new-password"
              :readonly="cvvReadOnly"
              @focus="cvvReadOnly = false"
              @blur="cvvReadOnly = true"
            >
              <template #append>
                <el-tooltip content="CVV通常为卡片背面的3位数字，美国运通卡为正面4位数字">
                  <el-icon><QuestionFilled /></el-icon>
                </el-tooltip>
              </template>
            </el-input>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item label="有效期">
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

        <el-descriptions-item v-if="isCreditCard" label="银行额度共享">
          <el-form-item prop="isSharedLimit">
            <el-radio-group v-model="formData.isSharedLimit" @change="handleLimitSharingChange">
              <el-radio :value="true" size="large">是</el-radio>
              <el-radio :value="false" size="large">否</el-radio>
            </el-radio-group>
            <div class="field-helper">
              {{ formData.isSharedLimit ? '同地区、同银行、同币种的共享卡使用同一额度' : '每张卡片拥有独立的信用额度' }}
            </div>
          </el-form-item>
        </el-descriptions-item>

        <el-descriptions-item v-if="isCreditCard" label="额度">
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
            <div
              v-if="formData.isSharedLimit && existingSharedLimitCard"
              class="field-warning"
            >
              检测到同银行已有共享额度卡片，修改额度将同步更新所有共享卡片
            </div>
          </el-form-item>
        </el-descriptions-item>

        <!-- 卡片信息 -->
        <el-descriptions-item v-if="isCreditCard" label="账单日">
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
        <el-descriptions-item v-if="isCreditCard" label="还款日">
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

        <el-descriptions-item v-if="isCreditCard" label="账单日消费计入" :span="2">
          <el-form-item prop="billingDaySpendingToNextBill">
            <el-radio-group v-model="formData.billingDaySpendingToNextBill">
              <el-radio :value="false" size="large">当期账单</el-radio>
              <el-radio :value="true" size="large">下期账单</el-radio>
            </el-radio-group>
            <div class="field-helper">
              {{ formData.billingDaySpendingToNextBill ? '账单日当天的消费将计入下期账单，免息期更长' : '账单日当天的消费将计入当期账单，免息期较短' }}
            </div>
          </el-form-item>
        </el-descriptions-item>
        <el-descriptions-item v-if="isCreditCard" label="年费">
          <el-input
            v-model="formData.annualFee"
            placeholder="请输入年费"
            type="number"
            autocomplete="off"
            clearable
          />
        </el-descriptions-item>

        <!-- 年费信息 -->
        <el-descriptions-item v-if="isCreditCard" label="年费状态" :span="2">
          <el-radio-group v-model="formData.isQualified" class="annual-fee-status-group">
            <el-radio :value="'2'" size="large">未达标</el-radio>
            <el-radio :value="'1'" size="large">已达标</el-radio>
            <el-radio :value="'3'" size="large">终免年费</el-radio>
          </el-radio-group>
        </el-descriptions-item>
        <el-descriptions-item v-if="isCreditCard" label="下次年费收取时间" :span="2">
          <el-date-picker
            v-model="formData.nextAnnualFeeCollectionTime"
            type="date"
            :placeholder="formData.isQualified === '3' ? '终免年费卡不收年费，无需选择' : '选择下次年费收取时间'"
            format="YYYY-MM-DD"
            value-format="YYYY-MM-DD"
            style="width: 100%"
            :disabled="formData.isQualified === '3'"
          />
        </el-descriptions-item>
        <el-descriptions-item v-if="isCreditCard" label="上次提额日期" :span="2">
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
        <el-descriptions-item label="权益" :span="2">
          <el-input
            v-model="formData.equity"
            type="textarea"
            :rows="3"
            placeholder="请输入权益信息"
            autocomplete="off"
          />
        </el-descriptions-item>
        <el-descriptions-item label="备注" :span="2">
          <el-input
            v-model="formData.remark"
            type="textarea"
            :rows="3"
            placeholder="请输入备注信息"
            autocomplete="off"
          />
        </el-descriptions-item>
        <el-descriptions-item label="卡片媒体文件" :span="2">
          <div class="card-media-editor">
            <input
              ref="imageInputRef"
              type="file"
              accept="image/*"
              multiple
              class="card-media-input"
              @change="handleCardImageInput"
            />
            <div class="card-media-actions">
              <el-button type="primary" plain @click="triggerImagePicker">上传图片</el-button>
              <span class="field-helper">上传后，其他设备也可以查看这些图片。</span>
            </div>
            <div v-if="formData.cardImages?.length" class="card-media-summary">
              共 {{ formData.cardImages.length }} 张图片 · 附件总大小 {{ formatFileSize(cardImagesTotalSize) }}
            </div>
            <div v-if="formData.cardImages?.length" class="card-media-grid">
              <div
                v-for="image in formData.cardImages"
                :key="image.id"
                class="card-media-item"
              >
                <img :src="image.data" :alt="image.name || '卡片图片'" />
                <div class="card-media-meta">
                  <div class="card-media-meta-text">
                    <span>{{ image.name || image.source || '卡片图片' }}</span>
                    <small>上传时间 {{ formatImageUploadTime(image.createdAt) }}</small>
                    <small>文件大小 {{ formatFileSize(dataUrlByteSize(image.data)) }}</small>
                  </div>
                  <el-button text type="danger" size="small" @click="removeCardImage(image.id)">删除</el-button>
                </div>
              </div>
            </div>
            <el-empty v-else description="暂无卡片图片" :image-size="72" />
          </div>
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
import { existingSharedLimitCard as findSharedLimitCard } from '@/utils/cardMetrics'
import { ref, computed, watch, inject } from 'vue'
import { ElMessage } from 'element-plus'
import { creditCardOptions } from '@/config/creditCardOptions'
import { QuestionFilled } from '@element-plus/icons-vue'
import { useAutoLock } from '@/composables/useAutoLock'
import { formatTimestampForDateInput, timestampFromDateInput } from '@/utils/cardTimestamp'
import { bankNamesReferToSameBank } from '@/utils/bankName'
import { normalizeCardLevel } from '@/config/referenceData'

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

function validateOptionalAmount(rule, value, callback) {
  if (value === '' || value === null || value === undefined) {
    return callback()
  }
  const amount = Number(value)
  if (Number.isNaN(amount) || amount < 0) {
    return callback(new Error('请输入大于等于0的数字'))
  }
  callback()
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
    const imageInputRef = ref(null)
    const cardType = ref('')
    const providedAutoLock = inject('autoLock', null)
    const { isLocked } = providedAutoLock || useAutoLock()

    // 用于彻底阻止浏览器流氓自动填充表单的动态只读控制状态
    const cardNumberReadOnly = ref(true)
    const cvvReadOnly = ref(true)
    const isCreditCard = computed(() => formData.value.cardCategory !== 'debit')

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
        { validator: validateOptionalAmount, trigger: 'blur' }
      ],
      annualFee: [
        { validator: validateOptionalAmount, trigger: 'blur' }
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
      const categoryText = isCreditCard.value ? '信用卡' : '储蓄卡'
      const baseTitle = props.mode === 'add' ? `新增${categoryText}` : `编辑${categoryText}`
      return cardType.value ? `${baseTitle} (${cardType.value})` : baseTitle
    })

    // 对话框可见性
    const dialogVisible = computed({
      get: () => props.visible,
      set: (value) => emit('update:visible', value)
    })

    watch(isLocked, (locked) => {
      if (locked && dialogVisible.value) {
        dialogVisible.value = false
      }
    })

    // 表单数据
    const formData = ref({
      cardCategory: 'credit',
      country: '',
      bank: '',
      cardNumber: '',
      alias: '',
      level: '',
      type: '',
      limit: null,
      cvv: '',
      valid: '',
      annualFee: null,
      accountBillDate: '',
      dueDate: '',
      nextAnnualFeeCollectionTime: '',
      isQualified: '',
      lastTime: '',
      equity: '',
      remark: '',
      cardImages: [],
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

          // 确保数值类型字段正确，空值保持空白，不给新建/编辑表单追加默认值。
          data.limit = data.limit === '' || data.limit === null || data.limit === undefined ? null : Number(data.limit)
          data.annualFee = data.annualFee === '' || data.annualFee === null || data.annualFee === undefined ? null : Number(data.annualFee)
          data.type = data.type || ''
          data.level = normalizeCardLevel(data.level)
          data.cardCategory = data.cardCategory === 'debit' ? 'debit' : 'credit'
          data.isQualified = data.isQualified || ''
          data.nextAnnualFeeCollectionTime = formatTimestampForDateInput(data.nextAnnualFeeCollectionTime)
          data.lastTime = formatTimestampForDateInput(data.lastTime)
          // 统一账单日和还款日的数据类型为String
          data.accountBillDate = data.accountBillDate ? String(data.accountBillDate) : ''
          data.dueDate = data.dueDate ? String(data.dueDate) : ''
          data.cardImages = normalizeCardImages(data.cardImages)

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
      if (isCreditCard.value && isShared && formData.value.country && formData.value.bank) {
        checkExistingSharedLimit()
      } else {
        existingSharedLimitCard.value = null
      }
    }

    // 检查同银行现有卡片的额度
    const checkExistingSharedLimit = () => {
      if (!isCreditCard.value) {
        existingSharedLimitCard.value = null
        return
      }
      if (!formData.value.country || !formData.value.bank) return

      const existingCard = findSharedLimitCard(props.existingCards, formData.value)

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

    // 监听国家、银行和币种变化，当选择共享额度时自动检查
    watch([() => formData.value.country, () => formData.value.bank, () => formData.value.type], () => {
      if (isCreditCard.value && formData.value.isSharedLimit) {
        checkExistingSharedLimit()
      }
    })

    watch(() => formData.value.cardCategory, (newVal) => {
      if (newVal === 'debit') {
        existingSharedLimitCard.value = null
      } else if (formData.value.isSharedLimit) {
        checkExistingSharedLimit()
      }
    })

    // 监听年费达标状态变化
    watch(() => formData.value.isQualified, (newVal) => {
      if (newVal === '3') {
        // 选择终免年费时，清空下次年费收取时间
        formData.value.nextAnnualFeeCollectionTime = ''
      }
    })

    // 监听 visible 变化，当对话框关闭或打开时均重置/锁定只读状态
    watch(
      () => props.visible,
      (newVal) => {
        // 无论打开还是关闭，均强制锁死为只读，阻止流氓填充
        cardNumberReadOnly.value = true
        cvvReadOnly.value = true

        if (newVal && props.mode === 'add') {
          formData.value.cardCategory = props.initialData?.cardCategory === 'debit' ? 'debit' : 'credit'
          return
        }

        if (!newVal) {
          // 重置表单数据
          formData.value = {
            cardCategory: props.initialData?.cardCategory === 'debit' ? 'debit' : 'credit',
            country: '',
            bank: '',
            cardNumber: '',
            alias: '',
            level: '',
            type: '',
            limit: null,
            cvv: '',
            valid: '',
            annualFee: null,
            accountBillDate: '',
            dueDate: '',
            nextAnnualFeeCollectionTime: '',
            isQualified: '',
            lastTime: '',
            equity: '',
            remark: '',
            cardImages: [],
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
      cardCategory: creditCardOptions.cardCategory,
      countryData: creditCardOptions.countryData,
      bankList: creditCardOptions.bankList,
      cardLevel: creditCardOptions.cardLevel,
      cardLevelGroups: creditCardOptions.cardLevelGroups,
      currencyList: creditCardOptions.currencyList
    }

    // 处理取消
    const handleCancel = () => {
      dialogVisible.value = false
      emit('cancel')
    }

    function normalizeCardImages(value) {
      if (!Array.isArray(value)) return []
      return value
        .map((item, index) => {
          if (typeof item === 'string') {
            const separatorIndex = item.indexOf(';')
            return {
              id: crypto.randomUUID(),
              mimeType: item.startsWith('data:') && separatorIndex > 5 ? item.slice(5, separatorIndex) : 'image/jpeg',
              data: item,
              createdAt: Date.now(),
              source: 'legacy',
              name: `card_image_${index + 1}.jpg`
            }
          }
          return {
            id: item.id || crypto.randomUUID(),
            mimeType: item.mimeType || 'image/jpeg',
            data: item.data || '',
            createdAt: Number(item.createdAt) || Date.now(),
            source: item.source || 'web_upload',
            name: item.name || ''
          }
        })
        .filter(item => item.data)
    }

    const triggerImagePicker = () => {
      imageInputRef.value?.click()
    }

    const dataUrlByteSize = (value) => {
      const encoded = String(value || '').split('base64,').pop().replace(/\s/g, '')
      if (!encoded) return 0
      const padding = encoded.endsWith('==') ? 2 : encoded.endsWith('=') ? 1 : 0
      return Math.max(0, Math.floor(encoded.length * 3 / 4) - padding)
    }

    const formatFileSize = (bytes) => {
      const value = Math.max(0, Number(bytes) || 0)
      if (value < 1024) return `${value} B`
      if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`
      if (value < 1024 * 1024 * 1024) return `${(value / 1024 / 1024).toFixed(1)} MB`
      return `${(value / 1024 / 1024 / 1024).toFixed(1)} GB`
    }

    const formatImageUploadTime = (timestamp) => {
      const value = Number(timestamp)
      if (!Number.isFinite(value) || value <= 0) return '未知'
      const date = new Date(value < 1e12 ? value * 1000 : value)
      if (Number.isNaN(date.getTime())) return '未知'
      return date.toLocaleString('zh-CN', {
        year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit', hour12: false
      })
    }

    const cardImagesTotalSize = computed(() => normalizeCardImages(formData.value.cardImages)
      .reduce((total, image) => total + dataUrlByteSize(image.data), 0))

    const fileToCardImage = (file) => new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = () => {
        resolve({
          id: crypto.randomUUID(),
          mimeType: file.type || 'image/jpeg',
          data: String(reader.result || ''),
          createdAt: Date.now(),
          source: 'web_upload',
          name: file.name
        })
      }
      reader.onerror = reject
      reader.readAsDataURL(file)
    })

    const handleCardImageInput = async (event) => {
      const files = Array.from(event.target.files || []).filter(file => file.type.startsWith('image/'))
      if (!files.length) return
      try {
        const images = await Promise.all(files.map(fileToCardImage))
        formData.value.cardImages = normalizeCardImages(formData.value.cardImages).concat(images)
        ElMessage.success(`已添加 ${images.length} 张卡片图片`)
      } catch (error) {
        ElMessage.error('图片读取失败')
      } finally {
        event.target.value = ''
      }
    }

    const removeCardImage = (imageId) => {
      formData.value.cardImages = normalizeCardImages(formData.value.cardImages).filter(image => image.id !== imageId)
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
        submitData.cardCategory = submitData.cardCategory === 'debit' ? 'debit' : 'credit'
        submitData.nextAnnualFeeCollectionTime = submitData.isQualified === '3'
          ? null
          : timestampFromDateInput(submitData.nextAnnualFeeCollectionTime)
        submitData.lastTime = timestampFromDateInput(submitData.lastTime)
        submitData.cardImages = normalizeCardImages(submitData.cardImages)

        // 保持有效期为 MM/YY 格式存储
        // 不再转换为 YYYY-MM-DD 格式
        emit('submit', submitData)
        dialogVisible.value = false
      })
    }

    return {
      formRef,
      imageInputRef,
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
      triggerImagePicker,
      handleCardImageInput,
      removeCardImage,
      dataUrlByteSize,
      formatFileSize,
      formatImageUploadTime,
      cardImagesTotalSize,
      handleLimitSharingChange,
      existingSharedLimitCard,
      cardNumberReadOnly,
      cvvReadOnly,
      isCreditCard
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
        display: flex;
        flex-direction: column;
        align-items: stretch;
        width: 100%;
      }
    }
  }

  :deep(.el-descriptions__cell.is-left) {
    white-space: nowrap;
    overflow: visible;
  }

  :deep(.el-descriptions-item__container) {
    display: flex;
    align-items: flex-start;
    width: 100%;
  }

  :deep(.el-descriptions-item__content) {
    flex: 1;
    min-width: 0;
    white-space: normal;
    overflow: visible;
  }

  :deep(.el-radio-group) {
    display: flex;
    flex-wrap: wrap;
    row-gap: 8px;
  }

  .el-select,
  .el-input,
  .el-input-number,
  .el-date-picker {
    width: 100%;
  }

  .card-level-picker {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;

    .el-cascader {
      flex: 1;
      min-width: 0;
    }
  }

  .card-level-preview {
    flex: none;
    color: var(--el-text-color-secondary);
    font-size: 12px;
    white-space: nowrap;
  }

  :deep(.el-input-group__append) {
    padding: 0 10px;
    cursor: help;
  }

  .field-helper,
  .field-warning {
    width: 100%;
    margin-top: 4px;
    font-size: 12px;
    line-height: 1.5;
    white-space: normal;
    word-break: break-word;
  }

  .field-helper {
    color: #909399;
    min-height: 18px; /* 强制固死单行提示语的最小高度，彻底绝杀是/否切换描述时的上下抖动 */
  }

  .field-warning {
    color: #E6A23C;
  }

  .card-media-editor {
    width: 100%;
  }

  .card-media-input {
    display: none;
  }

  .card-media-actions {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
    margin-bottom: 12px;
  }

  .card-media-summary {
    margin: -2px 0 12px;
    color: var(--el-text-color-secondary);
    font-size: 12px;
  }

  .card-media-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 12px;
  }

  .card-media-item {
    overflow: hidden;
    border: 1px solid var(--el-border-color);
    border-radius: 8px;
    background: var(--el-fill-color-light);
  }

  .card-media-item img {
    display: block;
    width: 100%;
    aspect-ratio: 1.586;
    object-fit: cover;
    background: #111827;
  }

  .card-media-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    padding: 6px 8px;
    font-size: 12px;
    color: var(--el-text-color-secondary);
  }

  .card-media-meta-text {
    display: grid;
    min-width: 0;
    gap: 2px;
  }

  .card-media-meta-text span {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .card-media-meta-text small {
    color: var(--el-text-color-placeholder);
    font-size: 11px;
    white-space: nowrap;
  }

  /* ==========================================================================
     殿堂级防抖与绝对物理对称（第十二版黄金比例列宽方案）
     ========================================================================== */

  /* 标签单元格：强制锁定 12% 宽度。在 900px 弹窗下相当于极简的 108px，且左右完全对称 */
  :deep(.el-descriptions__label) {
    width: 12% !important;
    box-sizing: border-box !important;
    white-space: nowrap !important;
  }

  /* 内容单元格：强制锁定 38% 宽度。左右百分比完全等宽对称，彻底绝杀输入时清除/小眼睛显隐带来的任何横向晃动 */
  :deep(.el-descriptions__content) {
    width: 38% !important;
    box-sizing: border-box !important;
  }

  /* 2. 年费状态单选按钮一排平铺展示，强行不折行 */
  :deep(.el-radio-group.annual-fee-status-group) {
    display: flex !important;
    flex-wrap: nowrap !important; /* 强行一排平铺，绝不折行 */
    gap: 20px !important;
  }
}

.dialog-footer {
  padding: 20px;
  text-align: right;
  background-color: transparent !important;
  border-top: none;
}
</style>
