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
  constructor() { this.queue = Promise.resolve() }
  enqueue(operation) {
    const session = localDataStore.session
    const next = this.queue.then(() => {
      if (session !== localDataStore.session) throw new Error('应用已锁定，请重新解锁。')
      return operation()
    })
    this.queue = next.catch(() => {})
    return next
  }

  load() {
    return localDataStore.get(STORAGE_KEYS.SYNC_RECORDS, [])
  }

  async initialize(cards) {
    return this.enqueue(async () => {
      const saved = localDataStore.get(STORAGE_KEYS.SYNC_RECORDS, null)
      if (saved !== null) return mergeRecords(saved)
      const records = mergeRecords(legacyRecords(ensureCardIds(cards)))
      await this.persist(records)
      return records
    })
  }

  async commit(cards, { deletedCardIds = [], replace = false } = {}) {
    return this.enqueue(async () => {
    const current = this.load()
    const recordsById = new Map(current.map((record) => [record.cardId, record]))
    const newEvents = []
    const normalizedCards = ensureCardIds(cards)
    const incomingIds = new Set(normalizedCards.map((card) => card.id))
    // 本地同一卡片的后续操作必须晚于已观察到的版本，不能交给随机 mutationId 决胜。
    const changedAtAfter = previous => new Date(Math.max(Date.now(), (Date.parse(previous?.changedAt) || 0) + 1)).toISOString()

    normalizedCards.forEach((card) => {
      const previous = recordsById.get(card.id)
      if (previous?.state === 'active' && cardsEqualForSync(previous.card, card)) {
        return
      }
      newEvents.push(activeRecord(card, changedAtAfter(previous)))
    })

    const deleted = new Set(deletedCardIds)
    if (replace) {
      current.filter((record) => record.state === 'active' && !incomingIds.has(record.cardId))
        .forEach((record) => deleted.add(record.cardId))
    }
    deleted.forEach((cardId) => newEvents.push(deletedRecord(cardId, changedAtAfter(recordsById.get(cardId)))))

    const records = mergeRecords(current, newEvents)
    if (newEvents.length > 0) await this.persist(records, [
      [STORAGE_KEYS.SYNC_REVISION, this.revision() + 1], [STORAGE_KEYS.SYNC_PENDING, true]
    ])
    return records
    })
  }

  async merge(remoteRecords) {
    return this.enqueue(async () => {
      const current = this.load()
      const merged = mergeRecords(current, remoteRecords)
      if (JSON.stringify(merged) !== JSON.stringify(current)) await this.persist(merged)
      return merged
    })
  }

  async save(records) { return this.enqueue(() => this.persist(records)) }

  async persist(records, metadata = []) {
    try {
      await localDataStore.setMany([[STORAGE_KEYS.SYNC_RECORDS, mergeRecords(records)], ...metadata], [STORAGE_KEYS.CARD_DATA])
    } catch (error) { throw new Error(`本地同步账本保存失败：${error.message}`) }
  }

  async acknowledgeUpload(filename, revision) {
    return this.enqueue(async () => {
      const pending = this.revision() !== revision
      await localDataStore.setMany([[STORAGE_KEYS.SYNC_PENDING, pending], [STORAGE_KEYS.SYNC_LAST_SNAPSHOT, filename]])
      return pending
    })
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
