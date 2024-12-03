<template>
  <el-dialog
    v-model="dialogVisible"
    title="确认删除"
    width="30%"
    :close-on-click-modal="false"
    draggable
  >
    <div class="delete-confirm-content">
      <el-alert
        type="warning"
        :closable="false"
        show-icon
      >
        <template #title>
          <span class="warning-title">
            <el-icon class="warning-icon"><Warning /></el-icon>
            确定要删除这张信用卡吗？
          </span>
        </template>
        <template #default>
          <div class="card-info">
            <p><strong>卡片名称：</strong>{{ cardInfo.cardName }}</p>
            <p><strong>发卡行：</strong>{{ cardInfo.bankName }}</p>
            <p><strong>卡片类型：</strong>{{ cardInfo.cardType }}</p>
          </div>
          <p class="warning-text">此操作将永久删除该信用卡信息，无法恢复！</p>
        </template>
      </el-alert>
    </div>

    <template #footer>
      <div class="dialog-footer">
        <el-button @click="handleCancel">取消</el-button>
        <el-button type="danger" @click="handleConfirm">
          <el-icon><Delete /></el-icon>
          确认删除
        </el-button>
      </div>
    </template>
  </el-dialog>
</template>

<script setup>
import { computed } from 'vue'
import { Delete, Warning } from '@element-plus/icons-vue'

const props = defineProps({
  visible: {
    type: Boolean,
    default: false
  },
  cardInfo: {
    type: Object,
    default: () => ({
      cardName: '',
      bankName: '',
      cardType: ''
    })
  }
})

const emit = defineEmits(['update:visible', 'confirm', 'cancel'])

const dialogVisible = computed({
  get: () => props.visible,
  set: (val) => emit('update:visible', val)
})

const handleConfirm = () => {
  emit('confirm')
  dialogVisible.value = false
}

const handleCancel = () => {
  emit('cancel')
  dialogVisible.value = false
}
</script>

<style scoped>
.delete-confirm-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.warning-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 16px;
  font-weight: bold;
}

.warning-icon {
  font-size: 20px;
  color: var(--el-color-warning);
}

.card-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin: 12px 0;
  padding: 12px;
  background-color: var(--el-fill-color-light);
  border-radius: 4px;
}

.warning-text {
  color: var(--el-color-danger);
  font-weight: bold;
  margin-top: 8px;
}

.dialog-footer {
  display: flex;
  justify-content: center;
  gap: 12px;
  padding-top: 20px;
}

:deep(.el-alert__title) {
  font-size: 16px;
}

:deep(.el-alert__content) {
  width: 100%;
}

:deep(.el-dialog__header) {
  display: none;
}
</style>
