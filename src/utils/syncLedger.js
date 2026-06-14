import { STORAGE_KEYS } from '@/config/constants'
import { activeRecord, cardsEqualForSync, deletedRecord, legacyRecords, mergeRecords, syncTimestamp } from '@/utils/syncProtocol'
import { localDataStore } from '@/utils/indexedDbStorage'

const createCardId = () => globalThis.crypto?.randomUUID?.() ||
  `${Date.now()}-${Math.random().toString(16).slice(2)}`

const ensureCardIds = (cards = []) => cards.map((card) => {
  const id = String(card?.id || '').trim()
  return id ? { ...card, id } : { ...card, id: createCardId() }
})

class CardSyncLedger {
  load() {
    return localDataStore.get(STORAGE_KEYS.SYNC_RECORDS, [])
  }

  async initialize(cards) {
    const saved = this.load()
    const normalizedCards = ensureCardIds(cards)
    const records = saved.length > 0 ? mergeRecords(saved) : mergeRecords(legacyRecords(normalizedCards))
    await this.save(records)
    return records
  }

  async commit(cards, { deletedCardIds = [], replace = false } = {}) {
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
    await this.save(records)
    if (newEvents.length > 0) {
      await this.bumpRevision()
      await this.setPending(true)
    }
    return records
  }

  async merge(remoteRecords) {
    const merged = mergeRecords(this.load(), remoteRecords)
    await this.save(merged)
    return merged
  }

  async save(records) {
    const normalized = mergeRecords(records)
    try {
      await localDataStore.set(STORAGE_KEYS.SYNC_RECORDS, normalized)
    } catch (error) {
      throw new Error(`本地同步账本保存失败：${error.message}`)
    }
    await localDataStore.remove(STORAGE_KEYS.CARD_DATA).catch(() => {})
  }

  async setPending(pending) {
    await localDataStore.set(STORAGE_KEYS.SYNC_PENDING, pending)
  }

  isPending() {
    return localDataStore.get(STORAGE_KEYS.SYNC_PENDING, false)
  }

  lastWebDAVSnapshotFilename() {
    return localDataStore.get(STORAGE_KEYS.SYNC_LAST_SNAPSHOT, '')
  }

  async setLastWebDAVSnapshotFilename(filename) {
    await localDataStore.set(STORAGE_KEYS.SYNC_LAST_SNAPSHOT, filename || '')
  }

  revision() {
    return Number(localDataStore.get(STORAGE_KEYS.SYNC_REVISION, 0)) || 0
  }

  async bumpRevision() {
    const next = this.revision() + 1
    await localDataStore.set(STORAGE_KEYS.SYNC_REVISION, next)
    return next
  }
}

export const cardSyncLedger = new CardSyncLedger()
