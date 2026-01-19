/**
 * 防抖优化 Composable
 */
import { ref, watch } from 'vue'

/**
 * 防抖功能
 * @param {Function} fn - 要防抖的函数
 * @param {number} delay - 延迟时间(ms)
 */
export function useDebounce(fn, delay = 300) {
  let timeoutId = null

  const debounced = (...args) => {
    clearTimeout(timeoutId)
    timeoutId = setTimeout(() => fn(...args), delay)
  }

  const cancel = () => {
    clearTimeout(timeoutId)
  }

  return { debounced, cancel }
}

/**
 * 防抖的响应式值
 * @param {Ref} value - 响应式值
 * @param {number} delay - 延迟时间(ms)
 */
export function useDebouncedRef(value, delay = 300) {
  const debouncedValue = ref(value.value)

  const { debounced } = useDebounce((newValue) => {
    debouncedValue.value = newValue
  }, delay)

  watch(value, debounced, { immediate: true, deep: true })

  return debouncedValue
}
