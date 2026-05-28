<template>
  <div
    class="perspective-container"
    ref="cardContainerRef"
    @mousemove="handleMouseMove"
    @mouseleave="handleMouseLeave"
    @dblclick.stop="flipCard"
  >
    <div
      class="physics-card-wrapper"
      :class="{ 'is-flipped': isFlipped }"
      :style="cardStyle"
    >
      <!-- 正面：精美拟物卡片 -->
      <div class="physics-card-face physics-card-front" :class="themeClass">
        <!-- 卡片顶部：银行与卡等级 -->
        <div class="card-header">
          <div class="bank-info">
            <span class="bank-name">{{ getBankDisplayName(card.bank) }}</span>
            <span class="country-tag">{{ card.country || '中国' }}</span>
          </div>
          <div class="card-logo">
            <span class="card-level-badge" :class="card.level">{{ card.level || '普卡' }}</span>
            <!-- 像素级卡组织矢量 Logo -->
            <div class="card-brand-logo" v-if="cardOrganization">
              <!-- Visa -->
              <svg v-if="cardOrganization === 'visa'" viewBox="0 7.8 24 8.2" class="brand-svg visa" fill="#0073e6" style="color: #0073e6 !important;" aria-label="Visa">
                <title>Visa</title>
                <path d="M9.112 8.262L5.97 15.758H3.92L2.374 9.775c-.094-.368-.175-.503-.461-.658C1.447 8.864.677 8.627 0 8.479l.046-.217h3.3a.904.904 0 01.894.764l.817 4.338 2.018-5.102zm8.033 5.049c.008-1.979-2.736-2.088-2.717-2.972.006-.269.262-.555.822-.628a3.66 3.66 0 011.913.336l.34-1.59a5.207 5.207 0 00-1.814-.333c-1.917 0-3.266 1.02-3.278 2.479-.012 1.079.963 1.68 1.698 2.04.756.367 1.01.603 1.006.931-.005.504-.602.725-1.16.734-.975.015-1.54-.263-1.992-.473l-.351 1.642c.453.208 1.289.39 2.156.398 2.037 0 3.37-1.006 3.377-2.564m5.061 2.447H24l-1.565-7.496h-1.656a.883.883 0 00-.826.55l-2.909 6.946h2.036l.405-1.12h2.488zm-2.163-2.656l1.02-2.815.588 2.815zm-8.16-4.84l-1.603 7.496H8.34l1.605-7.496z"/>
              </svg>
              
              <!-- MasterCard -->
              <svg v-else-if="cardOrganization === 'mastercard'" viewBox="0 0 120 74" class="brand-svg mastercard">
                <circle cx="37" cy="37" r="37" fill="#eb001b"/>
                <circle cx="83" cy="37" r="37" fill="#ff5f00" fill-opacity="0.85"/>
              </svg>
              
              <!-- UnionPay (银联) -->
              <div v-else-if="cardOrganization === 'unionpay'" class="logo-unionpay">
                <div class="band red-band"></div>
                <div class="band blue-band"></div>
                <div class="band cyan-band"></div>
                <span class="unionpay-text">UnionPay</span>
              </div>
              
              <!-- AMEX (美国运通) -->
              <div v-else-if="cardOrganization === 'amex'" class="logo-amex">
                <span class="amex-text">AMEX</span>
              </div>
              
              <!-- JCB -->
              <div v-else-if="cardOrganization === 'jcb'" class="logo-jcb">
                <div class="jcb-block j-block">J</div>
                <div class="jcb-block c-block">C</div>
                <div class="jcb-block b-block">B</div>
              </div>
              
              <!-- Discover (兜底) -->
              <div v-else-if="cardOrganization === 'discover'" class="logo-discover">
                <span class="discover-text">DISCOVER</span>
              </div>
            </div>
          </div>
        </div>

        <!-- 卡片中部：别名与卡号 -->
        <div class="card-body">
          <div class="card-alias">{{ card.alias || '未命名卡片' }}</div>
          <div class="card-number-row">
            <el-tooltip
              placement="top"
              :disabled="!cardNumberVisible"
              effect="dark"
              popper-class="copy-tooltip-popper"
            >
              <template #content>
                <span style="color: #ffffff !important; font-weight: 600; font-size: 12px; letter-spacing: 0.5px;">
                  点击卡号一键复制
                </span>
              </template>
              <div 
                class="number-segments-wrapper"
                :class="{ 'is-clickable': cardNumberVisible }"
                @click.stop="copyCardNumber"
              >
                <span class="number-segment" v-for="(seg, idx) in formattedCardNumber" :key="idx">
                  {{ seg }}
                </span>
              </div>
            </el-tooltip>
            <el-button
              type="primary"
              link
              @click.stop="toggleCardNumber"
              class="visibility-btn"
            >
              <el-icon><View v-if="cardNumberVisible" /><Hide v-else /></el-icon>
            </el-button>
          </div>
        </div>

        <!-- 卡片底部：额度与关键信息 -->
        <div class="card-footer">
          <div class="card-limit-info">
            <span class="label">额度 ({{ card.type || 'CNY' }})</span>
            <span class="value">{{ formatLimit(card.limit) }}</span>
            <span v-if="card.isSharedLimit" class="shared-limit-badge">共享</span>
          </div>

          <div class="card-dates">
            <div class="valid-thru">
              <span class="label">VALID THRU</span>
              <span class="value">{{ formatValid(card.valid) }}</span>
            </div>
            <div class="cvv-info">
              <span class="label">CVV</span>
              <span class="value" @click.stop="toggleCvv">{{ cvvVisible ? card.cvv || '***' : '***' }}</span>
            </div>
          </div>
        </div>

        <!-- 科技感高光遮罩 -->
        <div class="shine-overlay"></div>
      </div>

      <!-- 背面：科技看板详细信息 -->
      <div class="physics-card-face physics-card-back">
        <div class="back-header">
          <span class="title">卡片详细账目与年费</span>
          <el-button circle size="small" class="action-btn" @click.stop="flipCard">
            <el-icon><Refresh /></el-icon>
          </el-button>
        </div>

        <div class="back-content">
          <!-- 账单与还款信息 -->
          <div class="info-grid">
            <div class="info-item">
              <span class="label">账单日</span>
              <span class="value">{{ card.accountBillDate ? `${card.accountBillDate} 号` : '-' }}</span>
            </div>
            <div class="info-item">
              <span class="label">还款日</span>
              <span class="value">{{ card.dueDate ? `${card.dueDate} 号` : '-' }}</span>
            </div>
            <div class="info-item">
              <span class="label">免息天数</span>
              <span class="value highlight-text">{{ calculateInterestFree(card.accountBillDate, card.dueDate) }} 天</span>
            </div>
            <div class="info-item">
              <span class="label">下次年费时间</span>
              <span class="value warning-text" v-if="card.isQualified !== '3'">{{ formatCardTimestamp(card.nextAnnualFeeCollectionTime) }}</span>
              <span class="value info-text" v-else>终身免年费</span>
            </div>
          </div>

          <!-- 年费状态快捷按钮 -->
          <div class="annual-fee-status">
            <span class="status-label">年费达标：</span>
            <el-tag v-if="card.isQualified === '1'" type="success" size="small">已达标</el-tag>
            <el-tag v-else-if="card.isQualified === '2'" type="danger" size="small" class="clickable-tag" @click.stop="setAnnualFeeQualified">未达标 (快捷达标)</el-tag>
            <el-tag v-else-if="card.isQualified === '3'" type="info" size="small">终免年费</el-tag>

            <div class="days-remaining" v-if="card.nextAnnualFeeCollectionTime && card.isQualified !== '3'">
              距离收取年费: <span class="days-count">{{ getDaysCount(card.nextAnnualFeeCollectionTime) }}</span> 天
            </div>
          </div>

          <!-- 提额与更新时间 -->
          <div class="time-info">
            <div>上次提额时间: <span>{{ card.lastTime ? formatCardTimestamp(card.lastTime) : '暂无提额记录' }}</span></div>
            <div>上次修改时间: <span>{{ formatCardTimestamp(card.lastModifyTime) }}</span></div>
          </div>

          <!-- 权益与备注简述 -->
          <div class="memo-section">
            <div class="memo-item" v-if="card.equity">
              <span class="memo-title"><el-icon><Star /></el-icon> 权益：</span>
              <span class="memo-desc">{{ card.equity }}</span>
            </div>
            <div class="memo-item" v-if="card.remark">
              <span class="memo-title"><el-icon><Notebook /></el-icon> 备注：</span>
              <span class="memo-desc">{{ card.remark }}</span>
            </div>
          </div>
        </div>

        <div class="back-footer">
          <el-button type="info" size="small" @click.stop="$emit('view-details', card)">
            <el-icon><View /></el-icon> 查看详情弹窗
          </el-button>
          <el-button type="danger" size="small" @click.stop="$emit('delete', card)">
            <el-icon><Delete /></el-icon> 删除卡片
          </el-button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { View, Hide, Refresh, Star, Notebook, Delete } from '@element-plus/icons-vue'
import { getBankDisplayName } from '@/utils/bankNameFormatter'
import { getDaysFromNow } from '@/utils/dateCalculator'
import { ElMessage } from 'element-plus'
import { formatCardTimestamp } from '@/utils/cardTimestamp'

const props = defineProps({
  card: {
    type: Object,
    required: true
  }
})

const emit = defineEmits([
  'edit',
  'delete',
  'view-details',
  'annual-fee-qualified',
  'card-number-visibility',
  'cvv-visibility'
])

// 状态控制
const isFlipped = ref(false)
const cardNumberVisible = ref(false)
const cvvVisible = ref(false)

// 3D 鼠标倾斜计算
const cardContainerRef = ref(null)
const sheenX = ref(0)
const sheenY = ref(0)
const isHovering = ref(false)

// 翻转卡片
const flipCard = () => {
  isFlipped.value = !isFlipped.value
}

// 切换卡号防窥
const toggleCardNumber = () => {
  cardNumberVisible.value = !cardNumberVisible.value
  emit('card-number-visibility', { id: props.card.id, isVisible: cardNumberVisible.value })
}

// 复制卡号逻辑 (仅在卡号全部展示时允许点击复制，写入纯卡号并提示)
const copyCardNumber = () => {
  if (!cardNumberVisible.value) return
  
  const num = props.card.cardNumber || ''
  if (!num) return
  
  // 去除所有空格，提取纯净卡号供方便粘贴
  const cleanNum = num.replace(/\s/g, '')
  
  navigator.clipboard.writeText(cleanNum).then(() => {
    ElMessage.success('卡号复制成功')
  }).catch(() => {
    // 降级兼容处理，确保 100% 成功
    const input = document.createElement('input')
    input.value = cleanNum
    document.body.appendChild(input)
    input.select()
    document.execCommand('copy')
    document.body.removeChild(input)
    ElMessage.success('卡号复制成功')
  })
}

// 切换 CVV 防窥
const toggleCvv = () => {
  cvvVisible.value = !cvvVisible.value
  emit('cvv-visibility', { id: props.card.id, isVisible: cvvVisible.value })
}

// 快捷设置年费已达标
const setAnnualFeeQualified = () => {
  emit('annual-fee-qualified', props.card.id)
  ElMessage.success(`已将 "${props.card.alias}" 标记为年费已达标`)
}

// 3D 倾斜数学计算
const handleMouseMove = (e) => {
  if (!cardContainerRef.value || isFlipped.value) return
  isHovering.value = true

  const rect = cardContainerRef.value.getBoundingClientRect()
  const width = rect.width
  const height = rect.height

  // 鼠标相对中心点坐标
  const mouseX = e.clientX - rect.left - width / 2
  const mouseY = e.clientY - rect.top - height / 2

  // 反光中心点映射 (高光跟随鼠标保留)
  sheenX.value = (mouseX / (width / 2)) * 100
  sheenY.value = (mouseY / (height / 2)) * 100
}

const handleMouseLeave = () => {
  isHovering.value = false
}

// 计算卡片行内倾斜样式 (采用立体 Z 轴凸起，无偏角，支持完美整体平整凸起)
const cardStyle = computed(() => {
  if (!isHovering.value || isFlipped.value) {
    return {
      transform: isFlipped.value ? 'rotateY(180deg)' : 'translateZ(0px)',
      transition: 'transform 0.45s cubic-bezier(0.25, 0.8, 0.25, 1)'
    }
  }
  // translateZ(45px) 带来极具景深感的向前平行立体拉近凸起，彻底移除 rotateX/rotateY/translateY 动作
  // 这将实现卡片完美、平整的“整体凸起”浮雕特效，彻底消除某一个角（如左上角）不凸起低陷的视觉问题
  return {
    transform: isFlipped.value ? 'rotateY(180deg) translateZ(45px)' : 'translateZ(45px)',
    '--sheen-x': `${sheenX.value}px`,
    '--sheen-y': `${sheenY.value}px`,
    transition: 'transform 0.3s cubic-bezier(0.25, 0.8, 0.25, 1)'
  }
})

// 暴露翻转方法供父组件右键联动翻转调用
defineExpose({
  flipCard
})

// 根据等级渲染科技主题类
const themeClass = computed(() => {
  const level = (props.card.level || '').toLowerCase()
  if (level.includes('钻石') || level.includes('diamond') || level.includes('black')) {
    return 'theme-diamond'
  } else if (level.includes('白金') || level.includes('platinum')) {
    return 'theme-platinum'
  } else if (level.includes('金卡') || level.includes('gold')) {
    return 'theme-gold'
  }
  return 'theme-classic'
})

// 智能识别卡组织品牌
const cardOrganization = computed(() => {
  // 1. 优先按卡等级与别名中的显式卡组织识别，对齐 Mac 端表现
  const level = (props.card.level || '').toLowerCase()
  const alias = (props.card.alias || '').toLowerCase()

  if (level.includes('visa') || alias.includes('visa') || level.includes('维萨')) return 'visa'
  if (level.includes('mastercard') || level.includes('master') || alias.includes('mastercard') || alias.includes('master') || level.includes('万事达')) return 'mastercard'
  if (level.includes('amex') || level.includes('american express') || alias.includes('amex') || level.includes('运通') || alias.includes('运通')) return 'amex'
  if (level.includes('unionpay') || level.includes('银联') || alias.includes('unionpay') || alias.includes('银联')) return 'unionpay'
  if (level.includes('jcb') || alias.includes('jcb')) return 'jcb'
  if (level.includes('discover') || level.includes('发现') || alias.includes('discover')) return 'discover'

  // 2. 未明确标注卡组织时，根据卡号 BIN 号正则识别
  const num = (props.card.cardNumber || '').replace(/\D/g, '')
  if (num) {
    if (num.startsWith('4')) return 'visa'
    if (/^5[1-5]/.test(num) || /^222[1-9]|^22[3-9]|^2[3-6]|^27[0-1]|^2720/.test(num)) return 'mastercard'
    if (num.startsWith('34') || num.startsWith('37')) return 'amex'
    if (num.startsWith('62')) return 'unionpay'
    if (num.startsWith('35')) return 'jcb'
    if (/^6011|^65/.test(num)) return 'discover'
  }

  return ''
})

// 格式化卡号，带眼球防窥
const formattedCardNumber = computed(() => {
  const num = props.card.cardNumber || ''
  if (!num) return ['****', '****', '****', '****']

  const clean = num.replace(/\s/g, '')
  let displayed = clean

  if (!cardNumberVisible.value) {
    // 隐藏中间部分，只留首尾各4位
    if (clean.length > 8) {
      const start = clean.slice(0, 4)
      const end = clean.slice(-4)
      const middle = '*'.repeat(clean.length - 8)
      displayed = start + middle + end
    } else {
      displayed = '*'.repeat(clean.length)
    }
  }

  // 每 4 位切片分组
  const segments = []
  for (let i = 0; i < displayed.length; i += 4) {
    segments.push(displayed.slice(i, i + 4))
  }
  return segments
})

// 额度格式化
const formatLimit = (limit) => {
  if (!limit) return '0.00'
  const num = parseFloat(limit)
  return isNaN(num) ? limit : num.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

// 格式化有效期
const formatValid = (valid) => {
  if (!valid) return 'MM/YY'
  // 原格式一般为 YYYY-MM，转为 MM/YY
  const parts = valid.split('-')
  if (parts.length === 2) {
    return `${parts[1]}/${parts[0].slice(2)}`
  }
  return valid
}

// 距离年费收取的天数
const getDaysCount = (dateStr) => {
  if (!dateStr) return 0
  const daysObj = getDaysFromNow(dateStr)
  return daysObj.days || 0
}

// 免息期计算
const calculateInterestFree = (billStr, dueStr) => {
  if (!billStr || !dueStr) return '-'
  const bill = parseInt(billStr)
  const due = parseInt(dueStr)
  if (isNaN(bill) || isNaN(due)) return '-'

  if (due > bill) {
    return due - bill
  } else {
    // 跨月，假设按 30 天计算
    return 30 - bill + due
  }
}
</script>

<style lang="scss" scoped>
.perspective-container {
  perspective: 1200px;
  width: 100%;
  height: 230px;
  position: relative;
  isolation: isolate;
}

.physics-card-wrapper {
  width: 100%;
  height: 230px;
  position: relative;
  transform-style: preserve-3d;
  transform-origin: center center;
  cursor: pointer;
  will-change: transform;
}

.physics-card-face {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  border-radius: 16px;
  padding: 20px;
  box-sizing: border-box;
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
  box-shadow: 0 12px 35px rgba(0, 0, 0, 0.45);
  border: 1px solid rgba(0, 242, 254, 0.15);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  overflow: hidden;
  transition: border-color 0.3s ease, box-shadow 0.4s cubic-bezier(0.25, 0.8, 0.25, 1);
  transform-style: flat;
}

/* ================= 正面卡片等级色彩方案 ================= */
.physics-card-front {
  background-size: 200% 200%;
  position: relative;
  z-index: 5;
  pointer-events: auto;

  /* 基础科技风 */
  &.theme-classic {
    background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #3b82f6 100%);
    border-color: rgba(59, 130, 246, 0.3);

    &:hover {
      box-shadow: 0 25px 50px rgba(0, 0, 0, 0.6), 0 0 22px rgba(59, 130, 246, 0.45) !important;
      border-color: rgba(59, 130, 246, 0.6) !important;
    }
  }

  /* 炫金卡 */
  &.theme-gold {
    background: linear-gradient(135deg, #1e1b4b 0%, #2e1065 50%, #d97706 100%);
    border-color: rgba(217, 119, 6, 0.3);

    .card-level-badge {
      background: rgba(217, 119, 6, 0.2);
      color: #fbbf24;
      border-color: rgba(217, 119, 6, 0.4);
    }

    &:hover {
      box-shadow: 0 25px 50px rgba(0, 0, 0, 0.6), 0 0 22px rgba(217, 119, 6, 0.45) !important;
      border-color: rgba(217, 119, 6, 0.6) !important;
    }
  }

  /* 白金卡 */
  &.theme-platinum {
    background: linear-gradient(135deg, #022c22 0%, #064e3b 50%, #0d9488 100%);
    border-color: rgba(13, 148, 136, 0.3);

    .card-level-badge {
      background: rgba(13, 148, 136, 0.2);
      color: #2dd4bf;
      border-color: rgba(13, 148, 136, 0.4);
    }

    &:hover {
      box-shadow: 0 25px 50px rgba(0, 0, 0, 0.6), 0 0 22px rgba(13, 148, 136, 0.45) !important;
      border-color: rgba(13, 148, 136, 0.6) !important;
    }
  }

  /* 奢华黑金/钻石卡 */
  &.theme-diamond {
    background: linear-gradient(135deg, #090d16 0%, #151a2d 60%, #da22ff 120%);
    border-color: rgba(218, 34, 255, 0.3);

    .card-level-badge {
      background: rgba(218, 34, 255, 0.2);
      color: #e0aaff;
      border-color: rgba(218, 34, 255, 0.4);
    }

    &:hover {
      box-shadow: 0 25px 50px rgba(0, 0, 0, 0.6), 0 0 22px rgba(218, 34, 255, 0.45) !important;
      border-color: rgba(218, 34, 255, 0.6) !important;
    }
  }

  /* 科技漫反射高光 Sheen */
  .shine-overlay {
    position: absolute;
    top: -60%;
    left: -60%;
    width: 220%;
    height: 220%;
    background: radial-gradient(circle, rgba(255, 255, 255, 0.12) 0%, rgba(255, 255, 255, 0) 65%);
    pointer-events: none;
    transform: translate(var(--sheen-x, 0px), var(--sheen-y, 0px));
    z-index: 2;
  }
}

/* ================= 头部排版 ================= */
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  z-index: 3;
  width: 100%;

  .bank-info {
    display: flex;
    flex-direction: column;

    .bank-name {
      font-size: 16px;
      font-weight: 700;
      letter-spacing: 0.5px;
      color: #fff;
      text-shadow: 0 2px 4px rgba(0, 0, 0, 0.4);
    }

    .country-tag {
      font-size: 10px;
      color: rgba(255, 255, 255, 0.5);
      margin-top: 2px;
      text-transform: uppercase;
    }
  }

  .card-logo {
    display: flex;
    align-items: center;
    gap: 8px;

    .card-level-badge {
      font-size: 11px;
      padding: 2px 8px;
      border-radius: 4px;
      background: rgba(255, 255, 255, 0.1);
      color: #fff;
      border: 1px solid rgba(255, 255, 255, 0.2);
      font-weight: 600;
      letter-spacing: 0.5px;
    }

    /* 像素级卡组织矢量 Logo 容器 */
    .card-brand-logo {
      display: flex;
      align-items: center;
      height: 20px;
      overflow: visible;

      .brand-svg {
        height: 100%;
        width: auto;
        display: block;

        &.visa {
          color: #0073e6 !important;
          fill: #0073e6 !important;
          height: 9.5px; /* 精调高度，等比例将宽度控制在约 28px，达成视觉最佳对齐 */
          width: auto;
          filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.45));
        }

        &.mastercard {
          height: 20px;
          filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.4));
        }
      }

      /* 维萨卡标：对齐 Mac 端的 serif 加粗斜体渐变字样 */
      .logo-visa {
        display: inline-flex;
        align-items: center;
        font-family: Georgia, 'Times New Roman', serif;
        font-size: 20px;
        font-weight: 800;
        font-style: italic;
        line-height: 1;
        letter-spacing: 0;
        white-space: nowrap;
        color: #00abff;
        background: linear-gradient(135deg, #2563eb 0%, #00c8ff 100%);
        background-clip: text;
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        filter: drop-shadow(0 0 4px rgba(37, 99, 235, 0.3));
      }

      /* 银联 (UnionPay) 纯 CSS 矢量 */
      .logo-unionpay {
        display: flex;
        position: relative;
        width: 48px;
        height: 20px;
        border-radius: 3px;
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.15);
        overflow: hidden;
        box-sizing: border-box;
        align-items: center;
        justify-content: center;
        padding: 2px;
        box-shadow: 0 2px 5px rgba(0, 0, 0, 0.3);
        
        .band {
          position: absolute;
          top: 0;
          bottom: 0;
          width: 35%;
          transform: skewX(-20deg);
          
          &.red-band {
            background: #ff2a3a;
            left: -5%;
          }
          &.blue-band {
            background: #003087;
            left: 30%;
          }
          &.cyan-band {
            background: #00a4e4;
            left: 65%;
          }
        }
        
        .unionpay-text {
          position: relative;
          z-index: 5;
          font-size: 8px;
          font-weight: 900;
          color: #fff;
          font-style: italic;
          text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8);
          letter-spacing: -0.3px;
        }
      }

      /* 运通 (AMEX) */
      .logo-amex {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 35px;
        height: 20px;
        background: #006fcf;
        border-radius: 3px;
        border: 1px solid #fff;
        box-sizing: border-box;
        box-shadow: 0 2px 5px rgba(0, 0, 0, 0.3);
        
        .amex-text {
          font-family: 'Arial Black', sans-serif;
          font-size: 8px;
          font-weight: 900;
          color: #fff;
          letter-spacing: -0.2px;
        }
      }

      /* JCB */
      .logo-jcb {
        display: flex;
        gap: 1px;
        align-items: center;
        justify-content: center;
        width: 38px;
        height: 20px;
        padding: 1.5px;
        box-sizing: border-box;
        background: rgba(255, 255, 255, 0.08);
        border-radius: 3px;
        border: 1px solid rgba(255, 255, 255, 0.15);
        box-shadow: 0 2px 5px rgba(0, 0, 0, 0.3);
        
        .jcb-block {
          flex: 1;
          height: 100%;
          border-radius: 1.5px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-family: 'Arial Black', sans-serif;
          font-size: 8px;
          font-weight: 900;
          color: #fff;
          
          &.j-block {
            background: #003580;
          }
          &.c-block {
            background: #d31115;
          }
          &.b-block {
            background: #008137;
          }
        }
      }

      /* Discover */
      .logo-discover {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 48px;
        height: 20px;
        background: #ff6a00;
        border-radius: 3px;
        border: 1px solid rgba(255, 255, 255, 0.2);
        box-sizing: border-box;
        box-shadow: 0 2px 5px rgba(0, 0, 0, 0.3);
        
        .discover-text {
          font-family: sans-serif;
          font-size: 8px;
          font-weight: 900;
          color: #fff;
          letter-spacing: -0.2px;
        }
      }
    }
  }
}

/* ================= 中部别名与卡号 ================= */
.card-body {
  margin-top: 15px;
  z-index: 3;

  .card-alias {
    font-size: 13px;
    color: rgba(255, 255, 255, 0.7);
    margin-bottom: 4px;
    font-weight: 500;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
  }

  .card-number-row {
    font-family: 'Courier New', Courier, monospace;
    font-size: 20px;
    font-weight: 700;
    color: #fff;
    letter-spacing: 1.5px;
    display: flex;
    align-items: center;
    gap: 12px;
    text-shadow: 0 2px 5px rgba(0, 0, 0, 0.6);

    .number-segments-wrapper {
      display: flex;
      gap: 10px;
      cursor: default;
      user-select: none;
      transition: all 0.25s ease;

      &.is-clickable {
        cursor: copy; /* 可点击复制样式 */

        &:hover {
          color: var(--el-color-primary) !important;
          text-shadow: 0 0 10px rgba(0, 242, 254, 0.6) !important;
          transform: scale(1.02);
        }
      }
    }

    .visibility-btn {
      color: rgba(255, 255, 255, 0.6) !important;
      padding: 0;
      height: auto;

      &:hover {
        color: #fff !important;
        transform: scale(1.1);
      }
    }
  }
}

/* ================= 底部额度与日期 ================= */
.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  z-index: 3;

  .label {
    font-size: 9px;
    color: rgba(255, 255, 255, 0.45);
    text-transform: uppercase;
    display: block;
    margin-bottom: 2px;
    letter-spacing: 0.5px;
  }

  .card-limit-info {
    .value {
      font-size: 19px;
      font-weight: 800;
      color: #fff;
      text-shadow: 0 2px 4px rgba(0, 0, 0, 0.4);
    }

    .shared-limit-badge {
      font-size: 9px;
      background: rgba(0, 242, 254, 0.25);
      color: #00f2fe;
      border: 1px solid rgba(0, 242, 254, 0.4);
      padding: 1px 4px;
      border-radius: 3px;
      margin-left: 6px;
      font-weight: 600;
      vertical-align: middle;
    }
  }

  .card-dates {
    display: flex;
    gap: 20px;
    text-align: right;

    .value {
      font-size: 13px;
      font-weight: 700;
      color: #fff;
      font-family: monospace;
    }

    .cvv-info {
      .value {
        letter-spacing: 1px;
        cursor: pointer;
        background: rgba(255, 255, 255, 0.1);
        padding: 0 4px;
        border-radius: 3px;

        &:hover {
          background: rgba(255, 255, 255, 0.2);
        }
      }
    }
  }
}

.physics-card-wrapper:hover {
  .physics-card-face {
    border-color: rgba(0, 242, 254, 0.4);
  }
}

.physics-card-wrapper.is-flipped {
  .physics-card-front {
    z-index: 1 !important;
    pointer-events: none !important; /* 翻转后禁止正面鼠标响应，保障背部完全响应交互 */
  }
  .physics-card-back {
    z-index: 10 !important;
    pointer-events: auto !important; /* 翻转后让背部拥有最高点击层级并响应交互 */
  }
}

/* ================= 背面卡片面板样式 ================= */
.physics-card-back {
  background: linear-gradient(135deg, rgba(13, 20, 41, 0.95) 0%, rgba(6, 9, 18, 0.98) 100%);
  transform: rotateY(180deg);
  border-color: rgba(0, 242, 254, 0.2);
  z-index: 1; /* 初始未翻转时降低层叠层级，不挡住正面 */
  pointer-events: none; /* 初始未翻转时禁用背部鼠标响应，彻底解决正面盲区 */

  .back-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    padding-bottom: 8px;

    .title {
      font-size: 13px;
      font-weight: 700;
      color: var(--el-color-primary);
      text-shadow: 0 0 8px rgba(0, 242, 254, 0.3);
    }

    .action-btn {
      background: rgba(255, 255, 255, 0.05) !important;
      border: 1px solid rgba(255, 255, 255, 0.1) !important;
      color: #fff !important;

      &:hover {
        border-color: var(--el-color-primary) !important;
        color: var(--el-color-primary) !important;
        background: rgba(0, 242, 254, 0.1) !important;
      }
    }
  }

  .back-content {
    flex: 1;
    margin: 12px 0;
    display: flex;
    flex-direction: column;
    gap: 10px;
    overflow-y: auto;
    scrollbar-width: none; /* 隐藏背部的滚动条 */

    &::-webkit-scrollbar {
      display: none;
    }

    .info-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 6px 12px;

      .info-item {
        display: flex;
        flex-direction: column;

        .label {
          font-size: 9px;
          color: var(--el-text-color-secondary);
          margin-bottom: 2px;
        }

        .value {
          font-size: 12px;
          font-weight: 600;
          color: #fff;

          &.highlight-text {
            color: var(--el-color-primary);
          }
          &.warning-text {
            color: var(--el-color-danger);
          }
          &.info-text {
            color: var(--el-color-success);
          }
        }
      }
    }

    .annual-fee-status {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 6px;
      font-size: 11px;
      background: rgba(255, 255, 255, 0.02);
      padding: 6px 8px;
      border-radius: 6px;
      border: 1px solid rgba(255, 255, 255, 0.04);

      .status-label {
        color: var(--el-text-color-secondary);
      }

      .clickable-tag {
        cursor: pointer;
        transition: all 0.2s ease;

        &:hover {
          filter: brightness(1.2);
          transform: translateY(-1px);
        }
      }

      .days-remaining {
        color: var(--el-text-color-secondary);
        margin-left: auto;
        font-size: 10px;

        .days-count {
          color: var(--el-color-danger);
          font-weight: 700;
        }
      }
    }

    .time-info {
      font-size: 9px;
      color: rgba(255, 255, 255, 0.4);
      display: flex;
      justify-content: space-between;
      border-bottom: 1px solid rgba(255, 255, 255, 0.03);
      padding-bottom: 6px;

      span {
        color: rgba(255, 255, 255, 0.7);
      }
    }

    .memo-section {
      display: flex;
      flex-direction: column;
      gap: 6px;

      .memo-item {
        font-size: 11px;
        line-height: 1.4;
        display: flex;
        align-items: flex-start;

        .memo-title {
          color: var(--el-color-primary);
          font-weight: 600;
          display: flex;
          align-items: center;
          gap: 2px;
          flex-shrink: 0;
        }

        .memo-desc {
          color: var(--el-text-color-regular);
          word-break: break-all;
        }
      }
    }
  }

  .back-footer {
    display: flex;
    justify-content: space-between;
    border-top: 1px solid rgba(255, 255, 255, 0.05);
    padding-top: 8px;

    :deep(.el-button) {
      padding: 6px 12px;
      font-size: 11px;
      height: 28px;
      border-radius: 4px;
    }
  }
}
</style>

<style lang="scss">
/* 全局样式：定制卡号复制 Tooltip 气泡 popper 的高质感霓虹发光样式 */
.el-popper.is-dark.copy-tooltip-popper {
  background: rgba(13, 20, 41, 0.9) !important;
  border: 1px solid rgba(0, 242, 254, 0.35) !important;
  box-shadow: 0 4px 15px rgba(0, 242, 254, 0.25) !important;
  backdrop-filter: blur(10px) !important;
  
  .el-popper__arrow::before {
    background: rgba(13, 20, 41, 0.9) !important;
    border-right-color: rgba(0, 242, 254, 0.35) !important;
    border-bottom-color: rgba(0, 242, 254, 0.35) !important;
  }
}
</style>
