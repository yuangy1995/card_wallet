import { normalizeCardTimeFields, toCardTimestamp } from '@/utils/cardTimestamp'

export const SYNC_SCHEMA_VERSION = '4.0.0'

const TRANSIENT_CARD_FIELDS = new Set([
  'showCardNumber',
  'showCVV',
  'countryRowSpan',
  'showCountry',
  'bankRowSpan',
  'showBank',
  'limitRowSpan',
  'showLimit',
  'lastTimeRowSpan',
  'showLastTime'
])

const LEGACY_CARD_ID_FIELDS = new Set(['cardId', '_id', 'uuid'])

const newMutationId = () => globalThis.crypto?.randomUUID?.() ||
  `${Date.now()}-${Math.random().toString(16).slice(2)}`

export const syncTimestamp = () => new Date().toISOString()

export const normalizeTimestamp = (value) => {
  const candidate = typeof value === 'string' ? value.replace(' ', 'T') : value
  const parsed = new Date(candidate)
  return Number.isNaN(parsed.getTime()) ? syncTimestamp() : parsed.toISOString()
}

const stableValue = (value) => {
  if (Array.isArray(value)) return value.map(stableValue)
  if (!value || typeof value !== 'object') return value
  return Object.keys(value).sort().reduce((result, key) => {
    result[key] = stableValue(value[key])
    return result
  }, {})
}

export const normalizeCardForSync = (card = {}, { includeLastModifyTime = true } = {}) => {
  return Object.keys(card).sort().reduce((result, key) => {
    if (key.startsWith('_') || TRANSIENT_CARD_FIELDS.has(key) || LEGACY_CARD_ID_FIELDS.has(key)) return result
    if (!includeLastModifyTime && key === 'lastModifyTime') return result
    if (card[key] !== undefined) {
      result[key] = card[key]
    }
    return result
  }, {})
}

export const comparableCardForSync = (card) => normalizeCardTimeFields(
  normalizeCardForSync(card, { includeLastModifyTime: false })
)

export const cardsEqualForSync = (left, right) => {
  return JSON.stringify(stableValue(comparableCardForSync(left))) ===
    JSON.stringify(stableValue(comparableCardForSync(right)))
}

const stableCardId = (card = {}) => {
  for (const key of ['id', 'cardId', '_id', 'uuid']) {
    const value = card[key]
    if (value === undefined || value === null) continue
    const normalized = String(value).trim()
    if (normalized) return normalized
  }
  return ''
}

export const activeRecord = (card, changedAt = syncTimestamp()) => {
  const normalized = normalizeTimestamp(changedAt)
  const cardId = stableCardId(card) || newMutationId()
  const cardForSync = normalizeCardTimeFields(
    normalizeCardForSync(card, { includeLastModifyTime: false })
  )
  return {
    cardId,
    mutationId: newMutationId(),
    changedAt: normalized,
    state: 'active',
    card: { ...cardForSync, id: cardId, lastModifyTime: toCardTimestamp(normalized) }
  }
}

export const deletedRecord = (cardId, changedAt = syncTimestamp()) => ({
  cardId,
  mutationId: newMutationId(),
  changedAt: normalizeTimestamp(changedAt),
  state: 'deleted'
})

export const legacyRecords = (cards) => cards.map((card) =>
  activeRecord(card, card.lastModifyTime || syncTimestamp())
)

export const winningRecord = (left, right) => {
  const timeDifference = Date.parse(left.changedAt) - Date.parse(right.changedAt)
  if (timeDifference !== 0) return timeDifference > 0 ? left : right
  if (left.state !== right.state) return left.state === 'deleted' ? left : right
  return left.mutationId >= right.mutationId ? left : right
}

const normalizeRecord = (record) => {
  if (!record?.cardId) return null
  const changedAt = normalizeTimestamp(record.changedAt)
  if (record.state === 'deleted') {
    return {
      cardId: record.cardId,
      mutationId: record.mutationId || newMutationId(),
      changedAt,
      state: 'deleted'
    }
  }
  if (record.state === 'active' && record.card) {
    const cardForSync = normalizeCardTimeFields(
      normalizeCardForSync(record.card, { includeLastModifyTime: false })
    )
    return {
      cardId: record.cardId,
      mutationId: record.mutationId || newMutationId(),
      changedAt,
      state: 'active',
      card: {
        ...cardForSync,
        id: record.cardId,
        lastModifyTime: toCardTimestamp(changedAt)
      }
    }
  }
  return null
}

export const mergeRecords = (...collections) => {
  const recordsByCard = new Map()
  collections.flat().map(normalizeRecord).filter(Boolean).forEach((record) => {
    const current = recordsByCard.get(record.cardId)
    recordsByCard.set(record.cardId, current ? winningRecord(current, record) : record)
  })
  return [...recordsByCard.values()].sort((left, right) => left.cardId.localeCompare(right.cardId))
}

export const activeCards = (records) => mergeRecords(records)
  .filter((record) => record.state === 'active')
  .map((record) => record.card)

export const createSnapshot = (records, source = 'web') => ({
  schemaVersion: SYNC_SCHEMA_VERSION,
  snapshotId: newMutationId(),
  generatedAt: syncTimestamp(),
  source,
  records: mergeRecords(records)
})
