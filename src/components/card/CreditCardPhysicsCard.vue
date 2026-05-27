<template>
  <div 
    class="perspective-container" 
    ref="cardContainerRef"
    @mousemove="handleMouseMove"
    @mouseleave="handleMouseLeave"
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
          </div>
        </div>

        <!-- 卡片中部：别名与卡号 -->
        <div class="card-body">
          <div class="card-alias">{{ card.alias || '未命名卡片' }}</div>
          <div class="card-number-row">
            <span class="number-segment" v-for="(seg, idx) in formattedCardNumber" :key="idx">
              {{ seg }}
            </span>
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
        
        <!-- 操作小按钮组 -->
        <div class="card-actions-overlay">
          <el-tooltip content="翻转查看详情" placement="top">
            <el-button circle size="small" class="action-btn" @click.stop="flipCard">
              <el-icon><Refresh /></el-icon>
            </el-button>
          </el-tooltip>
          <el-tooltip content="快捷编辑" placement="top">
            <el-button circle size="small" class="action-btn" @click.stop="$emit('edit', card)">
              <el-icon><Edit /></el-icon>
            </el-button>
          </el-tooltip>
        </div>
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
import { View, Hide, Refresh, Edit, Star, Notebook, Delete } from '@element-plus/icons-vue'
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
const rotateX = ref(0)
const rotateY = ref(0)
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
  
  // 计算最大倾斜 15 度
  rotateX.value = -(mouseY / (height / 2)) * 12
  rotateY.value = (mouseX / (width / 2)) * 12
  
  // 反光中心点映射
  sheenX.value = (mouseX / (width / 2)) * 100
  sheenY.value = (mouseY / (height / 2)) * 100
}

const handleMouseLeave = () => {
  isHovering.value = false
  rotateX.value = 0
  rotateY.value = 0
}

// 计算卡片行内倾斜样式
const cardStyle = computed(() => {
  if (!isHovering.value || isFlipped.value) {
    return {
      transform: isFlipped.value ? 'rotateY(180deg)' : 'rotateX(0deg) rotateY(0deg)',
      transition: 'transform 0.5s cubic-bezier(0.25, 0.8, 0.25, 1)'
    }
  }
  return {
    transform: `rotateX(${rotateX.value}deg) rotateY(${rotateY.value}deg)`,
    '--sheen-x': `${sheenX.value}px`,
    '--sheen-y': `${sheenY.value}px`,
    transition: 'transform 0.05s ease-out'
  }
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
  transform-style: preserve-3d;
  width: 100%;
}

.physics-card-wrapper {
  width: 100%;
  height: 230px;
  position: relative;
  transform-style: preserve-3d;
  cursor: pointer;
}

.physics-card-face {
  position: absolute;
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
  transition: border-color 0.3s ease;
}

/* ================= 正面卡片等级色彩方案 ================= */
.physics-card-front {
  background-size: 200% 200%;
  position: relative;
  
  /* 基础科技风 */
  &.theme-classic {
    background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #3b82f6 100%);
    border-color: rgba(59, 130, 246, 0.3);
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
  align-items: flex-start;
  z-index: 3;

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

/* ================= 物理卡片右侧快捷操作遮罩 ================= */
.card-actions-overlay {
  position: absolute;
  top: 15px;
  right: -50px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  transition: all 0.35s cubic-bezier(0.25, 0.8, 0.25, 1);
  z-index: 10;
  
  .action-btn {
    background: rgba(13, 20, 41, 0.75) !important;
    border: 1px solid rgba(0, 242, 254, 0.2) !important;
    color: var(--el-color-primary) !important;
    backdrop-filter: blur(5px);
    
    &:hover {
      border-color: var(--el-color-primary) !important;
      background: var(--el-color-primary) !important;
      color: #000 !important;
      box-shadow: 0 0 10px rgba(0, 242, 254, 0.4);
    }
  }
}

.physics-card-wrapper:hover {
  .card-actions-overlay {
    right: 15px;
  }
  
  .physics-card-face {
    border-color: rgba(0, 242, 254, 0.4);
  }
}

/* ================= 背面卡片面板样式 ================= */
.physics-card-back {
  background: linear-gradient(135deg, rgba(13, 20, 41, 0.95) 0%, rgba(6, 9, 18, 0.98) 100%);
  transform: rotateY(180deg);
  border-color: rgba(0, 242, 254, 0.2);
  z-index: 4;

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
