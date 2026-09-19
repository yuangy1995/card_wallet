import { ref, computed, watch } from 'vue'

export function usePagedCards(cards, size, storageKey = '') {
  const page = ref(1)
  const pageSizes = [...new Set([20, 50, 100, 200, size])].sort((a, b) => a - b)
  let savedSize = size
  try {
    const saved = Number(storageKey && localStorage.getItem(storageKey))
    if (pageSizes.includes(saved)) savedSize = saved
  } catch { /* 禁用偏好存储时仍可以正常翻页。 */ }
  const pageSize = ref(savedSize)
  const total = computed(() => cards.value.length)
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / pageSize.value)))
  watch(pageCount, count => { page.value = Math.min(page.value, count) }, { flush: 'sync' })
  watch(pageSize, (value, previous) => {
    if (!pageSizes.includes(value)) { pageSize.value = previous; return }
    page.value = 1
    try { if (storageKey) localStorage.setItem(storageKey, String(value)) } catch { /* 会话内仍生效。 */ }
  }, { flush: 'sync' })
  // 搜索、收藏过滤或排序改变结果顺序时回到第一页；仅更新卡片字段不打断翻页。
  watch(() => cards.value.map(card => card.id), (ids, previous) => {
    if (ids.length !== previous.length || ids.some((id, index) => id !== previous[index])) page.value = 1
  }, { flush: 'sync' })
  const rows = computed(() => cards.value.slice((page.value - 1) * pageSize.value, page.value * pageSize.value))
  return { page, pageSize, pageSizes, pageCount, total, rows }
}
