import { ref, onMounted, onUnmounted } from 'vue'
// 全应用共用一个日历日时钟，避免每张卡片启动计时器；后台恢复也重新核对。
export function useCalendarDay() {
  const midnight = () => { const date = new Date(); date.setHours(0, 0, 0, 0); return date.getTime() }
  const day = ref(midnight())
  let timer
  const refresh = () => {
    day.value = midnight()
    clearTimeout(timer)
    const next = new Date(); next.setHours(24, 0, 0, 10)
    timer = setTimeout(refresh, next.getTime() - Date.now())
  }
  onMounted(() => { refresh(); document.addEventListener('visibilitychange', refresh) })
  onUnmounted(() => { clearTimeout(timer); document.removeEventListener('visibilitychange', refresh) })
  return day
}
