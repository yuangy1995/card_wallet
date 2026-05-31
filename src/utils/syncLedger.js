import { STORAGE_KEYS } from '@/config/constants'
import { CardDataStorage, StorageManager } from '@/utils/storage'
import { activeCards, activeRecord, cardsEqualForSync, deletedRecord, legacyRecords, mergeRecords, syncTimestamp } from '@/utils/syncProtocol'

const createCardId = () => globalThis.crypto?.randomUUID?.() ||
  `${Date.now()}-${Math.random().toString(16).slice(2)}`

const ensureCardIds = (cards = []) => cards.map((card) => {
  const id = String(card?.id || '').trim()
  return id ? { ...card, id } : { ...card, id: createCardId() }
})

class CardSyncLedger {
  load() {
    return StorageManager.get(STORAGE_KEYS.SYNC_RECORDS, [])
  }

  initialize(cards) {
    const saved = this.load()
    const normalizedCards = ensureCardIds(cards)
    const records = saved.length > 0 ? mergeRecords(saved) : mergeRecords(legacyRecords(normalizedCards))
    this.save(records)
    return records
  }

  commit(cards, { deletedCardIds = [], replace = false } = {}) {
    const current = this.load()
    const recordsById = new Map(current.map((record) => [record.cardId, record]))
    const newEvents = []
    const normalizedCards = ensureCardIds(cards)
    const incomingIds = new Set(normalizedCards.map((card) => card.id))
    const changedAt = syncTimestamp()

    normalizedCards.forEach((card) => {
      const previous = recordsById.get(card.id)
      if (previous?.state === 'active' && cardsEqualForSync(previous.card, card)) {
        return
      }
      newEvents.push(activeRecord(card, changedAt))
    })

    const deleted = new Set(deletedCardIds)
    if (replace) {
      current.filter((record) => record.state === 'active' && !incomingIds.has(record.cardId))
        .forEach((record) => deleted.add(record.cardId))
    }
    deleted.forEach((cardId) => newEvents.push(deletedRecord(cardId, changedAt)))

    const records = mergeRecords(current, newEvents)
    this.save(records)
    if (newEvents.length > 0) {
      this.bumpRevision()
      this.setPending(true)
    }
    return records
  }

  merge(remoteRecords) {
    const merged = mergeRecords(this.load(), remoteRecords)
    this.save(merged)
    return merged
  }

  save(records) {
    const normalized = mergeRecords(records)
    StorageManager.set(STORAGE_KEYS.SYNC_RECORDS, normalized)
    CardDataStorage.saveCardData(activeCards(normalized))
  }

  setPending(pending) {
    StorageManager.set(STORAGE_KEYS.SYNC_PENDING, pending)
  }

  isPending() {
    return StorageManager.get(STORAGE_KEYS.SYNC_PENDING, false)
  }

  revision() {
    return Number(StorageManager.get(STORAGE_KEYS.SYNC_REVISION, 0)) || 0
  }

  bumpRevision() {
    const next = this.revision() + 1
    StorageManager.set(STORAGE_KEYS.SYNC_REVISION, next)
    return next
  }
}

export const cardSyncLedger = new CardSyncLedger()
