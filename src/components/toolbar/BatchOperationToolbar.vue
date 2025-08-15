<template>
  <div class="batch-operation-toolbar" v-if="selectedCount > 0">
    <div class="toolbar-content">
      <div class="selection-info">
        <el-icon><Select /></el-icon>
        <span>已选择 {{ selectedCount }} 项</span>
        <el-button link type="primary" @click="$emit('clear-selection')">
          取消选择
        </el-button>
      </div>
      
      <div class="operation-buttons">
        <el-button 
          type="danger" 
          :icon="Delete" 
          @click="handleBatchDelete"
          :disabled="selectedCount === 0"
        >
          批量删除
        </el-button>
        
        <el-dropdown @command="handleBatchCommand" trigger="click">
          <el-button type="primary" :icon="Setting">
            批量操作
            <el-icon class="el-icon--right"><ArrowDown /></el-icon>
          </el-button>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="export">
                <el-icon><Download /></el-icon>
                导出选中项
              </el-dropdown-item>
              <el-dropdown-item command="mark-qualified" divided>
                <el-icon><CircleCheck /></el-icon>
                标记为达标
              </el-dropdown-item>
              <el-dropdown-item command="mark-unqualified">
                <el-icon><CircleClose /></el-icon>
                标记为未达标
              </el-dropdown-item>
              <el-dropdown-item command="update-annual-fee" divided>
                <el-icon><Money /></el-icon>
                批量更新年费
              </el-dropdown-item>
              <el-dropdown-item command="update-validity" >
                <el-icon><Calendar /></el-icon>
                批量更新有效期
              </el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
        
        <el-button 
          :icon="Select" 
          @click="$emit('toggle-select-all')"
        >
          {{ isAllSelected ? '取消全选' : '全选' }}
        </el-button>
      </div>
    </div>
  </div>
</template>

<script>
import { computed } from 'vue'
import { 
  Delete, 
  Setting, 
  ArrowDown, 
  Download, 
  CircleCheck, 
  Edit,
  Calendar,
  Clock,
  Select,
  CircleClose,
  Money
} from '@element-plus/icons-vue'
import { ElMessageBox, ElMessage } from 'element-plus'

export default {
  name: 'BatchOperationToolbar',
  components: {
    Delete,
    Setting,
    ArrowDown,
    Download,
    CircleCheck,
    Edit,
    Calendar,
    Clock,
    Select,
    CircleClose,
    Money
  },
  props: {
    selectedRows: {
      type: Array,
      default: () => []
    },
    totalCount: {
      type: Number,
      default: 0
    }
  },
  emits: [
    'batch-delete', 
    'batch-export', 
    'batch-update-status',
    'batch-update-annual-fee',
    'batch-update-validity',
    'clear-selection',
    'toggle-select-all'
  ],
  setup(props, { emit }) {
    const selectedCount = computed(() => props.selectedRows.length)
    
    const isAllSelected = computed(() => {
      return props.totalCount > 0 && selectedCount.value === props.totalCount
    })

    const handleBatchDelete = async () => {
      try {
        await ElMessageBox.confirm(
          `确定要删除选中的 ${selectedCount.value} 张信用卡吗？此操作不可撤销。`,
          '批量删除确认',
          {
            confirmButtonText: '删除',
            cancelButtonText: '取消',
            type: 'warning',
            confirmButtonClass: 'el-button--danger'
          }
        )
        
        emit('batch-delete', props.selectedRows)
        ElMessage.success(`成功删除 ${selectedCount.value} 张信用卡`)
      } catch {
        // 用户取消删除
      }
    }

    const handleBatchCommand = async (command) => {
      const count = selectedCount.value
      
      switch (command) {
        case 'export':
          emit('batch-export', props.selectedRows)
          ElMessage.success(`正在导出 ${count} 张信用卡数据...`)
          break
          
        case 'mark-qualified':
          try {
            await ElMessageBox.confirm(
              `确定要将选中的 ${count} 张信用卡标记为达标吗？`,
              '批量标记达标',
              { type: 'info' }
            )
            emit('batch-update-status', { rows: props.selectedRows, status: '1' })
            ElMessage.success(`成功标记 ${count} 张信用卡为达标`)
          } catch {
            // 用户取消
          }
          break
          
        case 'mark-unqualified':
          try {
            await ElMessageBox.confirm(
              `确定要将选中的 ${count} 张信用卡标记为未达标吗？`,
              '批量标记未达标',
              { type: 'info' }
            )
            emit('batch-update-status', { rows: props.selectedRows, status: '2' })
            ElMessage.success(`成功标记 ${count} 张信用卡为未达标`)
          } catch {
            // 用户取消
          }
          break
          
        case 'update-annual-fee':
          // 这里可以打开一个对话框来批量更新年费
          emit('batch-update-annual-fee', props.selectedRows)
          break
          
        case 'update-validity':
          // 这里可以打开一个对话框来批量更新有效期
          emit('batch-update-validity', props.selectedRows)
          break
      }
    }

    return {
      selectedCount,
      isAllSelected,
      handleBatchDelete,
      handleBatchCommand
    }
  }
}
</script>

<style lang="scss" scoped>
.batch-operation-toolbar {
  background: #f8f9fa;
  border: 1px solid #e9ecef;
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 16px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  transition: all 0.3s ease;

  .toolbar-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 12px;
  }

  .selection-info {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #606266;
    font-size: 14px;

    .el-icon {
      color: #409eff;
    }
  }

  .operation-buttons {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
  }
}

// 响应式设计
@media (max-width: 768px) {
  .batch-operation-toolbar {
    padding: 12px;
    
    .toolbar-content {
      flex-direction: column;
      align-items: stretch;
      gap: 12px;
    }
    
    .selection-info {
      justify-content: center;
    }
    
    .operation-buttons {
      justify-content: center;
      
      .el-button {
        flex: 1;
        min-width: 0;
      }
    }
  }
}

// 深色模式支持
@media (prefers-color-scheme: dark) {
  .batch-operation-toolbar {
    background: #2d3748;
    border-color: #4a5568;
    color: #e2e8f0;
    
    .selection-info {
      color: #a0aec0;
    }
  }
}
</style>
