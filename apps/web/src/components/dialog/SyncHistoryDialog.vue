<template>
  <el-dialog
    :model-value="visible"
    title="云同步记录"
    width="760px"
    top="4vh"
    modal-class="sync-history-overlay"
    class="sync-history-dialog"
    @update:model-value="$emit('update:visible', $event)"
  >
    <div class="sync-history-body">
      <div class="sync-current-card" :class="`is-${syncStatus.type || 'info'}`">
        <div>
          <div class="sync-current-title">{{ syncStatus.isSyncing ? '正在同步' : syncStateText }}</div>
          <div class="sync-current-desc">{{ syncStatus.message || 'WebDAV 云端同步' }}</div>
          <div v-if="syncStatus.isSyncing && currentProgress.total > 0" class="sync-progress-stack">
            <el-progress
              :percentage="currentStepPercentage"
              :stroke-width="5"
              :show-text="false"
            />
            <el-progress
              v-if="currentProgress.totalBytes > 0"
              :percentage="currentBytePercentage"
              :stroke-width="4"
              :show-text="false"
              color="#409eff"
            />
            <div v-if="currentByteText" class="sync-byte-text">{{ currentByteText }}</div>
          </div>
        </div>
        <div class="sync-current-actions">
          <el-tag v-if="syncStatus.isSyncing" type="info">已用时 {{ formatDuration(syncElapsedMs) }}</el-tag>
          <el-tag v-else-if="syncStatus.lastDurationMs" type="info">上次耗时 {{ formatDuration(syncStatus.lastDurationMs) }}</el-tag>
          <el-button
            type="primary"
            size="small"
            :loading="syncStatus.isSyncing"
            :disabled="syncStatus.isSyncing"
            @click="$emit('retry')"
          >
            重新执行同步
          </el-button>
        </div>
      </div>

      <el-empty v-if="history.length === 0" description="暂无同步记录" />
      <el-collapse v-else class="sync-history-list">
        <el-collapse-item
          v-for="entry in history"
          :key="entry.id"
          :name="entry.id"
        >
          <template #title>
            <div class="history-title">
              <span class="history-dot" :class="`is-${entry.status}`"></span>
              <span class="history-time">{{ formatDateTime(entry.finishedAt) }}</span>
              <span class="history-message">{{ entry.message }}</span>
              <el-tag size="small" effect="plain">本机 {{ entry.localChanges?.length || 0 }}</el-tag>
              <el-tag size="small" effect="plain" type="success">云端 {{ entry.remoteChanges?.length || 0 }}</el-tag>
              <span class="history-duration">{{ formatDuration(entry.durationMs || 0) }}</span>
            </div>
          </template>

          <div class="history-detail">
            <div class="detail-block">
              <div class="detail-title">同步文件</div>
              <div class="file-row">
                <span>上传</span>
                <code>{{ entry.uploadedFile || '无' }}</code>
              </div>
              <div v-if="entry.downloadedFiles?.length">
                <div v-for="file in entry.downloadedFiles" :key="file" class="file-row">
                  <span>读取</span>
                  <code>{{ file }}</code>
                </div>
              </div>
              <div v-else class="file-row">
                <span>读取</span>
                <code>无，已跳过下载解析</code>
              </div>
            </div>

            <ChangeList title="本机变更" :changes="entry.localChanges || []" />
            <ChangeList title="云端变更" :changes="entry.remoteChanges || []" />
          </div>
        </el-collapse-item>
      </el-collapse>
    </div>
  </el-dialog>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  visible: { type: Boolean, default: false },
  history: { type: Array, default: () => [] },
  syncStatus: { type: Object, default: () => ({}) },
  syncCountdownNow: { type: Number, default: 0 }
})

defineEmits(['update:visible', 'retry'])

const syncElapsedMs = computed(() => {
  if (!props.syncStatus?.isSyncing) return 0
  if (props.syncStatus.syncStartedAt) {
    return Math.max(0, props.syncCountdownNow - props.syncStatus.syncStartedAt)
  }
  return props.syncStatus.elapsedMs || 0
})

const syncStateText = computed(() => {
  if (props.syncStatus?.type === 'success') return '同步成功'
  if (['warning', 'danger', 'error'].includes(props.syncStatus?.type)) return '需要处理'
  if (props.syncStatus?.pending) return '等待同步'
  return '同步空闲'
})

const currentProgress = computed(() => props.syncStatus?.syncProgress || {})

const currentStepPercentage = computed(() => {
  const step = Number(currentProgress.value.step || 0)
  const total = Number(currentProgress.value.total || 0)
  if (total <= 0) return 0
  return Math.round(Math.min(1, Math.max(0, step / total)) * 100)
})

const currentBytePercentage = computed(() => {
  const transferred = Number(currentProgress.value.transferredBytes || 0)
  const total = Number(currentProgress.value.totalBytes || 0)
  if (total <= 0) return 0
  return Math.round(Math.min(1, Math.max(0, transferred / total)) * 100)
})

const formatBytes = (bytes) => {
  const normalized = Math.max(0, Number(bytes || 0))
  if (normalized < 1024) return `${normalized} B`
  const units = ['KB', 'MB', 'GB']
  let value = normalized / 1024
  let unitIndex = 0
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024
    unitIndex += 1
  }
  return `${value.toFixed(1)} ${units[unitIndex]}`
}

const currentByteText = computed(() => {
  const total = Number(currentProgress.value.totalBytes || 0)
  const transferred = Number(currentProgress.value.transferredBytes || 0)
  if (total <= 0) return ''
  const prefix = String(currentProgress.value.phase || '').includes('上传') ? '已上传' : '已下载'
  return `${prefix} ${formatBytes(transferred)} / ${formatBytes(total)}`
})

const formatDuration = (milliseconds) => {
  const seconds = Math.max(0, Math.ceil(Number(milliseconds || 0) / 1000))
  if (seconds >= 3600) return `${Math.floor(seconds / 3600)}小时${Math.floor((seconds % 3600) / 60)}分`
  if (seconds >= 60) return `${Math.floor(seconds / 60)}分${String(seconds % 60).padStart(2, '0')}秒`
  return `${seconds}秒`
}

const formatDateTime = (value) => {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value || '-'
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  })
}
</script>

<script>
export default {
  components: {
    ChangeList: {
      props: {
        title: { type: String, required: true },
        changes: { type: Array, default: () => [] }
      },
      template: `
        <div class="detail-block">
          <div class="detail-title">{{ title }}</div>
          <div v-if="changes.length === 0" class="empty-change">无</div>
          <div v-for="change in changes" :key="change.cardId + change.kind" class="change-card">
            <div class="change-card-title">
              <span class="change-kind">{{ kindText(change.kind) }}</span>
              <strong>{{ change.cardName }}</strong>
              <span class="change-field-count">{{ change.fields?.length || 0 }} 项明细</span>
            </div>
            <div v-if="!change.fields?.length" class="empty-change">该旧记录未保存字段明细</div>
            <div v-for="field in change.fields || []" :key="field.label + field.oldValue + field.newValue" class="field-row">
              <span class="field-label">{{ field.label }}</span>
              <span class="field-value">{{ field.oldValue || '空' }}</span>
              <span class="field-arrow">→</span>
              <span class="field-value is-new">{{ field.newValue || '空' }}</span>
            </div>
          </div>
        </div>
      `,
      methods: {
        kindText(kind) {
          return {
            added: '新增',
            modified: '修改',
            deleted: '删除'
          }[kind] || kind || '变更'
        }
      }
    }
  }
}
</script>

<style scoped>
.sync-history-body {
  display: flex;
  flex-direction: column;
  gap: 14px;
  height: 100%;
  min-height: 0;
  overflow: hidden;
}

.sync-current-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 14px 16px;
  border: 1px solid rgba(0, 188, 212, 0.22);
  border-radius: 10px;
  background: rgba(0, 188, 212, 0.08);
  flex: 0 0 auto;
}

.sync-current-title {
  font-size: 15px;
  font-weight: 700;
  color: var(--el-text-color-primary);
}

.sync-current-desc {
  margin-top: 4px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
  word-break: break-all;
}

.sync-progress-stack {
  display: grid;
  gap: 6px;
  max-width: 420px;
  margin-top: 10px;
}

.sync-byte-text {
  font-size: 12px;
  font-weight: 600;
  color: var(--el-text-color-secondary);
}

.sync-current-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-shrink: 0;
  white-space: nowrap;
}

.history-title {
  display: grid;
  grid-template-columns: 10px 150px minmax(0, 1fr) auto auto 60px;
  align-items: center;
  gap: 8px;
  width: 100%;
  min-width: 0;
}

.history-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--el-color-info);
}

.history-dot.is-success {
  background: var(--el-color-success);
}

.history-dot.is-warning {
  background: var(--el-color-warning);
}

.history-dot.is-error,
.history-dot.is-danger {
  background: var(--el-color-danger);
}

.history-time,
.history-message,
.history-duration {
  font-size: 12px;
}

.history-message {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.history-duration {
  color: var(--el-text-color-secondary);
  text-align: right;
}

.history-detail {
  display: grid;
  gap: 12px;
  padding: 4px 0 8px 18px;
}

.detail-block {
  padding: 10px 12px;
  border-radius: 8px;
  background: var(--el-fill-color-light);
}

.detail-title {
  margin-bottom: 8px;
  font-size: 12px;
  font-weight: 700;
  color: var(--el-text-color-secondary);
}

.file-row,
.field-row {
  display: grid;
  grid-template-columns: 48px minmax(0, 1fr);
  align-items: center;
  gap: 8px;
  min-width: 0;
  font-size: 12px;
}

.file-row code {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.change-card {
  padding: 8px 0;
  border-top: 1px solid var(--el-border-color-lighter);
}

.change-card:first-of-type {
  border-top: 0;
}

.change-card-title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 6px;
  font-size: 12px;
}

.change-kind {
  padding: 2px 6px;
  border-radius: 4px;
  color: #fff;
  background: var(--el-color-primary);
}

.change-field-count {
  margin-left: auto;
  color: var(--el-text-color-placeholder);
  font-size: 11px;
  font-weight: 500;
}

.field-row {
  grid-template-columns: 70px minmax(0, 1fr) 16px minmax(0, 1fr);
  margin-top: 4px;
}

.field-label {
  color: var(--el-text-color-secondary);
}

.field-value {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.field-value.is-new {
  color: var(--el-color-primary);
  font-weight: 600;
}

.field-arrow,
.empty-change {
  color: var(--el-text-color-placeholder);
}

.sync-history-list {
  flex: 1 1 auto;
  min-height: 0;
  max-height: none;
  overflow-y: auto;
  padding-right: 6px;
  /* 兼容 Firefox 极简滚动条 */
  scrollbar-width: thin !important;
  scrollbar-color: rgba(255, 255, 255, 0.15) transparent !important;
}

/* 弹窗固定在视口上方并限制总高度，外层不滚动，仅历史列表内部滚动。 */
:global(.sync-history-overlay .el-overlay-dialog) {
  overflow: hidden !important;
}

:global(.el-dialog.sync-history-dialog) {
  display: flex;
  flex-direction: column;
  height: min(720px, 84vh);
  max-height: 84vh;
  margin: 4vh auto 0 !important;
  overflow: hidden;
}

:global(.el-dialog.sync-history-dialog .el-dialog__header) {
  flex: 0 0 auto;
  padding: 18px 24px 12px;
}

:global(.el-dialog.sync-history-dialog .el-dialog__body) {
  flex: 1 1 auto;
  min-height: 0;
  padding: 12px 24px 18px;
  overflow: hidden;
}

@media (max-height: 760px) {
  :global(.el-dialog.sync-history-dialog) {
    height: 88vh;
    max-height: 88vh;
    margin-top: 2vh !important;
  }

  :global(.el-dialog.sync-history-dialog .el-dialog__header) {
    padding-top: 14px;
    padding-bottom: 10px;
  }

  :global(.el-dialog.sync-history-dialog .el-dialog__body) {
    padding-top: 8px;
    padding-bottom: 12px;
  }

  .sync-current-card {
    padding-top: 10px;
    padding-bottom: 10px;
  }
}

/* 兼容现代浏览器极简滚动条 */
.sync-history-list::-webkit-scrollbar {
  width: 6px !important;
  height: 6px !important;
}

.sync-history-list::-webkit-scrollbar-track {
  background: transparent !important;
}

.sync-history-list::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.15) !important;
  border-radius: 3px !important;
}

.sync-history-list::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3) !important;
}
</style>
