export const FAVORITES_KEY = 'wallet_favorite_card_ids'
export function readFavorites(storage = localStorage) {
  try {
    const values = JSON.parse(storage.getItem(FAVORITES_KEY) || '[]')
    return new Set(Array.isArray(values) ? values.filter(value => typeof value === 'string' && value) : [])
  } catch { return new Set() }
}
export function updateFavorites({ toggle, deleted = [] }, storage = localStorage) {
  const ids = readFavorites(storage)
  if (toggle) { if (ids.has(toggle)) ids.delete(toggle); else ids.add(toggle) }
  for (const id of deleted) ids.delete(id)
  storage.setItem(FAVORITES_KEY, JSON.stringify([...ids].sort()))
  return ids
}
