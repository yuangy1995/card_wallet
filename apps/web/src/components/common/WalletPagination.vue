<template>
  <div v-if="total > 0" class="wallet-pagination-bar">
    <span class="wallet-page-range" role="status">第 {{ start }}–{{ end }} 条，共 {{ total }} 条</span>
    <el-pagination
      :current-page="page"
      :page-size="pageSize"
      :page-sizes="pageSizes"
      :total="total"
      :pager-count="5"
      size="small"
      layout="sizes, prev, pager, next, jumper"
      class="wallet-pagination"
      @update:current-page="$emit('update:page', $event)"
      @update:page-size="$emit('update:pageSize', $event)"
    />
  </div>
</template>

<script setup>
import { computed } from 'vue'
const props = defineProps({
  page: { type: Number, required: true },
  pageSize: { type: Number, required: true },
  pageSizes: { type: Array, required: true },
  total: { type: Number, required: true }
})
defineEmits(['update:page', 'update:pageSize'])
const start = computed(() => props.total ? (props.page - 1) * props.pageSize + 1 : 0)
const end = computed(() => Math.min(props.page * props.pageSize, props.total))
</script>

<style scoped>
.wallet-pagination-bar {
  display: flex;
  flex: 0 0 auto;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 8px 16px;
  padding: 10px 12px;
  border-top: 1px solid var(--el-border-color-lighter);
  background: var(--el-bg-color);
  color: var(--el-text-color-secondary);
  font-size: 12px;
}
.wallet-page-range { white-space: nowrap; font-variant-numeric: tabular-nums; }
.wallet-pagination { flex-wrap: wrap; justify-content: flex-end; gap: 4px; padding: 0; }
.wallet-pagination :deep(.el-select) { width: 110px; }
.wallet-pagination :deep(.el-select__wrapper) { background: var(--el-fill-color-blank); }
@media (max-width: 640px) {
  .wallet-pagination-bar { justify-content: center; padding: 8px 4px; }
  .wallet-page-range { flex-basis: 100%; text-align: center; }
  .wallet-pagination { justify-content: center; }
  .wallet-pagination :deep(.el-pagination__jump) { display: none; }
  .wallet-pagination :deep(.el-pagination__sizes) { margin-right: 4px; }
}
</style>
