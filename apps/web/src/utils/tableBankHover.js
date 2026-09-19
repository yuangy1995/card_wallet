// 与表格银行合并口径一致：只联动当前页中同地区、同银行的连续记录。
export function bankHoverRange(rows, id) {
  const index = rows.findIndex(row => row.id === id)
  if (index < 0) return null
  const sameBank = row => (row.country || '') === (rows[index].country || '') &&
    (row.bank || '') === (rows[index].bank || '')
  let start = index
  let end = index + 1
  while (start > 0 && sameBank(rows[start - 1])) start--
  while (end < rows.length && sameBank(rows[end])) end++
  return { start, end }
}
