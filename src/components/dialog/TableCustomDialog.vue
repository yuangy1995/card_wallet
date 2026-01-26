<template>
  <el-dialog
    v-model="dialogVisible"
    title="选择表格显示内容"
    width="30%"
    draggable
    destroy-on-close
    :before-close="handleClose"
  >
    <div class="dialog-content">
      <div class="button-group">
        <el-button size="small" @click="selectAll">全选</el-button>
        <el-button size="small" @click="unselectAll">取消全选</el-button>
        <el-button size="small" @click="resetDefault">恢复默认</el-button>
      </div>
      <div class="checkbox-container">
        <el-checkbox
          v-for="item in localColumns"
          :key="item.value"
          v-model="item.checked"
          :label="item.label"
        >
          {{ item.label }}
        </el-checkbox>
      </div>
    </div>

    <template #footer>
      <span class="dialog-footer">
        <el-button @click="handleCancel">取消</el-button>
        <el-button type="primary" @click="handleConfirm">确定</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script>
import { ref, computed, watch, inject } from 'vue'
import { creditCardOptions } from '../../config/creditCardOptions'
import { useAutoLock } from '@/composables/useAutoLock'

export default {
  name: 'TableCustomDialog',
  props: {
    visible: {
      type: Boolean,
      default: false
    },
    columns: {
      type: Array,
      required: true
    }
  },
  emits: ['update:visible', 'confirm'],
  setup(props, { emit }) {
    const providedAutoLock = inject('autoLock', null)
    const { isLocked } = providedAutoLock || useAutoLock()
    
    const dialogVisible = computed({
      get: () => props.visible,
      set: (value) => emit('update:visible', value)
    })

    const localColumns = ref([])

    // 监听 visible 和 columns 属性的变化
    watch(() => props.visible, (newValue) => {
      if (newValue) {
        // 当对话框打开时，复制传入的列配置
        localColumns.value = [...props.columns]
      }
    })

    watch(isLocked, (locked) => {
      if (locked && dialogVisible.value) {
        dialogVisible.value = false
      }
    })

    const selectAll = () => {
      localColumns.value = localColumns.value.map(col => ({ ...col, checked: true }))
    }

    const unselectAll = () => {
      localColumns.value = localColumns.value.map(col => ({ ...col, checked: false }))
    }

    const resetDefault = () => {
      localColumns.value = creditCardOptions.tableCustomData.map(col => ({
        ...col,
        checked: col.defaultShow
      }))
    }

    const handleConfirm = () => {
      emit('confirm', localColumns.value)
      dialogVisible.value = false
    }

    const handleCancel = () => {
      dialogVisible.value = false
    }

    const handleClose = () => {
      dialogVisible.value = false
    }

    return {
      dialogVisible,
      localColumns,
      selectAll,
      unselectAll,
      resetDefault,
      handleConfirm,
      handleCancel,
      handleClose
    }
  }
}
</script>

<style lang="scss" scoped>
.dialog-content {
  max-height: 60vh;
  overflow-y: auto;

  .button-group {
    margin-bottom: 16px;
    display: flex;
    gap: 8px;
  }

  .checkbox-container {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    gap: 12px;

    .el-checkbox {
      margin-right: 0;
    }
  }
}

:deep(.el-dialog__body) {
  padding: 20px;
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
</style>
