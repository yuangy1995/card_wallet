<template>
  <el-dialog
    v-model="dialogVisible"
    title="删除确认"
    width="30%"
    :show-close="true"
    :append-to-body="true"
    destroy-on-close
    draggable
    @close="handleClose"
  >
    <div class="delete-confirm-content">
      <el-alert
        type="warning"
        :closable="false"
        show-icon
      >
        <template #title>
          <span class="warning-title">确定要删除该信用卡吗？此操作不可恢复！</span>
        </template>
      </el-alert>
      <div class="card-info" v-if="cardInfo">
        <div class="info-item">
          <span class="label">银行名称：</span>
          <span class="value">{{ cardInfo.bank || '-' }}</span>
        </div>
        <div class="info-item">
          <span class="label">卡片别名：</span>
          <span class="value">{{ cardInfo.alias || '-' }}</span>
        </div>
        <div class="info-item">
          <span class="label">卡片级别：</span>
          <span class="value">{{ cardInfo.level || '-' }}</span>
        </div>
        <div class="info-item">
          <span class="label">信用额度：</span>
          <span class="value">{{ formatLimit(cardInfo.limit) || '-' }}</span>
        </div>
      </div>
      <div class="no-card-info" v-else>
        <el-empty description="无卡片信息" />
      </div>
    </div>
    <template #footer>
      <span class="dialog-footer">
        <el-button @click="handleCancel">取消</el-button>
        <el-button
          type="danger"
          :disabled="!cardInfo"
          @click="handleConfirm"
        >
          确认删除
        </el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script setup>
import { computed } from 'vue'
import { Delete, Warning } from '@element-plus/icons-vue'

// 定义 props
const props = defineProps({
  visible: {
    type: Boolean,
    required: true
  },
  cardInfo: {
    type: Object,
    default: () => null
  }
})

// 定义 emits
const emit = defineEmits(['update:visible', 'confirm', 'cancel'])

// 对话框可见性
const dialogVisible = computed({
  get: () => props.visible,
  set: (value) => emit('update:visible', value)
})

// 格式化额度显示
const formatLimit = (value) => {
  if (!value) return ''
  return value.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

// 处理确认
const handleConfirm = () => {
  emit('confirm')
}

// 处理取消
const handleCancel = () => {
  emit('cancel')
}

// 对话框关闭后的处理
const handleClose = () => {
  emit('update:visible', false)
}
</script>

<style lang="scss" scoped>
.delete-confirm-content {
  padding: 10px 0;

  .warning-title {
    font-weight: bold;
    font-size: 16px;
  }

  .card-info {
    margin-top: 20px;
    padding: 15px;
    border: 1px solid #ebeef5;
    border-radius: 4px;
    background-color: #f5f7fa;

    .info-item {
      margin-bottom: 10px;
      line-height: 24px;

      &:last-child {
        margin-bottom: 0;
      }

      .label {
        display: inline-block;
        width: 80px;
        color: #606266;
      }

      .value {
        color: #303133;
        font-weight: 500;
      }
    }
  }

  .no-card-info {
    margin-top: 20px;
  }
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}
</style>
