export const CARD_TIMESTAMP_FIELDS = [
  'lastModifyTime',
  'lastTime',
  'nextAnnualFeeCollectionTime'
]

const pad = (value) => String(value).padStart(2, '0')

const parseNumericTimestamp = (value) => {
  const number = Number(value)
  if (!Number.isFinite(number) || number <= 0) return ''
  return number < 100000000000 ? number * 1000 : number
}

const parseDateParts = (value) => {
  if (typeof value !== 'string') return null
  const trimmed = value.trim()
  if (!trimmed) return null

  const match = trimmed.match(
    /^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2})(?:\.(\d{1,3}))?)?)?(?:Z)?$/
  )
  if (!match) return null

  const [, year, month, day, hour = '0', minute = '0', second = '0', millisecond = '0'] = match
  if (trimmed.endsWith('Z') || trimmed.includes('T')) {
    const iso = trimmed.includes('T') ? trimmed : trimmed.replace(' ', 'T')
    const parsed = Date.parse(iso)
    return Number.isNaN(parsed) ? null : parsed
  }

  return new Date(
    Number(year),
    Number(month) - 1,
    Number(day),
    Number(hour),
    Number(minute),
    Number(second),
    Number(millisecond.padEnd(3, '0'))
  ).getTime()
}

export const toCardTimestamp = (value, fallback = '') => {
  if (value === undefined || value === null || value === '') return fallback
  if (value instanceof Date) {
    const time = value.getTime()
    return Number.isNaN(time) ? fallback : time
  }
  if (typeof value === 'number') return parseNumericTimestamp(value) || fallback
  if (typeof value === 'string' && /^\d+(\.\d+)?$/.test(value.trim())) {
    return parseNumericTimestamp(value) || fallback
  }

  const parsedParts = parseDateParts(value)
  if (parsedParts) return parsedParts

  const parsed = new Date(value).getTime()
  return Number.isNaN(parsed) ? fallback : parsed
}

export const nowCardTimestamp = () => Date.now()

export const timestampFromDateInput = (value) => {
  if (!value) return null
  if (typeof value !== 'string') return toCardTimestamp(value)
  const [year, month, day] = value.split('-').map(Number)
  if (!year || !month || !day) return toCardTimestamp(value)
  return new Date(year, month - 1, day, 0, 0, 0, 0).getTime()
}

export const formatTimestampForDateInput = (value) => {
  const timestamp = toCardTimestamp(value)
  if (!timestamp) return ''
  const date = new Date(timestamp)
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

export const formatCardTimestamp = (value) => {
  const timestamp = toCardTimestamp(value)
  if (!timestamp) return '-'
  const date = new Date(timestamp)
  return `${date.getFullYear()}/${pad(date.getMonth() + 1)}/${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

export const addYearsToTimestamp = (value, years = 1) => {
  const timestamp = toCardTimestamp(value)
  if (!timestamp) return null
  const date = new Date(timestamp)
  date.setFullYear(date.getFullYear() + years)
  return date.getTime()
}

export const normalizeCardTimeFields = (card, { fillLastModifyTime = false } = {}) => {
  const normalized = { ...card }
  CARD_TIMESTAMP_FIELDS.forEach((field) => {
    const fallback = field === 'lastModifyTime' && fillLastModifyTime ? nowCardTimestamp() : null
    normalized[field] = toCardTimestamp(normalized[field], fallback)
  })
  return normalized
}
