<template>
  <el-dialog
    v-model="dialogVisible"
    :title="`${cardCategoryText}详情`"
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
          <el-descriptions-item label="银行"><WalletBrandMark :bank="cardInfo.bank" :country="cardInfo.country" /> {{ cardInfo.bank }}</el-descriptions-item>
          <el-descriptions-item label="卡类别">{{ cardCategoryText }}</el-descriptions-item>
          <el-descriptions-item label="卡片别名">{{ cardInfo.alias }}</el-descriptions-item>
          <el-descriptions-item label="等级">{{ cardInfo.level }}</el-descriptions-item>
          <el-descriptions-item label="币种">{{ cardInfo.type }}</el-descriptions-item>
          <el-descriptions-item v-if="isCreditCard" label="额度">{{ cardInfo.limit }}</el-descriptions-item>
          
          <!-- 卡片信息 -->
          <el-descriptions-item label="卡号">{{ formatCardNumber(cardInfo.cardNumber) }}</el-descriptions-item>
          <el-descriptions-item label="有效期">{{ cardInfo.valid }}</el-descriptions-item>
          <el-descriptions-item label="CVV码">{{ cardInfo.cvv }}</el-descriptions-item>
          <el-descriptions-item v-if="isCreditCard" label="账单日">{{ cardInfo.accountBillDate }}</el-descriptions-item>
          <el-descriptions-item v-if="isCreditCard" label="还款日">{{ cardInfo.dueDate }}</el-descriptions-item>
          <el-descriptions-item v-if="isCreditCard" label="年费">{{ cardInfo.annualFee }}</el-descriptions-item>

          <!-- 年费信息 -->
          <el-descriptions-item v-if="isCreditCard" label="年费达标状态" :span="2">
            <el-tag v-if="cardInfo.isQualified === '1'" type="success">已达标</el-tag>
            <el-tag v-if="cardInfo.isQualified === '2'" type="danger">未达标</el-tag>
            <el-tag v-if="cardInfo.isQualified === '3'" type="info">终免年费</el-tag>
          </el-descriptions-item>
          <el-descriptions-item v-if="isCreditCard" label="下次年费收取时间" :span="2">
            {{ nextAnnualFeeCollectionTimeDisplay }}
          </el-descriptions-item>
          <el-descriptions-item v-if="isCreditCard" label="上次提额日期" :span="2">
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
          <el-descriptions-item label="银行"><WalletBrandMark :bank="cardInfo.bank" :country="cardInfo.country" /> {{ cardInfo.bank }}</el-descriptions-item>
          <el-descriptions-item label="卡类别">{{ cardCategoryText }}</el-descriptions-item>
          <el-descriptions-item label="卡片别名">{{ cardInfo.alias }}</el-descriptions-item>
          <el-descriptions-item label="等级">{{ cardInfo.level }}</el-descriptions-item>
          <el-descriptions-item label="币种">{{ cardInfo.type }}</el-descriptions-item>
          <el-descriptions-item v-if="isCreditCard" label="额度">{{ cardInfo.limit }}</el-descriptions-item>
        </el-descriptions>
      </el-tab-pane>
      
      <!-- 卡片信息标签页 -->
      <el-tab-pane label="卡片信息">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="卡号">{{ formatCardNumber(cardInfo.cardNumber) }}</el-descriptions-item>
          <el-descriptions-item label="有效期">{{ cardInfo.valid }}</el-descriptions-item>
          <el-descriptions-item label="CVV码">{{ cardInfo.cvv }}</el-descriptions-item>
          <el-descriptions-item v-if="isCreditCard" label="账单日">{{ cardInfo.accountBillDate }}</el-descriptions-item>
          <el-descriptions-item v-if="isCreditCard" label="还款日">{{ cardInfo.dueDate }}</el-descriptions-item>
          <el-descriptions-item v-if="isCreditCard" label="年费">{{ cardInfo.annualFee }}</el-descriptions-item>
        </el-descriptions>
      </el-tab-pane>

      <el-tab-pane label="卡片媒体">
        <div v-if="normalizedCardImages.length" class="card-media-summary">
          共 {{ normalizedCardImages.length }} 张图片 · 附件总大小 {{ formatFileSize(cardImagesTotalSize) }}
        </div>
        <div v-if="normalizedCardImages.length" class="card-media-grid">
          <div
            v-for="image in normalizedCardImages"
            :key="image.id"
            class="card-media-item"
          >
            <el-image
              :src="image.data"
              fit="contain"
              :preview-src-list="normalizedCardImages.map(item => item.data)"
              preview-teleported
            />
            <div class="card-media-meta">
              <strong>{{ image.name || image.source || '卡片图片' }}</strong>
              <span>上传时间 {{ formatImageUploadTime(image.createdAt) }}</span>
              <span>文件大小 {{ formatFileSize(dataUrlByteSize(image.data)) }}</span>
            </div>
          </div>
        </div>
        <el-empty v-else description="暂无卡片图片" />
      </el-tab-pane>

      <!-- 年费信息标签页 -->
      <el-tab-pane v-if="isCreditCard" label="年费信息">
        <el-descriptions :column="1" border>
          <el-descriptions-item label="年费达标状态">
            <el-tag v-if="cardInfo.isQualified === '1'" type="success">已达标</el-tag>
            <el-tag v-if="cardInfo.isQualified === '2'" type="danger">未达标</el-tag>
            <el-tag v-if="cardInfo.isQualified === '3'" type="info">终免年费</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="下次年费收取时间">
            {{ nextAnnualFeeCollectionTimeDisplay }}
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
import WalletBrandMark from '../common/WalletBrandMark.vue'
import { getDaysFromNow } from '../../utils/dateCalculator'
import { useAutoLock } from '@/composables/useAutoLock'
import { formatCardTimestamp } from '@/utils/cardTimestamp'

export default {
  name: 'CardDetailsDialog',
  components: { WalletBrandMark },
  
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
      return `${formatCardTimestamp(this.cardInfo.lastTime)}\n(${text}${days}天)`
    },
    lastModifyTime() {
      if (!this.cardInfo.lastModifyTime) return '-'
      return formatCardTimestamp(this.cardInfo.lastModifyTime)
    },
    nextAnnualFeeCollectionTimeDisplay() {
      return this.cardInfo.nextAnnualFeeCollectionTime
        ? formatCardTimestamp(this.cardInfo.nextAnnualFeeCollectionTime)
        : '-'
    },
    isCreditCard() {
      return this.cardInfo.cardCategory !== 'debit'
    },
    cardCategoryText() {
      return this.isCreditCard ? '信用卡' : '储蓄卡'
    },
    normalizedCardImages() {
      const images = Array.isArray(this.cardInfo.cardImages) ? this.cardInfo.cardImages : []
      return images
        .map((item, index) => {
          if (typeof item === 'string') {
            return {
              id: `legacy-${index}`,
              data: item,
              createdAt: 0,
              source: 'legacy',
              name: `card_image_${index + 1}.jpg`
            }
          }
          return {
            id: item.id || `image-${index}`,
            data: item.data || '',
            createdAt: Number(item.createdAt) || 0,
            source: item.source || '',
            name: item.name || ''
          }
        })
        .filter(item => item.data)
    },
    cardImagesTotalSize() {
      return this.normalizedCardImages.reduce((total, image) => total + this.dataUrlByteSize(image.data), 0)
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
    },
    dataUrlByteSize(value) {
      const encoded = String(value || '').split('base64,').pop().replace(/\s/g, '')
      if (!encoded) return 0
      const padding = encoded.endsWith('==') ? 2 : encoded.endsWith('=') ? 1 : 0
      return Math.max(0, Math.floor(encoded.length * 3 / 4) - padding)
    },
    formatFileSize(bytes) {
      const value = Math.max(0, Number(bytes) || 0)
      if (value < 1024) return `${value} B`
      if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`
      if (value < 1024 * 1024 * 1024) return `${(value / 1024 / 1024).toFixed(1)} MB`
      return `${(value / 1024 / 1024 / 1024).toFixed(1)} GB`
    },
    formatImageUploadTime(timestamp) {
      const value = Number(timestamp)
      if (!Number.isFinite(value) || value <= 0) return '未知'
      const date = new Date(value < 1e12 ? value * 1000 : value)
      if (Number.isNaN(date.getTime())) return '未知'
      return date.toLocaleString('zh-CN', {
        year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit', hour12: false
      })
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

  .card-media-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 14px;
  }

  .card-media-summary {
    margin-bottom: 12px;
    color: var(--el-text-color-secondary);
    font-size: 12px;
  }

  .card-media-item {
    overflow: hidden;
    border: 1px solid var(--el-border-color);
    border-radius: 8px;
    background: var(--el-fill-color-light);
  }

  .card-media-item :deep(.el-image) {
    display: block;
    width: 100%;
    aspect-ratio: 1.586;
    background: #111827;
  }

  .card-media-meta {
    display: grid;
    gap: 3px;
    padding: 8px;
    color: var(--el-text-color-secondary);
    font-size: 12px;
  }

  .card-media-meta strong {
    overflow: hidden;
    color: var(--el-text-color-regular);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .card-media-meta span {
    color: var(--el-text-color-placeholder);
    font-size: 11px;
  }
}

.dialog-footer {
  text-align: right;
  margin-top: 20px;
}
</style>
