<template>
  <div class="credit-card-table">
    <el-table 
      :data="tableData" 
      style="width: 100%" 
      border
      height="calc(100vh - 250px)"
      @row-contextmenu="handleContextMenu"
    >
      <el-table-column type="index" label="序号" width="60" align="center" fixed />
      <el-table-column prop="country" label="国家" width="130" align="center" fixed />
      <el-table-column prop="bank" label="银行" width="150" align="center" fixed />
      <el-table-column prop="alias" label="别名" width="200" align="center" fixed />
      <el-table-column prop="level" label="等级" width="110" align="center" />
      <el-table-column prop="type" label="币种" width="150" align="center" />
      <el-table-column prop="annualFee" label="年费" width="90" align="center" />
      <el-table-column prop="cardNumber" label="💳 卡号" width="200" align="center">
        <template #default="{ row }">
          <secure-field 
            :value="row.cardNumber"
            :mask-start="4"
            :mask-end="12"
            type="cardNumber"
            :id="row.id"
            @visibility-change="handleVisibilityChange"
          />
        </template>
      </el-table-column>
      <el-table-column prop="valid" label="有效期" width="80" align="center" />
      <el-table-column prop="cvv" label="🔒 CVV" width="120" align="center">
        <template #default="{ row }">
          <secure-field 
            :value="row.cvv"
            :mask-all="true"
            type="cvv"
            :id="row.id"
            @visibility-change="handleVisibilityChange"
          />
        </template>
      </el-table-column>
      <el-table-column prop="limit" label="额度" width="100" align="center" />
      <el-table-column prop="nextAnnualFeeCollectionTime" label="下次年费收取时间" width="150" align="center" />
      <el-table-column prop="lastTime" label="最后提额时间" width="170" align="center" />
      <el-table-column prop="isQualified" label="年费达标" width="100" align="center">
        <template #default="{ row }">
          <el-tag v-if="row.isQualified === '1'" type="success">已达标</el-tag>
          <el-tag v-if="row.isQualified === '2'" type="danger">未达标</el-tag>
          <el-tag v-if="row.isQualified === '3'" type="info">终免年费</el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="equity" label="🎁 权益" width="200" align="center" show-overflow-tooltip />
      <el-table-column prop="remark" label="📌 备注" width="200" align="center" show-overflow-tooltip />
    </el-table>

    <!-- 右键菜单 -->
    <div 
      v-show="contextMenuVisible"
      class="context-menu"
      :style="{ left: contextMenuX + 'px', top: contextMenuY + 'px' }"
    >
      <el-menu>
        <el-menu-item @click="handleContextMenuAction('edit')">
          <el-icon><Edit /></el-icon>
          <span>编辑</span>
        </el-menu-item>
        <el-menu-item @click="handleContextMenuAction('details')">
          <el-icon><View /></el-icon>
          <span>详情</span>
        </el-menu-item>
        <el-menu-item @click="handleContextMenuAction('delete')">
          <el-icon><Delete /></el-icon>
          <span>删除</span>
        </el-menu-item>
      </el-menu>
    </div>
  </div>
</template>

<script>
import SecureField from '../common/SecureField.vue'
import { ElMessageBox } from 'element-plus'
import { Edit, View, Delete } from '@element-plus/icons-vue'
import { ref } from 'vue'

export default {
  name: 'CreditCardTable',
  components: {
    SecureField,
    Edit,
    View,
    Delete
  },
  props: {
    tableData: {
      type: Array,
      required: true
    }
  },
  emits: ['edit', 'delete', 'card-number-visibility', 'cvv-visibility', 'view-details'],
  setup(props, { emit }) {
    const contextMenuVisible = ref(false)
    const contextMenuX = ref(0)
    const contextMenuY = ref(0)
    const selectedRow = ref(null)

    // 处理右键菜单显示
    const handleContextMenu = (row, column, event) => {
      event.preventDefault()
      selectedRow.value = row
      contextMenuX.value = event.clientX
      contextMenuY.value = event.clientY
      contextMenuVisible.value = true

      // 点击其他地方时关闭菜单
      const closeMenu = () => {
        contextMenuVisible.value = false
        document.removeEventListener('click', closeMenu)
      }
      document.addEventListener('click', closeMenu)
    }

    // 处理右键菜单动作
    const handleContextMenuAction = (action) => {
      if (!selectedRow.value) return

      switch (action) {
        case 'edit':
          emit('edit', selectedRow.value)
          break
        case 'details':
          emit('view-details', selectedRow.value)
          break
        case 'delete':
          ElMessageBox.confirm(
            '确定要删除这张信用卡吗？',
            '警告',
            {
              confirmButtonText: '确定',
              cancelButtonText: '取消',
              type: 'warning',
            }
          )
            .then(() => {
              emit('delete', selectedRow.value)
            })
            .catch(() => {})
          break
      }
      
      contextMenuVisible.value = false
    }

    // 处理可见性变化
    const handleVisibilityChange = ({ id, isVisible, type }) => {
      if (type === 'cardNumber') {
        emit('card-number-visibility', { id, isVisible })
      } else if (type === 'cvv') {
        emit('cvv-visibility', { id, isVisible })
      }
    }

    return {
      handleContextMenu,
      handleContextMenuAction,
      handleVisibilityChange,
      contextMenuVisible,
      contextMenuX,
      contextMenuY
    }
  }
}
</script>

<style lang="scss" scoped>
.credit-card-table {
  width: 100%;
  position: relative;
}

.context-menu {
  position: fixed;
  z-index: 3000;
  background: white;
  border-radius: 4px;
  box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
  
  .el-menu {
    border: none;
    padding: 4px 0;
    min-width: 120px;
  }

  .el-menu-item {
    height: 36px;
    line-height: 36px;
    padding: 0 16px;
    display: flex;
    align-items: center;
    gap: 8px;
    
    &:hover {
      background-color: var(--el-menu-hover-bg-color);
    }

    .el-icon {
      margin-right: 4px;
      font-size: 16px;
    }
  }
}

:deep(.el-table) {
  --el-table-border-color: var(--el-border-color-lighter);
  --el-table-border: 1px solid var(--el-table-border-color);
  --el-table-text-color: var(--el-text-color-regular);
  --el-table-header-text-color: var(--el-text-color-secondary);
  --el-table-row-hover-bg-color: var(--el-fill-color-light);
  
  th {
    background-color: var(--el-fill-color-light);
    font-weight: bold;
  }
  
  td {
    padding: 8px 0;
  }
}
</style>
