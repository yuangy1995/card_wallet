<template>
  <el-dialog 
    v-model="dialogVisible" 
    title="选择排序方式" 
    width="30%" 
    draggable
  >
    <el-radio-group v-model="sortValue">
      <el-radio label="1">按额度升序</el-radio>
      <el-radio label="2">按额度降序</el-radio>
      <el-radio label="3">按年费升序</el-radio>
      <el-radio label="4">按年费降序</el-radio>
      <el-radio label="5">按账单日升序</el-radio>
      <el-radio label="6">按账单日降序</el-radio>
      <el-radio label="7">按还款日升序</el-radio>
      <el-radio label="8">按还款日降序</el-radio>
    </el-radio-group>

    <template #footer>
      <span class="dialog-footer">
        <el-button @click="handleCancel">取消</el-button>
        <el-button type="primary" @click="handleConfirm">确定</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script>
import { computed } from 'vue'

export default {
  name: 'SortDialog',
  props: {
    visible: {
      type: Boolean,
      required: true
    },
    modelValue: {
      type: String,
      default: '1'
    }
  },
  emits: ['update:visible', 'update:modelValue', 'confirm', 'cancel'],
  setup(props, { emit }) {
    // 对话框可见性
    const dialogVisible = computed({
      get: () => props.visible,
      set: (value) => emit('update:visible', value)
    })

    // 排序值
    const sortValue = computed({
      get: () => props.modelValue,
      set: (value) => emit('update:modelValue', value)
    })

    // 处理确认
    const handleConfirm = () => {
      emit('confirm', sortValue.value)
      dialogVisible.value = false
    }

    // 处理取消
    const handleCancel = () => {
      emit('cancel')
      dialogVisible.value = false
    }

    return {
      dialogVisible,
      sortValue,
      handleConfirm,
      handleCancel
    }
  }
}
</script>

<style scoped>
.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

:deep(.el-radio-group) {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

:deep(.el-radio) {
  margin-right: 0;
  height: auto;
  white-space: normal;
  line-height: 1.5;
}
</style>
