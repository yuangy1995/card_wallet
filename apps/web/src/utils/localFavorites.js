export const FAVORITES_KEY = 'walletLocalFavoritesV1'
export const readFavoriteIDs = value => new Set(Array.isArray(value) ? value.filter(id => typeof id === 'string' && id) : [])
export const toggledFavorites = (value, id) => {
  const ids = readFavoriteIDs(value)
  if (!id) return [...ids].sort()
  if (ids.has(id)) ids.delete(id); else ids.add(id)
  return [...ids].sort()
}
export const retainedFavorites = (value, validIDs) => [...readFavoriteIDs(value)].filter(id => validIDs.has(id)).sort()
