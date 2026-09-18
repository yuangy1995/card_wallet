export const escapeHTML = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char])
export function csvCell(value) {
  let text = String(value ?? '')
  // 防止表格软件把用户输入当作公式；所有字段都转义逗号、换行和双引号。
  if (/^[\s]*[=+@-]/.test(text) || /^[\t\r\n]/.test(text)) text = "'" + text
  return '"' + text.replace(/"/g, '""') + '"'
}
export function toCSV(rows, headers) {
  return '\uFEFF' + [headers.map(csvCell).join(','), ...rows.map(row => headers.map(key => csvCell(row[key])).join(','))].join('\r\n')
}
