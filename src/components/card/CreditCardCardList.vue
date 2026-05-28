<template>
  <div class="card-list-container">
    <!-- 顶部多选快捷控制条 -->
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
      </div>
      <div class="actions-tips" v-if="selectedRows.length > 0">
        <span class="pulse-dot"></span>
        下方已激活批量操作工具栏
      </div>
    </div>

    <!-- 粒子渐变过渡的卡片网格 -->
    <div class="card-grid-scroll-wrapper">
      <div v-if="tableData.length === 0" class="empty-state">
        <div class="radar-scan">
          <div class="radar-line"></div>
        </div>
        <div class="empty-text">雷达未扫描到符合筛选条件的信用卡</div>
        <div class="empty-sub">请尝试调整上方查询条件或新增一张卡片</div>
      </div>

      <TransitionGroup
        name="card-flip-list"
        tag="div"
        class="card-grid"
        v-else
      >
        <div
          v-for="card in tableData"
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

    <!-- 右键快捷菜单 (太空舱半透明磨砂) -->
    <div
      v-show="contextMenuVisible"
      class="context-menu"
      :style="{ left: contextMenuX + 'px', top: contextMenuY + 'px' }"
    >
      <el-menu>
        <el-menu-item @click="handleContextMenuAction('flip')">
          <el-icon><Refresh /></el-icon>
          <span>3D翻转卡片 (查看背面)</span>
        </el-menu-item>
        <el-menu-item @click="handleContextMenuAction('edit')">
          <el-icon><Edit /></el-icon>
          <span>快捷编辑信用卡</span>
        </el-menu-item>
        <el-menu-item @click="handleContextMenuAction('delete')">
          <el-icon><Delete /></el-icon>
          <span>删除此信用卡</span>
        </el-menu-item>
        <el-menu-item @click="handleContextMenuAction('details')">
          <el-icon><View /></el-icon>
          <span>查看完整卡详情</span>
        </el-menu-item>
        <el-menu-item @click="handleContextMenuAction('qualified')" v-if="contextMenuRow && contextMenuRow.isQualified !== '3'">
          <el-icon><Check /></el-icon>
          <span>标记为年费已达标</span>
        </el-menu-item>
      </el-menu>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { Edit, Delete, View, Check, Refresh } from '@element-plus/icons-vue'
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
  padding: 10px 16px;
  margin-bottom: 12px;
  backdrop-filter: blur(10px);

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
    gap: 8px;
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
</style>
