import { computed, onScopeDispose, ref, watch } from 'vue'
import { localDataStore } from '@/utils/indexedDbStorage'
import { FAVORITES_KEY, readFavoriteIDs, toggledFavorites, retainedFavorites } from '@/utils/localFavorites'

export function useLocalFavorites(cards, ready, reportError) {
  const saved = ref(localDataStore.get(FAVORITES_KEY) || [])
  const ids = computed(() => readFavoriteIDs(saved.value))
  let queue = Promise.resolve()
  let disposed = false
  onScopeDispose(() => { disposed = true; saved.value = [] })
  const update = transform => {
    const job = queue.then(async () => {
      if (disposed || !localDataStore.isUnlocked) return
      const current = localDataStore.get(FAVORITES_KEY) || []
      const next = transform(current)
      if (JSON.stringify(current) === JSON.stringify(next)) return
      await localDataStore.set(FAVORITES_KEY, next)
      if (!disposed) saved.value = next
    })
    queue = job.catch(error => { if (!disposed) reportError(error) })
    return queue
  }
  const toggle = id => update(current => toggledFavorites(current, id))
  watch([ready, () => cards.value.map(card => card.id)], ([loaded, keys]) => {
    if (loaded) update(current => retainedFavorites(current, new Set(keys)))
  })
  return { favoriteIDs: ids, toggleFavorite: toggle }
}
