<template>
  <el-dialog
    v-model="dialogVisible"
    width="32%"
    :close-on-click-modal="false"
    draggable
  >
    <div class="delete-confirm-content">
      <div class="confirm-header">
        <el-icon class="warning-icon"><Warning /></el-icon>
        <span class="warning-title">确定要删除这张卡片吗？</span>
      </div>
      
      <div class="card-details">
        <div class="info-row">
          <span class="info-label">卡片名称：</span>
          <span class="info-value">{{ cardInfo.cardName }}</span>
        </div>
        <div class="info-row">
          <span class="info-label">发卡行：</span>
          <span class="info-value">{{ cardInfo.bankName }}</span>
        </div>
        <div class="info-row">
          <span class="info-label">发行地区：</span>
          <span class="info-value">{{ cardInfo.country }}</span>
        </div>
        <div class="info-row">
          <span class="info-label">卡片等级：</span>
          <span class="info-value">{{ cardInfo.level }}</span>
        </div>
        <div class="info-row" v-if="cardInfo.limit">
          <span class="info-label">卡片额度：</span>
          <span class="info-value">{{ cardInfo.limit }}</span>
        </div>
      </div>

      <p class="warning-text">此操作将永久删除该卡片信息，无法恢复！</p>
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
import { computed, inject, watch } from 'vue'
import { Delete, Warning } from '@element-plus/icons-vue'
import { useAutoLock } from '@/composables/useAutoLock'

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
      limit: '',
      level: ''
    })
  }
})

const emit = defineEmits(['update:visible', 'confirm', 'cancel'])
const providedAutoLock = inject('autoLock', null)
const { isLocked } = providedAutoLock || useAutoLock()

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

watch(isLocked, (locked) => {
  if (locked && dialogVisible.value) {
    dialogVisible.value = false
  }
})
</script>

<style scoped>
.delete-confirm-content {
  /* 亮色模式配置变量 */
  --del-title-color: #d46b08;
  --del-card-bg: #f8fafc;
  --del-label-color: #64748b;
  --del-value-color: #1e293b;
  --del-warning-text: #ef4444;
  
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 8px 4px;
}

/* 适配暗色模式变量 */
.dark .delete-confirm-content,
:deep(.dark) .delete-confirm-content {
  --del-title-color: #f1c40f;
  --del-card-bg: rgba(255, 255, 255, 0.02);
  --del-label-color: #9aa5b1;
  --del-value-color: #f1f2f6;
  --del-warning-text: #ff0844;
}

.confirm-header {
  display: flex;
  align-items: center;
  gap: 10px;
}

.warning-icon {
  font-size: 24px;
  color: var(--del-title-color);
  flex-shrink: 0;
}

.warning-title {
  font-size: 17px;
  font-weight: 600;
  color: var(--del-title-color);
  letter-spacing: 0.5px;
}

.card-details {
  background-color: var(--del-card-bg);
  border-radius: 8px;
  padding: 16px 20px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  border: none !important; /* 去除多余的内部边框 */
}

.info-row {
  display: flex;
  justify-content: flex-start;
  align-items: center;
  font-size: 14px;
  line-height: 1.6;
}

.info-label {
  color: var(--del-label-color);
  width: 80px;
  flex-shrink: 0;
  font-weight: 500;
}

.info-value {
  color: var(--del-value-color);
  font-weight: 600;
}

.warning-text {
  color: var(--del-warning-text);
  font-weight: 700;
  font-size: 13px;
  margin: 0;
  padding-left: 4px;
}

.dialog-footer {
  display: flex;
  justify-content: center;
  gap: 16px;
  padding-top: 12px;
}

:deep(.el-dialog__header) {
  display: none;
}
</style>
