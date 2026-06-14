import { cardSyncLedger } from '@/utils/syncLedger'
import { activeCards, createSnapshot, mergeRecords, SYNC_SCHEMA_VERSION } from '@/utils/syncProtocol'
import { webdavClient } from '@/utils/webdav'
import { decryptSyncEnvelopeV4 } from '@/utils/syncCryptoV4'
import { STORAGE_KEYS } from '@/config/constants'
import { localDataStore } from '@/utils/indexedDbStorage'

const SYNC_HISTORY_LIMIT = 40

const normalizeDisplayValue = (value) => {
  const normalized = value === undefined || value === null ? '' : String(value).trim()
  return normalized || '空'
}

const maskCardNumber = (value = '') => {
  const digits = String(value).replace(/\D/g, '')
  return digits ? `•••• ${digits.slice(-4)}` : '空'
}

const cardDisplayName = (card = {}) => {
  const bank = normalizeDisplayValue(card.bank)
  const alias = normalizeDisplayValue(card.alias)
  return alias === '空' ? `${bank} / ${maskCardNumber(card.cardNumber)}` : `${bank} / ${alias}`
}

const amountText = (value) => {
  if (value === undefined || value === null || value === '') return '空'
  const number = Number(value)
  if (!Number.isFinite(number)) return normalizeDisplayValue(value)
  return Number.isInteger(number) ? String(number) : number.toFixed(2)
}

const categoryText = (value) => value === 'debit' ? '储蓄卡' : '信用卡'

const appendFieldChange = (fields, label, oldValue, newValue) => {
  const oldText = normalizeDisplayValue(oldValue)
  const newText = normalizeDisplayValue(newValue)
  if (oldText !== newText) {
    fields.push({ label, oldValue: oldText, newValue: newText })
  }
}

const fieldChanges = (before = {}, after = {}) => {
  const fields = []
  appendFieldChange(fields, '发卡行', before.bank, after.bank)
  appendFieldChange(fields, '别名', before.alias, after.alias)
  appendFieldChange(fields, '卡类别', categoryText(before.cardCategory), categoryText(after.cardCategory))
  appendFieldChange(fields, '国家', before.country, after.country)
  appendFieldChange(fields, '卡号', maskCardNumber(before.cardNumber), maskCardNumber(after.cardNumber))
  appendFieldChange(fields, '卡级别', before.level, after.level)
  appendFieldChange(fields, '币种', before.type, after.type)
  appendFieldChange(fields, '额度', amountText(before.limit), amountText(after.limit))
  appendFieldChange(fields, '有效期', before.valid, after.valid)
  appendFieldChange(fields, '年费', amountText(before.annualFee), amountText(after.annualFee))
  appendFieldChange(fields, '共享额度', before.isSharedLimit ? '是' : '否', after.isSharedLimit ? '是' : '否')
  return fields.slice(0, 10)
}

const buildCardChange = (kind, before, after) => {
  const card = after || before
  if (!card) return null
  if (kind === 'added') {
    return {
      kind,
      cardId: card.id,
      cardName: cardDisplayName(card),
      fields: [
        { label: '状态', oldValue: '无', newValue: '新增' },
        { label: '发卡行', oldValue: '空', newValue: normalizeDisplayValue(card.bank) },
        { label: '卡号', oldValue: '空', newValue: maskCardNumber(card.cardNumber) }
      ]
    }
  }
  if (kind === 'deleted') {
    return {
      kind,
      cardId: card.id,
      cardName: cardDisplayName(card),
      fields: [{ label: '状态', oldValue: '已存在', newValue: '已删除' }]
    }
  }
  const fields = fieldChanges(before, after)
  if (fields.length === 0) return null
  return { kind, cardId: after.id, cardName: cardDisplayName(after), fields }
}

const diffCards = (beforeCards = [], afterCards = []) => {
  const beforeById = new Map(beforeCards.map(card => [card.id, card]))
  const afterById = new Map(afterCards.map(card => [card.id, card]))
  const ids = new Set([...beforeById.keys(), ...afterById.keys()])
  return [...ids].map((id) => {
    const before = beforeById.get(id)
    const after = afterById.get(id)
    if (!before && after) return buildCardChange('added', null, after)
    if (before && !after) return buildCardChange('deleted', before, null)
    return buildCardChange('modified', before, after)
  }).filter(Boolean).sort((left, right) => left.cardName.localeCompare(right.cardName, 'zh-CN'))
}

const snapshotDateFromFilename = (filename = '') => {
  const prefix = String(filename).split('---')[0]
  let match = prefix.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})-(\d{3})Z$/)
  if (match) {
    const [, year, month, day, hour, minute, second, millisecond] = match
    return Date.UTC(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), Number(second), Number(millisecond))
  }
  match = prefix.match(/^(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{3})$/)
  if (match) {
    const [, year, month, day, hour, minute, second, millisecond] = match
    return new Date(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), Number(second), Number(millisecond)).getTime()
  }
  const parsed = Date.parse(prefix)
  return Number.isNaN(parsed) ? 0 : parsed
}

const recentLocalChanges = (records = [], sinceMs = 0) => {
  const latest = new Map()
  mergeRecords(records).forEach((record) => latest.set(record.cardId, record))
  return [...latest.values()].map((record) => {
    const changedAt = Date.parse(record.changedAt)
    if (!Number.isFinite(changedAt) || changedAt <= sinceMs) return null
    if (record.state === 'deleted') {
      return {
        kind: 'deleted',
        cardId: record.cardId,
        cardName: record.cardId,
        fields: [{ label: '状态', oldValue: '已存在', newValue: '已删除' }]
      }
    }
    return buildCardChange('modified', {}, record.card)
  }).filter(Boolean).sort((left, right) => left.cardName.localeCompare(right.cardName, 'zh-CN'))
}

class WebDAVSyncService {
  constructor() {
    this.onCardsChanged = null
    this.onStatusChanged = null
    this.onHistoryChanged = null
    this.isSyncing = false
    this.syncHistory = []
    this.syncTimer = null
    this.visibilityHandler = null
    this.syncIntervalMs = 5 * 60 * 1000
    this.nextSyncAt = null
    this.lastSuccessfulSyncAt = null
    this.lastFailedSyncAt = null
    this.syncStartedAt = null
    this.lastDurationMs = null
    this.queuedPublishLocalChanges = false
    this.status = {
      message: '正在准备云同步...',
      type: 'info',
      pending: false,
      isSyncing: false,
      nextSyncAt: null,
      lastSuccessfulSyncAt: null,
      lastFailedSyncAt: null,
      syncStartedAt: null,
      elapsedMs: 0,
      lastDurationMs: null,
      intervalMs: this.syncIntervalMs
    }
  }

  startTiming() {
    this.syncStartedAt = Date.now()
    this.lastDurationMs = null
  }

  finishTiming() {
    if (!this.syncStartedAt) return this.lastDurationMs || 0
    const durationMs = Math.max(0, Date.now() - this.syncStartedAt)
    this.syncStartedAt = null
    this.lastDurationMs = durationMs
    return durationMs
  }

  updateStatus(message, type = 'info', pending = cardSyncLedger.isPending(), extra = {}) {
    const elapsedMs = this.isSyncing && this.syncStartedAt
      ? Math.max(0, Date.now() - this.syncStartedAt)
      : 0
    this.status = {
      ...this.status,
      message,
      type,
      pending,
      isSyncing: this.isSyncing,
      nextSyncAt: this.nextSyncAt,
      lastSuccessfulSyncAt: this.lastSuccessfulSyncAt,
      lastFailedSyncAt: this.lastFailedSyncAt,
      syncStartedAt: this.syncStartedAt,
      elapsedMs,
      lastDurationMs: this.lastDurationMs,
      intervalMs: this.syncIntervalMs,
      ...extra
    }
    this.onStatusChanged?.({ ...this.status })
  }

  emitCurrentStatus() {
    this.updateStatus(this.status.message, this.status.type, this.status.pending)
  }

  loadSyncHistory() {
    this.syncHistory = localDataStore.get(STORAGE_KEYS.SYNC_HISTORY, [])
    this.onHistoryChanged?.([...this.syncHistory])
    return this.syncHistory
  }

  getSyncHistory() {
    return [...this.syncHistory]
  }

  async appendSyncHistory(entry) {
    const normalized = {
      id: entry.id || globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`,
      startedAt: entry.startedAt || new Date().toISOString(),
      finishedAt: entry.finishedAt || new Date().toISOString(),
      status: entry.status || 'success',
      message: entry.message || '',
      durationMs: Math.max(0, Number(entry.durationMs || 0)),
      uploadedFile: entry.uploadedFile || '',
      downloadedFiles: Array.isArray(entry.downloadedFiles) ? entry.downloadedFiles : [],
      localChanges: Array.isArray(entry.localChanges) ? entry.localChanges.slice(0, 30) : [],
      remoteChanges: Array.isArray(entry.remoteChanges) ? entry.remoteChanges.slice(0, 30) : []
    }
    this.syncHistory = [normalized, ...this.syncHistory].slice(0, SYNC_HISTORY_LIMIT)
    await localDataStore.set(STORAGE_KEYS.SYNC_HISTORY, this.syncHistory)
    this.onHistoryChanged?.([...this.syncHistory])
  }

  async start(cards, onCardsChanged, onStatusChanged, onHistoryChanged) {
    this.onCardsChanged = onCardsChanged
    this.onStatusChanged = onStatusChanged
    this.onHistoryChanged = onHistoryChanged
    this.loadSyncHistory()
    const records = await cardSyncLedger.initialize(cards)
    this.onCardsChanged(activeCards(records))

    const config = webdavClient.loadConfig()
    if (!config) {
      this.updateStatus('还未设置云同步，本机改动会先保存在本地', 'info')
      return
    }
    this.startAutoSync()
    this.updateStatus('正在后台检查云端数据...', 'info', cardSyncLedger.isPending())
    this.synchronize(false).catch((error) => {
      this.updateStatus(`云同步暂时不可用：${error.message}`, 'warning')
    })
  }

  async commitCards(cards, options = {}) {
    await cardSyncLedger.commit(cards, options)
    this.onCardsChanged?.(activeCards(cardSyncLedger.load()))
    this.synchronize(true).catch((error) => {
      cardSyncLedger.setPending(true).catch(() => {})
      this.updateStatus(`同步失败，本机改动已保留，稍后可重试：${error.message}`, 'warning', true)
    })
  }

  startAutoSync(intervalMs = this.syncIntervalMs) {
    if (typeof window === 'undefined') return

    this.syncIntervalMs = intervalMs
    this.stopAutoSync()
    this.scheduleNextSync(intervalMs)

    if (typeof document !== 'undefined') {
      this.visibilityHandler = () => {
        if (!document.hidden && webdavClient.loadConfig()) {
          this.synchronize(false)
        }
      }
      document.addEventListener('visibilitychange', this.visibilityHandler)
    }
  }

  stopAutoSync() {
    if (this.syncTimer && typeof window !== 'undefined') {
      window.clearTimeout(this.syncTimer)
    }
    this.syncTimer = null
    this.nextSyncAt = null

    if (this.visibilityHandler && typeof document !== 'undefined') {
      document.removeEventListener('visibilitychange', this.visibilityHandler)
    }
    this.visibilityHandler = null
    this.emitCurrentStatus()
  }

  clearScheduledSync() {
    if (this.syncTimer && typeof window !== 'undefined') {
      window.clearTimeout(this.syncTimer)
    }
    this.syncTimer = null
    this.nextSyncAt = null
  }

  scheduleNextSync(delayMs = this.syncIntervalMs) {
    if (typeof window === 'undefined') return
    this.clearScheduledSync()
    if (!webdavClient.loadConfig()) {
      this.emitCurrentStatus()
      return
    }

    this.nextSyncAt = Date.now() + delayMs
    this.syncTimer = window.setTimeout(() => {
      this.syncTimer = null
      this.nextSyncAt = null
      if (typeof document !== 'undefined' && document.hidden) {
        this.scheduleNextSync(this.syncIntervalMs)
        return
      }
      this.synchronize(false)
    }, delayMs)
    this.emitCurrentStatus()
  }

  stop() {
    this.stopAutoSync()
  }

  async synchronize(publishLocalChanges = false) {
    if (this.isSyncing) {
      this.queuedPublishLocalChanges = this.queuedPublishLocalChanges || publishLocalChanges
      if (publishLocalChanges) {
        this.updateStatus('当前修改会在本次同步结束后继续上传', 'info', true)
      }
      return
    }
    this.clearScheduledSync()
    const config = webdavClient.loadConfig()
    if (!config) {
      this.updateStatus('有本机改动待同步：请先完成云同步设置', 'warning', true)
      return
    }
    const syncPassword = String(config.syncPassword || '').trim()
    if (!syncPassword) {
      this.updateStatus('请先在云同步设置中填写同步密钥', 'warning', cardSyncLedger.isPending())
      return
    }

    this.isSyncing = true
    this.startTiming()
    this.updateStatus('正在同步云端数据...', 'info', cardSyncLedger.isPending(), { nextSyncAt: null })
    const historyStartedAt = new Date().toISOString()
    let downloadedFiles = []
    let uploadedFile = ''
    let localChanges = []
    let remoteChanges = []
    try {
      if (!webdavClient.client) {
        await webdavClient.initialize(config)
      }
      const listResult = await webdavClient.getBackupList()
      if (!listResult.success) throw new Error(listResult.message)
      const automaticFiles = listResult.data.filter((file) =>
          file.filename.includes('[SyncV4]') && file.filename.includes('[自]')
      ).sort((a, b) => {
        const timeDiff = (b.lastModified || 0) - (a.lastModified || 0)
        return timeDiff || String(b.filename).localeCompare(String(a.filename))
      })
      const filesToRead = automaticFiles.slice(0, 5)
      downloadedFiles = filesToRead.map(file => file.filename)
      if (!publishLocalChanges && automaticFiles.length === 0) {
        await this.appendSyncHistory({
          startedAt: historyStartedAt,
          status: 'warning',
          message: '云端还没有同步文件',
          durationMs: this.finishTiming(),
          downloadedFiles: []
        })
        this.updateStatus('云端还没有新版同步文件，可点击“立即同步”用当前本地数据初始化云同步', 'warning', true)
        return
      }
      const newestFilename = automaticFiles[0]?.filename || ''
      const lastSnapshotFilename = cardSyncLedger.lastWebDAVSnapshotFilename()
      const hasPendingBeforeSync = cardSyncLedger.isPending()
      if (!hasPendingBeforeSync && newestFilename && newestFilename === lastSnapshotFilename) {
        this.lastSuccessfulSyncAt = Date.now()
        const durationMs = this.finishTiming()
        await this.appendSyncHistory({
          startedAt: historyStartedAt,
          status: 'success',
          message: '云端文件未变化，已跳过下载解析',
          durationMs,
          downloadedFiles: []
        })
        this.updateStatus('云端文件未变化，已跳过下载解析', 'success', false, { lastDurationMs: durationMs })
        return
      }
      const localRecordsBeforeMerge = cardSyncLedger.load()
      const activeCardsBeforeMerge = activeCards(localRecordsBeforeMerge)
      localChanges = recentLocalChanges(localRecordsBeforeMerge, snapshotDateFromFilename(lastSnapshotFilename))
      const snapshots = await Promise.all(filesToRead.map(async (file) => {
        const restored = await webdavClient.restoreBackup(file.filename)
        if (!restored.success || restored.data == null) return null
        try {
          const snapshot = await decryptSyncEnvelopeV4(restored.data, syncPassword)
          return snapshot.schemaVersion === SYNC_SCHEMA_VERSION ? snapshot : null
        } catch {
          return null
        }
      }))
      if (filesToRead.length > 0 && snapshots.filter(Boolean).length === 0) {
        throw new Error('无法解密云端同步文件，请检查同步密钥')
      }
      const remoteRecords = snapshots.filter(Boolean).flatMap(snapshot => snapshot.records)
      const merged = mergeRecords(localRecordsBeforeMerge, remoteRecords)
      const changedByRemote = JSON.stringify(merged) !== JSON.stringify(localRecordsBeforeMerge)
      await cardSyncLedger.save(merged)
      const activeCardsAfterMerge = activeCards(merged)
      this.onCardsChanged?.(activeCardsAfterMerge)
      remoteChanges = changedByRemote ? diffCards(activeCardsBeforeMerge, activeCardsAfterMerge) : []
      const snapshotRevision = cardSyncLedger.revision()

      if (changedByRemote || cardSyncLedger.isPending() ||
          (automaticFiles.length === 0 && merged.length > 0)) {
        uploadedFile = await webdavClient.uploadSyncSnapshot(createSnapshot(merged), syncPassword)
        if (cardSyncLedger.revision() === snapshotRevision) {
          await cardSyncLedger.setPending(false)
        } else {
          await cardSyncLedger.setPending(true)
          this.queuedPublishLocalChanges = true
        }
        await cardSyncLedger.setLastWebDAVSnapshotFilename(uploadedFile)
        const updatedList = await webdavClient.getBackupList()
        if (updatedList.success) {
          const oldAutomaticFiles = updatedList.data.filter((file) =>
            file.filename.includes('[SyncV4]') && file.filename.includes('[自]')
          ).sort((a, b) => {
            const timeDiff = (b.lastModified || 0) - (a.lastModified || 0)
            return timeDiff || String(b.filename).localeCompare(String(a.filename))
          }).slice(5)
          await Promise.all(oldAutomaticFiles.map(file => webdavClient.deleteBackup(file.filename)))
        }
      } else if (newestFilename) {
        await cardSyncLedger.setLastWebDAVSnapshotFilename(newestFilename)
      }
      this.lastSuccessfulSyncAt = Date.now()
      const durationMs = this.finishTiming()
      await this.appendSyncHistory({
        startedAt: historyStartedAt,
        status: 'success',
        message: this.queuedPublishLocalChanges ? '同步成功：同步期间有新修改，正在继续同步' : '同步成功：本机与云端已更新',
        durationMs,
        uploadedFile,
        downloadedFiles,
        localChanges,
        remoteChanges
      })
      this.updateStatus(
        this.queuedPublishLocalChanges ? '本次同步完成，检测到期间又有新修改，正在继续同步' : '云端数据已更新',
        this.queuedPublishLocalChanges ? 'info' : 'success',
        cardSyncLedger.isPending(),
        { lastDurationMs: durationMs }
      )
    } catch (error) {
      await cardSyncLedger.setPending(true)
      this.lastFailedSyncAt = Date.now()
      const durationMs = this.finishTiming()
      await this.appendSyncHistory({
        startedAt: historyStartedAt,
        status: 'error',
        message: `同步失败：${error.message}`,
        durationMs,
        uploadedFile,
        downloadedFiles,
        localChanges,
        remoteChanges
      }).catch(() => {})
      this.updateStatus(`同步失败，本机改动已保留，稍后可重试：${error.message}`, 'warning', true, { lastDurationMs: durationMs })
    } finally {
      if (this.syncStartedAt) {
        this.finishTiming()
      }
      this.isSyncing = false
      const shouldContinue = this.queuedPublishLocalChanges
      this.queuedPublishLocalChanges = false
      if (shouldContinue) {
        this.synchronize(true)
      } else {
        this.scheduleNextSync(this.syncIntervalMs)
        this.emitCurrentStatus()
      }
    }
  }
}

export const webdavSyncService = new WebDAVSyncService()
