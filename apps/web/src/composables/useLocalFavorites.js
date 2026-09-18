import { ref, onMounted, onUnmounted } from 'vue'
import { ElMessage } from 'element-plus'
import { FAVORITES_KEY, readFavorites, updateFavorites } from '@/utils/localFavorites'
export function useLocalFavorites() {
  const favoriteIds = ref(readFavorites())
  const update = change => {
    try { favoriteIds.value = updateFavorites(change) }
    catch { ElMessage.error('收藏未能保存，请检查浏览器存储设置。') }
  }
  const changed = event => { if (event.key === FAVORITES_KEY || event.key === null) favoriteIds.value = readFavorites() }
  onMounted(() => window.addEventListener('storage', changed))
  onUnmounted(() => window.removeEventListener('storage', changed))
  return { favoriteIds, toggleFavorite: id => update({ toggle: id }), removeDeletedFavorites: ids => update({ deleted: ids }) }
}
