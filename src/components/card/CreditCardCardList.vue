<template>
  <div class="card-list-container">
    <!-- 顶部多选快捷控制条 (含批量与分组排序集成控制线) -->
    <div class="card-list-actions" v-if="tableData.length > 0">
      <div class="selection-status">
        <el-checkbox
          :model-value="isAllSelected"
          :indeterminate="isIndeterminate"
          @change="handleSelectAllChange"
          class="tech-checkbox"
        >
          全选所有卡片 (已选择 {{ selectedRows.length }} / {{ tableData.length }})
        </el-checkbox>
        <div class="actions-tips" v-if="selectedRows.length > 0">
          <span class="pulse-dot"></span>
          已激活批量操作
        </div>
      </div>

      <!-- 分组与排序筛选器 (太空舱半透明磨砂风格) -->
      <div class="card-group-sort-filters">
        <!-- 一键折叠/展开太空舱按钮组 (分组状态下动态显示) -->
        <div class="group-collapse-actions" v-if="groupBy !== 'none'">
          <el-button
            v-if="showCollapseAll"
            type="info"
            size="small"
            @click="collapseAllGroups"
            class="collapse-action-btn"
          >
            <el-icon><ArrowUp /></el-icon>一键折叠
          </el-button>
          <el-button
            v-if="showExpandAll"
            type="primary"
            size="small"
            @click="expandAllGroups"
            class="collapse-action-btn expand-btn"
          >
            <el-icon><ArrowDown /></el-icon>一键展开
          </el-button>
        </div>

        <div class="filter-item">
          <span class="filter-label">分组：</span>
          <el-select v-model="groupBy" size="small" class="tech-select" placeholder="无分组">
            <el-option label="无分组" value="none" />
            <el-option label="按发卡行" value="bank" />
            <el-option label="按地区" value="country" />
            <el-option label="按卡组织" value="organization" />
          </el-select>
        </div>
        <div class="filter-item">
          <span class="filter-label">排序：</span>
          <el-select v-model="sortBy" size="small" class="tech-select" placeholder="默认排序">
            <el-option label="默认排序" value="default" />
            <el-option label="额度：从高到低" value="limit-desc" />
            <el-option label="额度：从低到高" value="limit-asc" />
            <el-option label="下次年费时间" value="annualFee" />
            <el-option label="最近修改时间" value="modifyTime" />
          </el-select>
        </div>
      </div>
    </div>

    <!-- 粒子渐变过渡的卡片网格 -->
    <div class="card-grid-scroll-wrapper">
      <div v-if="tableData.length === 0" class="empty-state">
        <div class="radar-scan">
          <div class="radar-line"></div>
        </div>
        <div class="empty-text">雷达未扫描到符合筛选条件的银行卡</div>
        <div class="empty-sub">请尝试调整上方查询条件或新增一张卡片</div>
      </div>
      
      <!-- 根据分组渲染卡片 -->
      <div v-else class="card-groups-wrapper">
        <div 
          v-for="group in groupedCards" 
          :key="group.key"
          class="card-group-container"
        >
          <!-- 分组头部 (高档太空舱半透明磨砂药丸，支持点击折叠) -->
          <div 
            class="card-group-header" 
            v-if="groupBy !== 'none'"
            @click="toggleGroup(group.key)"
            :class="{ 'is-collapsed': isGroupCollapsed(group.key) }"
            style="cursor: pointer;"
          >
            <div class="group-title-wrapper">
              <el-icon class="collapse-arrow" :class="{ 'is-collapsed': isGroupCollapsed(group.key) }">
                <ArrowDown />
              </el-icon>
              <el-icon class="group-icon-lead">
                <component :is="getGroupIcon(groupBy)" />
              </el-icon>
              <span class="group-title">{{ group.title }}</span>
              <span class="group-badge">{{ group.cards.length }}张</span>
            </div>
            <div class="group-limit-pill">
              本组信用额度 <span class="limit-value">¥{{ group.limitSum.toLocaleString('zh-CN', { minimumFractionDigits: 0, maximumFractionDigits: 0 }) }}</span>
            </div>
          </div>

          <!-- 分组内的卡片网格 (支持折叠与收缩过渡动画) -->
          <el-collapse-transition>
            <div v-show="!isGroupCollapsed(group.key)">
              <TransitionGroup 
                name="card-flip-list" 
                tag="div" 
                class="card-grid"
              >
                <div 
                  v-for="card in group.cards" 
                  :key="card.id" 
                  class="card-item-wrapper"
                  :class="{ 'is-selected': isCardSelected(card.id) }"
                  @contextmenu.prevent="handleContextMenu(card, $event)"
                >
                  <!-- 悬浮精细 Checkbox (用于批量操作) -->
                  <div class="card-selector-overlay">
                    <el-checkbox
                      :model-value="isCardSelected(card.id)"
                      @change="(checked) => handleCardSelect(card, checked)"
                      class="card-checkbox"
                    />
                  </div>

                  <!-- 物理 3D 悬浮卡片 -->
                  <CreditCardPhysicsCard
                    :card="card"
                    :ref="el => setCardRef(card.id, el)"
                    @edit="(c) => $emit('edit', c)"
                    @delete="(c) => $emit('delete', c)"
                    @view-details="(c) => $emit('view-details', c)"
                    @annual-fee-qualified="(id) => $emit('annual-fee-qualified', id)"
                    @card-number-visibility="(data) => $emit('card-number-visibility', data)"
                    @cvv-visibility="(data) => $emit('cvv-visibility', data)"
                  />
                </div>
              </TransitionGroup>
            </div>
          </el-collapse-transition>
        </div>
      </div>
    </div>

    <!-- 右键快捷菜单 (太空舱半透明磨砂) -->
    <div
      v-show="contextMenuVisible"
      class="context-menu"
      :style="{ left: contextMenuX + 'px', top: contextMenuY + 'px' }"
    >
      <el-menu>
        <el-menu-item index="flip" @click="handleContextMenuAction('flip')">
          <el-icon><Refresh /></el-icon>
          <span>3D翻转卡片 (查看背面)</span>
        </el-menu-item>
        <el-menu-item index="edit" @click="handleContextMenuAction('edit')">
          <el-icon><Edit /></el-icon>
          <span>快捷编辑卡片</span>
        </el-menu-item>
        <el-menu-item index="delete" @click="handleContextMenuAction('delete')">
          <el-icon><Delete /></el-icon>
          <span>删除此卡片</span>
        </el-menu-item>
        <el-menu-item index="details" @click="handleContextMenuAction('details')">
          <el-icon><View /></el-icon>
          <span>查看完整卡详情</span>
        </el-menu-item>
        <el-menu-item index="qualified" @click="handleContextMenuAction('qualified')" v-if="contextMenuRow && contextMenuRow.cardCategory !== 'debit' && contextMenuRow.isQualified !== '3'">
          <el-icon><Check /></el-icon>
          <span>确认本周期年费已达标</span>
        </el-menu-item>
      </el-menu>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { Edit, Delete, View, Check, Refresh, OfficeBuilding, Location, CreditCard, ArrowDown, ArrowUp } from '@element-plus/icons-vue'
import CreditCardPhysicsCard from './CreditCardPhysicsCard.vue'

const props = defineProps({
  tableData: {
    type: Array,
    required: true
  },
  selectedRows: {
    type: Array,
    default: () => []
  }
})

const emit = defineEmits([
  'edit',
  'delete',
  'view-details',
  'annual-fee-qualified',
  'card-number-visibility',
  'cvv-visibility',
  'selection-change'
])

// 分组与排序控制状态（默认按照发卡行 bank 分组，对齐 Mac 端原生面板）
const groupBy = ref(localStorage.getItem('creditCardGroupMode') || 'bank')
const sortBy = ref(localStorage.getItem('creditCardSortMode') || 'default')

// 监听分组与排序方式，存入 localStorage
watch(groupBy, (newVal) => {
  localStorage.setItem('creditCardGroupMode', newVal)
})
watch(sortBy, (newVal) => {
  localStorage.setItem('creditCardSortMode', newVal)
})

// 分组折叠缓存持久化逻辑
const collapsedGroups = ref(JSON.parse(localStorage.getItem('creditCardCollapsedGroups') || '{}'))

const isGroupCollapsed = (groupKey) => {
  return !!collapsedGroups.value[groupKey]
}

const toggleGroup = (groupKey) => {
  collapsedGroups.value[groupKey] = !collapsedGroups.value[groupKey]
  localStorage.setItem('creditCardCollapsedGroups', JSON.stringify(collapsedGroups.value))
}

// 是否有当前视图未折叠的分组 (只要有当前未折叠的组，就显示 "一键折叠")
const showCollapseAll = computed(() => {
  if (groupBy.value === 'none' || groupedCards.value.length === 0) return false
  return groupedCards.value.some(g => !isGroupCollapsed(g.key))
})

// 是否有当前视图已折叠的分组 (只要有当前已折叠的组，就显示 "一键展开")
const showExpandAll = computed(() => {
  if (groupBy.value === 'none' || groupedCards.value.length === 0) return false
  return groupedCards.value.some(g => isGroupCollapsed(g.key))
})

// 一键折叠所有当前显示的分组
const collapseAllGroups = () => {
  groupedCards.value.forEach(g => {
    collapsedGroups.value[g.key] = true
  })
  localStorage.setItem('creditCardCollapsedGroups', JSON.stringify(collapsedGroups.value))
}

// 一键展开所有当前显示的分组
const expandAllGroups = () => {
  groupedCards.value.forEach(g => {
    collapsedGroups.value[g.key] = false
  })
  localStorage.setItem('creditCardCollapsedGroups', JSON.stringify(collapsedGroups.value))
}

// 根据分组获取图标
const getGroupIcon = (type) => {
  if (type === 'bank') return OfficeBuilding
  if (type === 'country') return Location
  if (type === 'organization') return CreditCard
  return null
}

// 智能捕获卡片品牌（用于分组）
const getCardOrganization = (card) => {
  const num = (card.cardNumber || '').replace(/\D/g, '')
  if (num) {
    if (num.startsWith('4')) return 'visa'
    if (/^5[1-5]/.test(num) || /^222[1-9]|^22[3-9]|^2[3-6]|^27[0-1]|^2720/.test(num)) return 'mastercard'
    if (num.startsWith('34') || num.startsWith('37')) return 'amex'
    if (num.startsWith('62')) return 'unionpay'
    if (num.startsWith('35')) return 'jcb'
    if (/^6011|^65/.test(num)) return 'discover'
  }
  const level = (card.level || '').toLowerCase()
  const alias = (card.alias || '').toLowerCase()
  if (level.includes('visa') || alias.includes('visa') || level.includes('维萨')) return 'visa'
  if (level.includes('mastercard') || level.includes('master') || alias.includes('mastercard') || alias.includes('master') || level.includes('万事达')) return 'mastercard'
  if (level.includes('amex') || level.includes('american express') || alias.includes('amex') || level.includes('运通') || alias.includes('运通')) return 'amex'
  if (level.includes('unionpay') || level.includes('银联') || alias.includes('unionpay') || alias.includes('银联')) return 'unionpay'
  if (level.includes('jcb') || alias.includes('jcb')) return 'jcb'
  if (level.includes('discover') || level.includes('发现') || alias.includes('discover')) return 'discover'
  return 'other'
}

// 获取卡组织美观名称
const getCardOrganizationDisplayName = (org) => {
  const mapping = {
    'visa': 'VISA 卡',
    'mastercard': 'MasterCard 卡',
    'unionpay': '银联 (UnionPay) 卡',
    'amex': '美国运通 (AMEX) 卡',
    'jcb': 'JCB 国际卡',
    'discover': 'Discover 发现卡',
    'other': '其他卡组织卡'
  }
  return mapping[org] || '其他卡组织卡'
}

// 共享授信计算机制（同一银行共享额度合并取最大值，独立额度累加）
const calculateLimitSum = (cards) => {
  let total = 0
  const sharedPools = {}
  
  cards.forEach(card => {
    const limit = parseFloat(card.limit || 0)
    if (isNaN(limit)) return

    if (card.cardCategory === 'debit') return

    if (card.isSharedLimit) {
      const bankKey = (card.bank || 'unknown').trim()
      sharedPools[bankKey] = Math.max(sharedPools[bankKey] || 0, limit)
    } else {
      total += limit
    }
  })

  // 加总所有的共享额度最大授信
  Object.values(sharedPools).forEach(limit => {
    total += limit
  })

  return total
}

// 计算属性：对数据源执行多维分组与高级排序
const groupedCards = computed(() => {
  let sortedData = [...props.tableData]
  
  // 1. 进行高级条件排序
  if (sortBy.value === 'limit-desc') {
    sortedData.sort((a, b) => parseFloat(b.limit || 0) - parseFloat(a.limit || 0))
  } else if (sortBy.value === 'limit-asc') {
    sortedData.sort((a, b) => parseFloat(a.limit || 0) - parseFloat(b.limit || 0))
  } else if (sortBy.value === 'annualFee') {
    sortedData.sort((a, b) => {
      const timeA = a.nextAnnualFeeCollectionTime ? parseInt(a.nextAnnualFeeCollectionTime) : 9999999999999
      const timeB = b.nextAnnualFeeCollectionTime ? parseInt(b.nextAnnualFeeCollectionTime) : 9999999999999
      return timeA - timeB
    })
  } else if (sortBy.value === 'modifyTime') {
    sortedData.sort((a, b) => {
      const timeA = a.lastModifyTime ? parseInt(a.lastModifyTime) : 0
      const timeB = b.lastModifyTime ? parseInt(b.lastModifyTime) : 0
      return timeB - timeA
    })
  }

  // 2. 如果不分组，直接作为单一整体返回
  if (groupBy.value === 'none') {
    return [{
      key: 'all',
      title: '所有银行卡',
      cards: sortedData,
      limitSum: calculateLimitSum(sortedData)
    }]
  }

  // 3. 执行分组聚合
  const groups = {}
  sortedData.forEach(card => {
    let key = ''
    let title = ''

    if (groupBy.value === 'bank') {
      key = (card.bank || '未知发卡行').trim()
      title = card.bank || '未知发卡行'
    } else if (groupBy.value === 'country') {
      key = (card.country || '其他地区').trim()
      title = card.country || '其他地区'
    } else if (groupBy.value === 'organization') {
      key = getCardOrganization(card)
      title = getCardOrganizationDisplayName(key)
    }

    if (!groups[key]) {
      groups[key] = {
        key,
        title,
        cards: [],
        limitSum: 0
      }
    }
    groups[key].cards.push(card)
  })

  // 4. 计算每个分组的共享后实际授信总额并转换为数组
  const groupList = Object.values(groups)
  groupList.forEach(g => {
    g.limitSum = calculateLimitSum(g.cards)
  })

  // 5. 对分组本身进行逻辑排序（卡数多的排前面，或按拼音排序）
  groupList.sort((a, b) => b.cards.length - a.cards.length || a.title.localeCompare(b.title, 'zh-CN'))

  return groupList
})

// 动态收集子卡片组件实例以支持联动操作
const cardRefs = ref({})
const setCardRef = (id, el) => {
  if (el) {
    cardRefs.value[id] = el
  } else {
    delete cardRefs.value[id]
  }
}

// 右键菜单逻辑
const contextMenuVisible = ref(false)
const contextMenuX = ref(0)
const contextMenuY = ref(0)
const contextMenuRow = ref(null)

const handleContextMenu = (card, event) => {
  contextMenuRow.value = card
  contextMenuX.value = event.clientX
  contextMenuY.value = event.clientY
  contextMenuVisible.value = true

  // 绑定全局点击事件，点击空白处自动关闭右键菜单
  document.addEventListener('click', closeContextMenu)
}

const closeContextMenu = () => {
  contextMenuVisible.value = false
  document.removeEventListener('click', closeContextMenu)
}

const handleContextMenuAction = (action) => {
  if (!contextMenuRow.value) return

  if (action === 'flip') {
    const cardInst = cardRefs.value[contextMenuRow.value.id]
    if (cardInst && cardInst.flipCard) {
      cardInst.flipCard()
    }
  } else if (action === 'edit') {
    emit('edit', contextMenuRow.value)
  } else if (action === 'delete') {
    emit('delete', contextMenuRow.value)
  } else if (action === 'details') {
    emit('view-details', contextMenuRow.value)
  } else if (action === 'qualified') {
    emit('annual-fee-qualified', contextMenuRow.value.id)
  }

  closeContextMenu()
}

// 判断单张卡片是否已勾选
const isCardSelected = (id) => {
  return props.selectedRows.some(item => item.id === id)
}

// 勾选单张卡片
const handleCardSelect = (card, checked) => {
  let newSelection = [...props.selectedRows]
  if (checked) {
    if (!isCardSelected(card.id)) {
      newSelection.push(card)
    }
  } else {
    newSelection = newSelection.filter(item => item.id !== card.id)
  }
  emit('selection-change', newSelection)
}

// 全选/半选状态计算
const isAllSelected = computed(() => {
  if (props.tableData.length === 0) return false
  return props.tableData.every(card => isCardSelected(card.id))
})

const isIndeterminate = computed(() => {
  if (props.selectedRows.length === 0) return false
  return props.selectedRows.length < props.tableData.length
})

// 快捷全选/全不选变化
const handleSelectAllChange = (checked) => {
  let newSelection = []
  if (checked) {
    newSelection = [...props.tableData]
  }
  emit('selection-change', newSelection)
}

// 监听外界数据变化（当数据在表格外被删除时，同步清理选中状态）
watch(() => props.tableData, (newData) => {
  const newSelection = props.selectedRows.filter(selected =>
    newData.some(card => card.id === selected.id)
  )
  if (newSelection.length !== props.selectedRows.length) {
    emit('selection-change', newSelection)
  }
}, { deep: true })

// 暴露清理勾选的方法（配合 App.vue 的 clearSelection 触发，主要用于向后兼容）
const clearSelection = () => {
  emit('selection-change', [])
}

defineExpose({
  clearSelection
})
</script>

<style lang="scss" scoped>
.card-list-container {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-height: 0;
  width: 100%;
  position: relative;
}

/* ================= 顶部多选快捷控制栏 ================= */
.card-list-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: rgba(13, 20, 41, 0.4);
  border: 1px solid rgba(0, 242, 254, 0.15);
  border-radius: 8px;
  padding: 8px 16px;
  margin-bottom: 12px;
  backdrop-filter: blur(10px);
  gap: 16px;
  flex-wrap: wrap; /* 自适应折行，防折断 */

  .selection-status {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;

    .tech-checkbox {
      :deep(.el-checkbox__label) {
        color: var(--el-text-color-regular) !important;
        font-size: 12px;
        font-weight: 500;
      }

      :deep(.el-checkbox__input.is-checked .el-checkbox__inner) {
        background-color: var(--el-color-primary) !important;
        border-color: var(--el-color-primary) !important;
      }
    }

    .actions-tips {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 11px;
      color: var(--el-color-primary);
      text-shadow: 0 0 8px rgba(0, 242, 254, 0.3);
      font-weight: 600;

      .pulse-dot {
        width: 6px;
        height: 6px;
        background: var(--el-color-primary);
        border-radius: 50%;
        box-shadow: 0 0 0 0 rgba(0, 242, 254, 0.7);
        animation: pulse 1.6s infinite;
      }
    }
  }
}

/* ================= 分组与排序筛选器样式 ================= */
.card-group-sort-filters {
  display: flex;
  gap: 16px;
  align-items: center;
  margin-left: auto;
  flex-wrap: wrap;

  /* 一键折叠/展开太空舱按钮样式 */
  .group-collapse-actions {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-right: 6px;

    .collapse-action-btn {
      font-size: 11.5px;
      font-weight: 600;
      color: rgba(255, 255, 255, 0.8) !important;
      background: rgba(13, 20, 41, 0.6) !important;
      border: 1px solid rgba(0, 242, 254, 0.25) !important;
      border-radius: 6px;
      padding: 0 10px;
      height: 24px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 4px;
      cursor: pointer;
      transition: all 0.25s cubic-bezier(0.25, 0.8, 0.25, 1);

      .el-icon {
        font-size: 11px;
      }

      &:hover {
        color: var(--el-color-primary) !important;
        border-color: var(--el-color-primary) !important;
        background: rgba(0, 242, 254, 0.08) !important;
        box-shadow: 0 0 10px rgba(0, 242, 254, 0.35) !important;
        transform: translateY(-0.5px);
      }

      &.expand-btn {
        border-color: rgba(0, 242, 254, 0.3) !important;

        &:hover {
          color: var(--el-color-primary) !important;
          border-color: var(--el-color-primary) !important;
          background: rgba(0, 242, 254, 0.12) !important;
          box-shadow: 0 0 12px rgba(0, 242, 254, 0.45) !important;
        }
      }
    }
  }

  .filter-item {
    display: flex;
    align-items: center;
    gap: 6px;

    .filter-label {
      font-size: 12px;
      color: var(--el-text-color-regular);
      font-weight: 500;
    }

    .tech-select {
      width: 130px;

      :deep(.el-input__wrapper) {
        background-color: rgba(13, 20, 41, 0.75) !important;
        border: 1px solid rgba(0, 242, 254, 0.2) !important;
        box-shadow: none !important;
        border-radius: 6px;
        padding: 0 8px;
        transition: all 0.3s ease;

        &:hover,
        &.is-focus {
          border-color: var(--el-color-primary) !important;
          box-shadow: 0 0 8px rgba(0, 242, 254, 0.3) !important;
        }
      }

      :deep(.el-input__inner) {
        color: #fff !important;
        font-size: 12px;
      }
      
      :deep(.el-select__caret) {
        color: rgba(255, 255, 255, 0.6) !important;
      }
    }
  }
}

/* ================= 物理卡片分组容器与头部 (Mac端 1:1 像素级复现) ================= */
.card-groups-wrapper {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.card-group-container {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.card-group-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: rgba(13, 20, 41, 0.55);
  border: 1px solid rgba(0, 242, 254, 0.15);
  border-left: 4px solid var(--el-color-primary);
  border-radius: 8px;
  padding: 10px 18px;
  backdrop-filter: blur(15px);
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.25);
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
  user-select: none;

  &:hover {
    border-color: rgba(0, 242, 254, 0.35);
    background: rgba(13, 20, 41, 0.65);
    box-shadow: 0 4px 20px rgba(0, 242, 254, 0.15);

    .collapse-arrow {
      color: var(--el-color-primary);
    }
  }

  &.is-collapsed {
    border-left: 1px solid rgba(0, 242, 254, 0.15) !important;
    opacity: 0.85;

    &:hover {
      opacity: 1;
      border-left-color: rgba(0, 242, 254, 0.35) !important;
    }
  }

  .collapse-arrow {
    font-size: 11px;
    color: rgba(255, 255, 255, 0.4);
    transition: transform 0.3s cubic-bezier(0.25, 0.8, 0.25, 1), color 0.3s ease;
    margin-right: 2px;

    &.is-collapsed {
      transform: rotate(-90deg); /* 折叠时优雅指向右侧 */
    }
  }

  .group-title-wrapper {
    display: flex;
    align-items: center;
    gap: 8px;

    .group-icon-lead {
      color: var(--el-color-primary);
      font-size: 15px;
      display: flex;
      align-items: center;
      filter: drop-shadow(0 0 5px rgba(0, 242, 254, 0.5));
    }

    .group-title {
      font-size: 13.5px;
      font-weight: 700;
      color: #fff;
      letter-spacing: 0.5px;
      text-shadow: 0 1px 3px rgba(0, 0, 0, 0.5);
    }

    .group-badge {
      font-size: 10px;
      background: rgba(0, 242, 254, 0.15);
      color: var(--el-color-primary);
      border: 1px solid rgba(0, 242, 254, 0.3);
      padding: 1px 6px;
      border-radius: 10px;
      font-weight: 600;
    }
  }

  .group-limit-pill {
    font-size: 10.5px;
    color: var(--el-text-color-regular);
    background: rgba(16, 185, 129, 0.1);
    border: 1.5px solid rgba(16, 185, 129, 0.25);
    color: #10b981;
    padding: 3px 12px;
    border-radius: 20px;
    font-weight: 500;
    box-shadow: 0 2px 8px rgba(16, 185, 129, 0.15);
    display: flex;
    align-items: center;
    gap: 4px;
    letter-spacing: 0.5px;

    .limit-value {
      font-weight: 700;
      font-size: 11.5px;
      text-shadow: 0 0 5px rgba(16, 185, 129, 0.4);
    }
  }
}

/* ================= 滚动容器与自适应网格 ================= */
.card-grid-scroll-wrapper {
  flex: 1;
  overflow-y: auto;
  padding-right: 4px;

  /* 科技风个性化滚动条，仅在大屏下显示 */
  &::-webkit-scrollbar {
    width: 6px;
  }
  &::-webkit-scrollbar-track {
    background: rgba(10, 15, 32, 0.2);
  }
  &::-webkit-scrollbar-thumb {
    background: rgba(0, 242, 254, 0.2);
    border-radius: 4px;
    &:hover {
      background: var(--el-color-primary);
    }
  }
}

.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 20px;
  width: 100%;
  padding: 12px 12px 24px 12px; /* 四周预留间距，彻底消除悬浮多选框被边缘裁剪遮挡的问题 */
}

/* ================= 单个卡片外部容器 (含多选框覆层) ================= */
.card-item-wrapper {
  position: relative;
  border-radius: 16px;
  overflow: visible;
  transition: all 0.3s ease;

  /* 悬浮多选 Checkbox */
  .card-selector-overlay {
    position: absolute;
    top: -8px;
    left: -8px;
    z-index: 10;
    opacity: 0;
    transform: scale(0.8);
    pointer-events: none;
    transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);

    .card-checkbox {
      margin-right: 0;

      :deep(.el-checkbox__inner) {
        width: 22px;
        height: 22px;
        background-color: rgba(13, 20, 41, 0.9) !important;
        border: 1.5px solid rgba(0, 242, 254, 0.4) !important;
        border-radius: 50% !important; /* 变成精美的圆形选择框 */
        box-shadow: 0 4px 10px rgba(0, 0, 0, 0.5);
        transition: all 0.2s ease;

        &::after {
          height: 10px;
          width: 5px;
          left: 7px;
          top: 3px;
          border-color: #0b0f19 !important; /* 勾选后为深色调，清晰易读 */
          border-width: 2.5px !important;
        }
      }

      :deep(.el-checkbox__input.is-checked .el-checkbox__inner) {
        background-color: var(--el-color-primary) !important;
        border-color: var(--el-color-primary) !important;
        box-shadow: 0 0 10px rgba(0, 242, 254, 0.6);
      }

      &:hover :deep(.el-checkbox__inner) {
        border-color: var(--el-color-primary) !important;
        transform: scale(1.05);
      }
    }
  }

  /* 悬停与选中样式 */
  &:hover {
    .card-selector-overlay {
      opacity: 1;
      transform: scale(1);
      pointer-events: auto;
    }
  }

  &.is-selected {
    .card-selector-overlay {
      opacity: 1;
      transform: scale(1);
      pointer-events: auto;
    }

    &::after {
      content: '';
      position: absolute;
      inset: -2px;
      border-radius: 18px;
      border: 2px dashed var(--el-color-primary);
      pointer-events: none;
      animation: selectBorderRotate 4s linear infinite;
      z-index: 1;
    }
  }
}

/* ================= 缺省空状态 (粒子雷达扫描) ================= */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 350px;
  text-align: center;
  background: rgba(13, 20, 41, 0.2);
  border: 1px dashed rgba(0, 242, 254, 0.2);
  border-radius: 16px;
  backdrop-filter: blur(5px);
  padding: 40px;

  .radar-scan {
    width: 80px;
    height: 80px;
    border-radius: 50%;
    border: 1px solid rgba(0, 242, 254, 0.3);
    position: relative;
    background: radial-gradient(circle, rgba(0, 242, 254, 0.05) 0%, transparent 70%);
    margin-bottom: 24px;
    overflow: hidden;

    &::before {
      content: '';
      position: absolute;
      inset: 15px;
      border-radius: 50%;
      border: 1px dashed rgba(0, 242, 254, 0.2);
    }

    .radar-line {
      position: absolute;
      top: 50%;
      left: 50%;
      width: 50%;
      height: 2px;
      background: linear-gradient(to right, var(--el-color-primary), transparent);
      transform-origin: left center;
      animation: radarRotate 3s linear infinite;
    }
  }

  .empty-text {
    font-size: 15px;
    font-weight: 700;
    color: var(--el-color-primary);
    text-shadow: 0 0 8px rgba(0, 242, 254, 0.3);
    margin-bottom: 8px;
  }

  .empty-sub {
    font-size: 12px;
    color: var(--el-text-color-secondary);
  }
}

/* ================= 动画特效定义 ================= */
@keyframes pulse {
  0% {
    box-shadow: 0 0 0 0 rgba(0, 242, 254, 0.7);
  }
  70% {
    box-shadow: 0 0 0 6px rgba(0, 242, 254, 0);
  }
  100% {
    box-shadow: 0 0 0 0 rgba(0, 242, 254, 0);
  }
}

@keyframes radarRotate {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

@keyframes selectBorderRotate {
  100% {
    border-color: rgba(218, 34, 255, 0.8);
  }
}

/* FLIP 布局重排与删除、添加动画 (Vue 3 TransitionGroup) */
.card-flip-list-enter-active,
.card-flip-list-leave-active {
  transition: all 0.5s cubic-bezier(0.25, 0.8, 0.25, 1);
}

.card-flip-list-enter-from {
  opacity: 0;
  transform: scale(0.8) translateY(30px);
}

.card-flip-list-leave-to {
  opacity: 0;
  transform: scale(0.8) translateY(-30px);
  position: absolute; /* 必须设置 absolute 才能让其他兄弟元素流畅地重排 (Flip) */
}

.card-flip-list-move {
  transition: transform 0.5s cubic-bezier(0.25, 0.8, 0.25, 1);
}

/* 右键悬浮菜单 - 科技感半透明圆角 */
.context-menu {
  position: fixed;
  z-index: 1000;
  background: rgba(10, 15, 32, 0.94) !important;
  backdrop-filter: blur(15px);
  border: 1px solid var(--el-color-primary) !important;
  border-radius: 8px !important;
  box-shadow: 0 10px 30px rgba(0, 242, 254, 0.3) !important;
  overflow: hidden;

  :deep(.el-menu) {
    background: transparent !important;
    border: none !important;
  }

  :deep(.el-menu-item) {
    color: var(--el-text-color-regular) !important;
    height: 38px !important;
    line-height: 38px !important;
    font-size: 13px !important;
    transition: background-color 0.2s ease, color 0.2s ease !important;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 16px !important;

    &:hover {
      background: rgba(0, 242, 254, 0.15) !important;
      color: var(--el-color-primary) !important;

      .el-icon {
        color: var(--el-color-primary) !important;
        transform: scale(1.15);
      }
    }

    .el-icon {
      color: var(--el-text-color-secondary) !important;
      transition: transform 0.2s ease, color 0.2s ease !important;
      margin-right: 0 !important;
      font-size: 14px;
    }
  }
}

/* ==========================================================================
   ☀️ 亮色模式（白色主题）卡片列表组件高拟真极简视觉重塑
   ========================================================================== */
:global(html:not(.dark)) {
  .card-list-actions {
    background: rgba(255, 255, 255, 0.72) !important;
    border: 1px solid rgba(86, 114, 190, 0.16) !important;
    box-shadow: 0 4px 12px rgba(86, 114, 190, 0.04) !important;
    backdrop-filter: blur(10px) !important;

    .selection-status {
      .tech-checkbox {
        :deep(.el-checkbox__label) {
          color: #334155 !important;
        }
      }

      .actions-tips {
        text-shadow: none !important;
        color: #008fa0 !important;

        .pulse-dot {
          background: #008fa0 !important;
          box-shadow: 0 0 0 0 rgba(0, 143, 160, 0.4) !important;
        }
      }
    }
  }

  /* 一键折叠/展开亮色实体按钮重塑 */
  .group-collapse-actions {
    .collapse-action-btn {
      color: #334155 !important;
      background: rgba(255, 255, 255, 0.95) !important;
      border: 1px solid rgba(86, 114, 190, 0.24) !important;
      box-shadow: 0 1px 3px rgba(86, 114, 190, 0.06) !important;

      &:hover {
        color: #008fa0 !important;
        border-color: #008fa0 !important;
        background: rgba(0, 143, 160, 0.06) !important;
        box-shadow: 0 0 10px rgba(0, 143, 160, 0.15) !important;
      }

      &.expand-btn {
        border-color: rgba(86, 114, 190, 0.28) !important;

        &:hover {
          color: #008fa0 !important;
          border-color: #008fa0 !important;
          background: rgba(0, 143, 160, 0.08) !important;
          box-shadow: 0 0 12px rgba(0, 143, 160, 0.2) !important;
        }
      }
    }
  }

  /* 下拉筛选选择框亮色重塑 */
  .card-group-sort-filters {
    .filter-item {
      .filter-label {
        color: #334155 !important;
      }
    }

    .tech-select {
      :deep(.el-input__wrapper) {
        background-color: rgba(255, 255, 255, 0.9) !important;
        border: 1px solid rgba(86, 114, 190, 0.22) !important;
        box-shadow: none !important;

        &:hover,
        &.is-focus {
          border-color: #008fa0 !important;
          box-shadow: 0 0 8px rgba(0, 143, 160, 0.12) !important;
        }
      }

      :deep(.el-input__inner) {
        color: #334155 !important;
      }

      :deep(.el-select__caret) {
        color: rgba(51, 65, 85, 0.6) !important;
      }
    }
  }

  /* 分组头部晶莹白卡片重塑 */
  .card-group-header {
    background: rgba(255, 255, 255, 0.8) !important;
    border: 1px solid rgba(86, 114, 190, 0.15) !important;
    border-left: 4px solid #008fa0 !important;
    box-shadow: 0 4px 15px rgba(86, 114, 190, 0.04) !important;

    &:hover {
      border-color: rgba(86, 114, 190, 0.3) !important;
      background: rgba(255, 255, 255, 0.95) !important;
      box-shadow: 0 6px 20px rgba(86, 114, 190, 0.08) !important;
    }

    &.is-collapsed {
      border-left-color: #94a3b8 !important;
    }

    .collapse-arrow {
      color: rgba(100, 116, 139, 0.6) !important;
    }

    .group-title-wrapper {
      .group-icon-lead {
        color: #008fa0 !important;
        filter: drop-shadow(0 1px 2px rgba(0, 143, 160, 0.15)) !important;
      }

      .group-title {
        color: #1e293b !important;
        text-shadow: none !important;
      }

      .group-badge {
        background: rgba(0, 143, 160, 0.08) !important;
        color: #008fa0 !important;
        border: 1px solid rgba(0, 143, 160, 0.2) !important;
      }
    }

    .group-limit-pill {
      background: rgba(16, 185, 129, 0.06) !important;
      border: 1px solid rgba(16, 185, 129, 0.2) !important;
      color: #10b981 !important;
      box-shadow: 0 1px 4px rgba(16, 185, 129, 0.03) !important;
    }
  }
}
</style>
