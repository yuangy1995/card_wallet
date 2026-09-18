export function pageGroups(groups, page, size) {
  const start = (page - 1) * size
  const end = start + size
  let offset = 0
  return groups.flatMap(group => {
    const count = group.cards.length
    const from = Math.max(0, start - offset)
    const to = Math.min(count, end - offset)
    offset += count
    return to > from ? [{ ...group, fullCount: count, cards: group.cards.slice(from, to) }] : []
  })
}
export function mergePageSelection(previous, selection, page) {
  const pageIds = new Set(page.map(card => card.id))
  return [...previous.filter(card => !pageIds.has(card.id)), ...selection.filter(card => pageIds.has(card.id))]
}
