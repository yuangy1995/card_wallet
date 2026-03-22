<template>
  <el-dialog
    v-model="visible"
    title="找回密码 - 身份验证"
    width="500px"
    :close-on-click-modal="false"
    :z-index="200002"
    center
  >
    <div class="password-recovery">
      <el-alert
        title="请回答以下3个问题来验证您的身份"
        type="info"
        :closable="false"
        show-icon
        style="margin-bottom: 20px"
      />
      
      <div class="questions">
        <div v-for="(question, index) in questions" :key="index" class="question-item" :class="{ 'question-error': questionErrors[index] === false, 'question-correct': questionErrors[index] === true }">
          <h4>问题 {{ index + 1 }}
            <span v-if="questionErrors[index] === false" style="color: #F56C6C; font-size: 13px; font-weight: normal; margin-left: 8px;">✖ 回答错误</span>
            <span v-if="questionErrors[index] === true" style="color: #67C23A; font-size: 13px; font-weight: normal; margin-left: 8px;">✔ 回答正确</span>
          </h4>
          <p>{{ question.question }}</p>
          
          <el-input
            v-if="question.type === 'input'"
            v-model="answers[index]"
            :placeholder="question.placeholder"
            style="margin-top: 10px"
            @input="questionErrors[index] = null"
          />
          
          <el-input
            v-if="question.type === 'date'"
            v-model="answers[index]"
            placeholder="请输入有效期 (格式: MM/YY，如: 06/30)"
            style="margin-top: 10px"
            clearable
            @input="questionErrors[index] = null"
          >
            <template #append>
              <el-date-picker
                v-model="tempDate[index]"
                type="month"
                placeholder=""
                format="MM/YY"
                value-format="YYYY-MM"
                @change="handleDateChange(index, $event)"
                style="width: 120px"
              />
            </template>
          </el-input>
        </div>
      </div>
      
      <div class="buttons">
        <el-button @click="refreshQuestions" :loading="loading">
          <el-icon><Refresh /></el-icon>
          刷新问题
        </el-button>
        <el-button type="primary" @click="verifyAnswers" :loading="loading">
          验证答案
        </el-button>
        <el-button @click="visible = false">取消</el-button>
      </div>
    </div>
  </el-dialog>
</template>
<script setup>
import { ref, computed, onMounted, watch, inject } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh } from '@element-plus/icons-vue'
import { getCardData } from '@/utils/storage'
import { PasswordManager } from '@/utils/passwordManager'
import { useAutoLock } from '@/composables/useAutoLock'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['update:modelValue', 'recovery-success'])
const providedAutoLock = inject('autoLock', null)
const { isLocked } = providedAutoLock || useAutoLock()

const visible = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value)
})

watch(isLocked, (locked) => {
  if (locked && visible.value) {
    visible.value = false
  }
})

const loading = ref(false)
const questions = ref([])
const answers = ref(['', '', ''])
const questionErrors = ref([null, null, null]) // null=未验证, true=正确, false=错误
const cardData = ref([])
const tempDate = ref({}) // 临时存储日期选择器的值

// 生成验证问题
const generateQuestions = () => {
  cardData.value = getCardData()
  
  if (cardData.value.length === 0) {
    ElMessage.error('没有找到信用卡数据，无法生成验证问题')
    visible.value = false
    return
  }

  // 开发环境调试：显示所有卡片数据
  if (import.meta.env.DEV) {
    console.group('🎯 密码找回 - 生成验证问题')
    console.log('可用卡片数据:', cardData.value.map(card => ({
      id: card.id,
      cardNumber: card.cardNumber,
      bankName: card.bank,  // 使用正确的字段名
      alias: card.alias,
      region: card.country,  // 使用正确的字段名
      cvv: card.cvv,
      expiryDate: card.valid,  // 使用正确的字段名
      creditLimit: card.limit  // 使用正确的字段名
    })))
    console.groupEnd()
  }

  const newQuestions = []
  
  // 问题1：输入任意卡片的卡号
  const randomCard1 = cardData.value[Math.floor(Math.random() * cardData.value.length)]
  newQuestions.push({
    type: 'input',
    question: '请输入当前正在使用的任意卡片的卡号',
    placeholder: '请输入完整的卡号',
    cardId: randomCard1.id,
    answer: randomCard1.cardNumber,
    validator: (answer) => {
      const cleanAnswer = answer.trim().replace(/[\s\-]/g, '')
      const found = cardData.value.some(card => {
        const cleanCardNumber = card.cardNumber ? card.cardNumber.trim().replace(/[\s\-]/g, '') : ''
        return cleanCardNumber && cleanCardNumber === cleanAnswer
      })
      
      return found
    }
  })
  
  // 问题2：输入指定尾号的CVV或有效期
  const randomCard2 = cardData.value[Math.floor(Math.random() * cardData.value.length)]
  // 确保获取卡号的最后4位数字，去除空格和非数字字符
  const getLastFourDigits = (cardNumber) => {
    if (!cardNumber) return '****'
    const cleanNumber = cardNumber.replace(/\D/g, '') // 只保留数字
    return cleanNumber.length >= 4 ? cleanNumber.slice(-4) : cleanNumber.padStart(4, '*')
  }
  const lastFourDigits = getLastFourDigits(randomCard2.cardNumber)
  const questionType = Math.random() > 0.5 ? 'cvv' : 'expiry'
  
  if (questionType === 'cvv') {
    newQuestions.push({
      type: 'input',
      question: `请输入尾号为${lastFourDigits}的卡片的CVV`,
      placeholder: '请输入3位CVV码',
      cardId: randomCard2.id,
      answer: randomCard2.cvv,
      validator: (answer) => {
        const cleanAnswer = answer.trim().replace(/[\s\-]/g, '')
        const cleanCvv = randomCard2.cvv ? randomCard2.cvv.toString().trim().replace(/[\s\-]/g, '') : ''
        return cleanAnswer === cleanCvv
      }
    })
  } else {
    newQuestions.push({
      type: 'input',
      question: `请输入尾号为${lastFourDigits}的卡片的有效期`,
      placeholder: '请输入有效期 (格式: MM/YY，如: 06/29 或 YYYYMM，如: 202306)',
      cardId: randomCard2.id,
      answer: randomCard2.valid,  // 使用正确的字段名
      validator: (answer) => {
        if (!answer || !randomCard2.valid) {
          return false
        }
        
        // 解析用户输入的多种格式
        const parseInputDate = (input) => {
          const trimmed = input.trim().replace(/\s/g, '') // 去除所有空格
          
          // 支持MM/YY格式 (如 06/29)
          const mmyyMatch = trimmed.match(/^(\d{1,2})\/(\d{2})$/)
          if (mmyyMatch) {
            const month = parseInt(mmyyMatch[1])
            const year = 2000 + parseInt(mmyyMatch[2]) // 将YY转换为完整年份
            if (month >= 1 && month <= 12) {
              return { year: year, month: month }
            }
          }
          
          // 支持YYYYMM格式 (如 202306)
          const yyyymmMatch = trimmed.match(/^(\d{4})(\d{2})$/)
          if (yyyymmMatch) {
            const year = parseInt(yyyymmMatch[1])
            const month = parseInt(yyyymmMatch[2])
            if (month >= 1 && month <= 12) {
              return { year: year, month: month }
            }
          }
          
          // 支持YYYY-MM格式 (如 2023-06)
          const yyyyDashMmMatch = trimmed.match(/^(\d{4})-(\d{1,2})$/)
          if (yyyyDashMmMatch) {
            const year = parseInt(yyyyDashMmMatch[1])
            const month = parseInt(yyyyDashMmMatch[2])
            if (month >= 1 && month <= 12) {
              return { year: year, month: month }
            }
          }
          
          return null
        }
        
        // 解析卡片的YYYY-MM格式
        const parseCardDate = (cardDate) => {
          if (!cardDate) return null
          const yyyyMmMatch = cardDate.match(/^(\d{4})-(\d{1,2})$/)
          if (yyyyMmMatch) {
            const year = parseInt(yyyyMmMatch[1])
            const month = parseInt(yyyyMmMatch[2])
            return { year: year, month: month }
          }
          return null
        }
        
        const inputDate = parseInputDate(answer)
        const cardDate = parseCardDate(randomCard2.valid)  // 使用正确的字段名
        
        return inputDate && cardDate && 
               inputDate.year === cardDate.year && 
               inputDate.month === cardDate.month
      }
    })
  }
  
  // 问题3：卡片别名+额度
  const randomCard3 = cardData.value[Math.floor(Math.random() * cardData.value.length)]
  
  // 构建卡片显示名称：地区+银行+别名
  const buildCardDisplayName = (card) => {
    const parts = []
    
    // 添加地区
    if (card.country) {
      parts.push(card.country)
    }
    
    // 添加银行名
    if (card.bank) {
      parts.push(card.bank)
    }
    
    // 添加别名
    if (card.alias) {
      parts.push(card.alias)
    }
    
    // 如果都没有，使用默认值
    if (parts.length === 0) {
      parts.push('未知卡片')
    }
    
    return parts.join(' ')
  }
  
  const cardDisplayName = buildCardDisplayName(randomCard3)
  
  newQuestions.push({
    type: 'input',
    question: `${cardDisplayName}的信用额度是多少？`,
    placeholder: '请输入纯数字金额',
    cardId: randomCard3.id,
    answer: randomCard3.limit,  // 使用正确的字段名
    validator: (answer) => {
      const cleanAnswer = answer.replace(/[^\d]/g, '')
      const numAnswer = parseInt(cleanAnswer) || 0
      
      const cleanCardLimit = String(randomCard3.limit || '0').replace(/[^\d]/g, '')
      const cardLimit = parseInt(cleanCardLimit) || 0
      
      return numAnswer === cardLimit && numAnswer > 0
    }
  })
  
  questions.value = newQuestions
  answers.value = ['', '', '']
  questionErrors.value = [null, null, null]
  tempDate.value = {} // 重置临时日期存储
}

// 处理日期选择器变化
const handleDateChange = (index, value) => {
  if (value) {
    // 将YYYY-MM格式转换为MM/YY格式
    const date = new Date(value + '-01')
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const year = String(date.getFullYear()).slice(-2)
    answers.value[index] = `${month}/${year}`
  }
}

// 刷新问题
const refreshQuestions = () => {
  generateQuestions()
  ElMessage.info({ message: '问题已刷新', zIndex: 200010 })
}

// 验证答案
const verifyAnswers = async () => {
  if (answers.value.some(answer => !answer || answer.trim() === '')) {
    ElMessage.warning({ message: '请回答所有问题', zIndex: 200010 })
    return
  }

  loading.value = true
  
  try {
    let correctCount = 0
    const errors = []
    const results = []
    
    questions.value.forEach((question, index) => {
      const isCorrect = question.validator(answers.value[index])
      results[index] = isCorrect
      if (isCorrect) {
        correctCount++
      } else {
        errors.push(`问题 ${index + 1}`)
      }
      
      // 开发环境调试信息
      if (import.meta.env.DEV) {
        console.log(`问题 ${index + 1}: ${question.question}`)
        console.log(`用户答案: "${answers.value[index]}"`)
        console.log(`期望答案: "${getExpectedAnswer(question)}"`)
        console.log(`验证结果: ${isCorrect ? '✅ 正确' : '❌ 错误'}`)
      }
    })
    
    // 更新每个问题的验证状态
    questionErrors.value = results
    
    if (correctCount === 3) {
      ElMessage.success({
        message: '验证成功！请设置新密码',
        zIndex: 200010
      })
      emit('recovery-success')
      visible.value = false
    } else {
      ElMessage.error({
        message: `${errors.join('、')}回答错误，请修改后重试`,
        zIndex: 200010
      })
    }
  } catch (error) {
    ElMessage.error({
      message: '验证过程出错',
      zIndex: 200010
    })
    if (import.meta.env.DEV) {
      console.error('验证过程错误:', error)
    }
  } finally {
    loading.value = false
  }
}

// 获取期望答案的辅助函数
const getExpectedAnswer = (question) => {
  if (question.type === 'input') {
    return question.answer || '未设置'
  } else if (question.type === 'date') {
    return question.answer || '未设置'
  }
  return '未知类型'
}

onMounted(() => {
  if (visible.value) {
    generateQuestions()
  }
})

// 监听显示状态变化
watch(() => visible.value, (newVal) => {
  if (newVal) {
    generateQuestions()
  }
})
</script>

<style scoped>
.password-recovery {
  padding: 10px 0;
}

.questions {
  margin: 20px 0;
}

.question-item {
  margin-bottom: 25px;
  padding: 15px;
  border: 1px solid #eee;
  border-radius: 8px;
  background-color: #fafafa;
}

.question-item :deep(h4) {
  margin: 0 0 8px 0;
  color: #409eff;
  font-size: 16px;
}

.question-item :deep(p) {
  margin: 0 0 10px 0;
  color: #303133;
  font-weight: 500;
}

.password-recovery-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.8);
  backdrop-filter: blur(10px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 99999;
}

/* 确保日期选择器有足够高的z-index */
.password-recovery-overlay :deep(.el-date-editor) {
  z-index: 100001;
}

.password-recovery-overlay :deep(.el-picker-panel) {
  z-index: 100002 !important;
}

.password-recovery-overlay :deep(.el-popper) {
  z-index: 100002 !important;
}

.question-error {
  border-color: #F56C6C !important;
  background-color: #fef0f0 !important;
}

.question-correct {
  border-color: #67C23A !important;
  background-color: #f0f9eb !important;
}

.buttons {
  display: flex;
  justify-content: center;
  gap: 10px;
  margin-top: 30px;
}
</style>
