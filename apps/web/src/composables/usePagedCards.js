import { ref, computed, watch } from 'vue'
export function usePagedCards(cards, size) {
  const page = ref(1)
  const total = computed(() => cards.value.length)
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / size)))
  watch(pageCount, count => { page.value = Math.min(page.value, count) }, { flush: 'sync' })
  const rows = computed(() => cards.value.slice((page.value - 1) * size, page.value * size))
  return { page, total, rows }
}
