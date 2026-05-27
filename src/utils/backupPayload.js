import { activeCards, SYNC_SCHEMA_VERSION } from '@/utils/syncProtocol'

export const parseBackupPayload = (data) => {
  return typeof data === 'string' ? JSON.parse(data) : data
}

export const isSyncSnapshotPayload = (payload) => {
  return payload?.schemaVersion === SYNC_SCHEMA_VERSION && Array.isArray(payload.records)
}

export const isLegacyBackupPayload = (data) => {
  return backupPayloadInfo(data).isLegacy
}

export const backupPayloadInfo = (data) => {
  const payload = parseBackupPayload(data)
  const isSnapshot = isSyncSnapshotPayload(payload)
  const isCardArray = Array.isArray(payload)
  const hasDataArray = Array.isArray(payload?.data)
  const hasCardsArray = Array.isArray(payload?.cards)
  const isRecognized = isCardArray || isSnapshot || hasDataArray || hasCardsArray
  const cards = (() => {
    if (isCardArray) return payload
    if (isSnapshot) return activeCards(payload.records)
    if (hasDataArray) return payload.data
    return hasCardsArray ? payload.cards : []
  })()

  return {
    payload,
    cards,
    isSyncSnapshot: isSnapshot,
    isLegacy: isRecognized && !isSnapshot,
    isRecognized
  }
}

export const cardsFromBackupPayload = (data) => backupPayloadInfo(data).cards
