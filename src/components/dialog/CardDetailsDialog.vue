<template>
  <el-dialog
    v-model="dialogVisible"
    title="信用卡详情"
    center
    top="5vh"
    width="800px"
    draggable
    class="card-details-dialog"
  >
    <el-tabs>
      <!-- 总览标签页 -->
      <el-tab-pane label="总览">
        <el-descriptions :column="2" border>
          <!-- 基本信息 -->
          <el-descriptions-item label="国家">{{ cardInfo.country }}</el-descriptions-item>
          <el-descriptions-item label="银行">{{ cardInfo.bank }}</el-descriptions-item>
          <el-descriptions-item label="卡片别名">{{ cardInfo.alias }}</el-descriptions-item>
          <el-descriptions-item label="等级">{{ cardInfo.level }}</el-descriptions-item>
          <el-descriptions-item label="币种">{{ cardInfo.type }}</el-descriptions-item>
          <el-descriptions-item label="额度">{{ cardInfo.limit }}</el-descriptions-item>
          
          <!-- 卡片信息 -->
          <el-descriptions-item label="卡号">{{ formatCardNumber(cardInfo.cardNumber) }}</el-descriptions-item>descriptions-item>
          <el-descriptions-item label="有效期">{{ cardInfo.valid }}</el-descriptions-item>
          <el-descriptions-item label="CVV码">{{ cardInfo.cvv }}</el-descriptions-item>
          <el-descriptions-item label="账单日">{{ cardInfo.accountBillDate }}</el-descriptions-item>
          <el-descriptions-item label="还款日">{{ cardInfo.dueDate }}</el-descriptions-item>
          <el-descriptions-item label="年费">{{ cardInfo.annualFee }}</el-descriptions-item>

          <!-- 年费信息 -->
          <el-descriptions-item label="年费达标状态" :span="2">
            <el-tag v-if="cardInfo.isQualified === '1'" type="success">已达标</el-tag>
            <el-tag v-if="cardInfo.isQualified === '2'" type="danger">未达标</el-tag>
            <el-tag v-if="cardInfo.isQualified === '3'" type="info">终免年费</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="下次年费收取时间" :span="2">
            {{ cardInfo.nextAnnualFeeCollectionTime }}
          </el-descriptions-item>
          <el-descriptions-item label="上次提额日期" :span="2">
            <div style="white-space: pre-line">{{ lastTimeDisplay }}</div>
          </el-descriptions-item>

          <!-- 其他信息 -->
          <el-descriptions-item label="权益" :span="2">
            <div class="details-content">{{ cardInfo.equity || '暂无权益信息' }}</div>
          </el-descriptions-item>
          <el-descriptions-item label="备注" :span="2">
            <div class="details-content">{{ cardInfo.remark || '暂无备注信息' }}</div>
          </el-descriptions-item>
          <el-descriptions-item label="最后修改时间" :span="2">
            <div style="white-space: pre-line">{{ lastModifyTime }}</div>
          </el-descriptions-item>
        </el-descriptions>
      </el-tab-pane>

      <!-- 基本信息标签页 -->
      <el-tab-pane label="基本信息">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="国家">{{ cardInfo.country }}</el-descriptions-item>
          <el-descriptions-item label="银行">{{ cardInfo.bank }}</el-descriptions-item>
          <el-descriptions-item label="卡片别名">{{ cardInfo.alias }}</el-descriptions-item>
          <el-descriptions-item label="等级">{{ cardInfo.level }}</el-descriptions-item>
          <el-descriptions-item label="币种">{{ cardInfo.type }}</el-descriptions-item>
          <el-descriptions-item label="额度">{{ cardInfo.limit }}</el-descriptions-item>
        </el-descriptions>
      </el-tab-pane>
      
      <!-- 卡片信息标签页 -->
      <el-tab-pane label="卡片信息">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="卡号">{{ formatCardNumber(cardInfo.cardNumber) }}</el-descriptions-item>
          <el-descriptions-item label="有效期">{{ cardInfo.valid }}</el-descriptions-item>
          <el-descriptions-item label="CVV码">{{ cardInfo.cvv }}</el-descriptions-item>
          <el-descriptions-item label="账单日">{{ cardInfo.accountBillDate }}</el-descriptions-item>
          <el-descriptions-item label="还款日">{{ cardInfo.dueDate }}</el-descriptions-item>
          <el-descriptions-item label="年费">{{ cardInfo.annualFee }}</el-descriptions-item>
        </el-descriptions>
      </el-tab-pane>

      <!-- 年费信息标签页 -->
      <el-tab-pane label="年费信息">
        <el-descriptions :column="1" border>
          <el-descriptions-item label="年费达标状态">
            <el-tag v-if="cardInfo.isQualified === '1'" type="success">已达标</el-tag>
            <el-tag v-if="cardInfo.isQualified === '2'" type="danger">未达标</el-tag>
            <el-tag v-if="cardInfo.isQualified === '3'" type="info">终免年费</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="下次年费收取时间">
            {{ cardInfo.nextAnnualFeeCollectionTime }}
          </el-descriptions-item>
          <el-descriptions-item label="上次提额日期">
            <div style="white-space: pre-line">{{ lastTimeDisplay }}</div>
          </el-descriptions-item>
        </el-descriptions>
      </el-tab-pane>

      <!-- 其他信息标签页 -->
      <el-tab-pane label="其他信息">
        <el-descriptions :column="1" border>
          <el-descriptions-item label="权益">
            <div class="details-content">{{ cardInfo.equity || '暂无权益信息' }}</div>
          </el-descriptions-item>
          <el-descriptions-item label="备注">
            <div class="details-content">{{ cardInfo.remark || '暂无备注信息' }}</div>
          </el-descriptions-item>
          <el-descriptions-item label="最后修改时间" :span="2">
            <div style="white-space: pre-line">{{ lastModifyTime }}</div>
          </el-descriptions-item>
        </el-descriptions>
      </el-tab-pane>
    </el-tabs>

    <template #footer>
      <div class="dialog-footer">
        <el-button @click="handleClose">关闭</el-button>
      </div>
    </template>
  </el-dialog>
</template>

<script>
import { inject, watch } from 'vue'
import { getDaysFromNow } from '../../utils/dateCalculator'
import { useAutoLock } from '@/composables/useAutoLock'

export default {
  name: 'CardDetailsDialog',
  
  props: {
    visible: {
      type: Boolean,
      default: false
    },
    cardInfo: {
      type: Object,
      required: true,
      default: () => ({})
    }
  },
  setup(props, { emit }) {
    const providedAutoLock = inject('autoLock', null)
    const { isLocked } = providedAutoLock || useAutoLock()

    watch(isLocked, (locked) => {
      if (locked) {
        emit('update:visible', false)
      }
    })

    return {}
  },

  computed: {
    dialogVisible: {
      get() {
        return this.visible
      },
      set(value) {
        this.$emit('update:visible', value)
      }
    },
    lastTimeDisplay() {
      if (!this.cardInfo.lastTime) return '-'
      const { days, text } = getDaysFromNow(this.cardInfo.lastTime)
      return `${this.cardInfo.lastTime}\n(${text}${days}天)`
    },
    lastModifyTime() {
      if (!this.cardInfo.lastModifyTime) return '-'
      const { days, text } = getDaysFromNow(this.cardInfo.lastModifyTime)
      return this.cardInfo.lastModifyTime
    }
  },

  methods: {
    handleClose() {
      this.dialogVisible = false
    },
    formatCardNumber(cardNumber) {
      if (!cardNumber) return ''
      // 每4个字符添加一个空格
      return cardNumber.replace(/(.{4})/g, '$1 ').trim()
    }
  }
}
</script>

<style lang="scss" scoped>
.card-details-dialog {
  :deep(.el-dialog__body) {
    padding: 0 20px 20px;
  }

  .details-content {
    white-space: pre-wrap;
    word-break: break-all;
  }
}

.dialog-footer {
  text-align: right;
  margin-top: 20px;
}
</style>
