<template>
  <el-dialog
    v-model="visible"
    title="存储管理"
    width="680px"
    top="7vh"
    class="mobile-dialog storage-management-dialog"
    @open="refresh"
  >
    <div v-loading="loading" class="storage-content">
      <el-alert
        :title="persistent ? '浏览器已允许持久化保存本地数据' : '本地数据可能受浏览器空间回收策略影响'"
        :type="persistent ? 'success' : 'warning'"
        :closable="false"
        show-icon
      />

      <div class="metric-grid">
        <div class="metric-card">
          <span>浏览器已用空间</span>
          <strong>{{ formatBytes(usage) }}</strong>
        </div>
        <div class="metric-card">
          <span>浏览器可用配额</span>
          <strong>{{ formatBytes(quota) }}</strong>
        </div>
        <div class="metric-card">
          <span>卡片数据估算</span>
          <strong>{{ formatBytes(cardDataBytes) }}</strong>
        </div>
        <div class="metric-card">
          <span>卡片图片</span>
          <strong>{{ imageCount }} 张 · {{ formatBytes(imageBytes) }}</strong>
        </div>
      </div>

      <el-progress
        v-if="quota > 0"
        :percentage="usagePercentage"
        :status="usagePercentage > 85 ? 'exception' : undefined"
      />

      <el-descriptions :column="1" border>
        <el-descriptions-item label="本地数据库">{{ databaseAvailable ? 'IndexedDB 正常' : '不可用' }}</el-descriptions-item>
        <el-descriptions-item label="本地键数量">{{ databaseKeyCount }}</el-descriptions-item>
        <el-descriptions-item label="卡片数量">{{ cards.length }}</el-descriptions-item>
      </el-descriptions>

      <div class="actions">
        <el-button @click="refresh">重新检测</el-button>
        <el-button v-if="!persistent" type="primary" plain @click="requestPersistence">申请持久化存储</el-button>
        <el-button type="warning" plain @click="clearRuntimeCaches">清理运行缓存</el-button>
      </div>

      <p class="hint">清理运行缓存不会删除卡片、同步配置或密码；浏览器会在需要时自动重新计算。</p>
    </div>
  </el-dialog>
</template>

<script setup>
import { computed, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { localDataStore } from '@/utils/indexedDbStorage'
import { globalCache, cardDataCache } from '@/utils/cache'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  cards: { type: Array, default: () => [] }
})

const emit = defineEmits(['update:modelValue'])
const visible = computed({
  get: () => props.modelValue,
  set: value => emit('update:modelValue', value)
})

const loading = ref(false)
const usage = ref(0)
const quota = ref(0)
const persistent = ref(false)
const databaseAvailable = ref(false)
const databaseKeyCount = ref(0)

const cardDataBytes = computed(() => new Blob([JSON.stringify(props.cards)]).size)
const allImages = computed(() => props.cards.flatMap(card => Array.isArray(card.cardImages) ? card.cardImages : []))
const imageCount = computed(() => allImages.value.length)
const imageBytes = computed(() => allImages.value.reduce((sum, image) => {
  const raw = String(image?.data || '').replace(/^data:[^,]+,/, '')
  return sum + Math.floor(raw.length * 0.75)
}, 0))
const usagePercentage = computed(() => quota.value > 0 ? Math.min(100, Math.round((usage.value / quota.value) * 100)) : 0)

const formatBytes = value => {
  const bytes = Number(value || 0)
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(1)} MB`
  return `${(bytes / 1024 ** 3).toFixed(2)} GB`
}

const refresh = async () => {
  loading.value = true
  try {
    const estimate = await navigator.storage?.estimate?.()
    usage.value = Number(estimate?.usage || 0)
    quota.value = Number(estimate?.quota || 0)
    persistent.value = Boolean(await navigator.storage?.persisted?.())
    const info = localDataStore.info()
    databaseAvailable.value = info.available
    databaseKeyCount.value = info.keys.length
  } finally {
    loading.value = false
  }
}

const requestPersistence = async () => {
  const granted = Boolean(await navigator.storage?.persist?.())
  persistent.value = granted
  ElMessage[granted ? 'success' : 'warning'](granted ? '已启用持久化存储' : '浏览器未授予持久化存储')
  await refresh()
}

const clearRuntimeCaches = () => {
  globalCache.clear()
  cardDataCache.clear()
  ElMessage.success('运行缓存已清理，卡片数据未受影响')
}
</script>

<style scoped>
.storage-content { display: flex; flex-direction: column; gap: 16px; }
.metric-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
.metric-card { display: flex; flex-direction: column; gap: 8px; padding: 16px; border: 1px solid var(--el-border-color-light); border-radius: 12px; background: var(--el-fill-color-lighter); }
.metric-card span, .hint { color: var(--el-text-color-secondary); font-size: 12px; }
.metric-card strong { font-size: 18px; }
.actions { display: flex; flex-wrap: wrap; gap: 10px; }
.hint { margin: 0; }
@media (max-width: 560px) { .metric-grid { grid-template-columns: 1fr; } }
</style>
