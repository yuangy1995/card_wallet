/**
 * 表格性能优化 Composable
 */
import { ref, computed, watchEffect } from 'vue'

/**
 * 表格数据性能优化
 * @param {Ref} tableData - 表格数据
 * @param {number} pageSize - 页面大小
 */
export function useTablePerformance(tableData, pageSize = 100) {
  const currentPage = ref(1)
  const loading = ref(false)

  // 虚拟滚动优化 - 只渲染可见区域的数据
  const visibleData = computed(() => {
    if (!tableData.value || tableData.value.length <= pageSize) {
      return tableData.value
    }

    const startIndex = (currentPage.value - 1) * pageSize
    const endIndex = startIndex + pageSize
    return tableData.value.slice(startIndex, endIndex)
  })

  // 总页数
  const totalPages = computed(() => {
    if (!tableData.value) return 0
    return Math.ceil(tableData.value.length / pageSize)
  })

  // 分页控制
  const goToPage = (page) => {
    if (page >= 1 && page <= totalPages.value) {
      currentPage.value = page
    }
  }

  const nextPage = () => {
    if (currentPage.value < totalPages.value) {
      currentPage.value++
    }
  }

  const prevPage = () => {
    if (currentPage.value > 1) {
      currentPage.value--
    }
  }

  // 重置到第一页
  const resetPage = () => {
    currentPage.value = 1
  }

  // 监听数据变化，自动重置页码
  watchEffect(() => {
    if (tableData.value && currentPage.value > totalPages.value) {
      resetPage()
    }
  })

  return {
    visibleData,
    currentPage,
    totalPages,
    loading,
    goToPage,
    nextPage,
    prevPage,
    resetPage
  }
}

/**
 * 计算属性缓存优化
 * @param {Function} computeFn - 计算函数
 * @param {Array} deps - 依赖项
 */
export function useComputedCache(computeFn, deps) {
  let cache = null
  let lastDepsHash = null

  return computed(() => {
    // 生成依赖项哈希
    const currentDepsHash = JSON.stringify(deps.map(dep => dep.value))
    
    // 如果依赖项没有变化，返回缓存结果
    if (cache !== null && currentDepsHash === lastDepsHash) {
      return cache
    }

    // 重新计算并缓存结果
    cache = computeFn()
    lastDepsHash = currentDepsHash
    return cache
  })
}
