import { cardSyncLedger } from '@/utils/syncLedger'
import { activeCards, createSnapshot, mergeRecords, SYNC_SCHEMA_VERSION } from '@/utils/syncProtocol'
import { webdavClient } from '@/utils/webdav'
import { decryptSyncEnvelopeV4 } from '@/utils/syncCryptoV4'
import { STORAGE_KEYS } from '@/config/constants'
import { localDataStore } from '@/utils/indexedDbStorage'

const SYNC_HISTORY_LIMIT = 40
const PROGRESS_UI_INTERVAL_MS = 250

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
  return [bank, alias, maskCardNumber(card.cardNumber)]
    .filter(value => value !== '空')
    .join(' / ')
}

const amountText = (value) => {
  if (value === undefined || value === null || value === '') return '空'
  const number = Number(value)
  if (!Number.isFinite(number)) return normalizeDisplayValue(value)
  return Number.isInteger(number) ? String(number) : number.toFixed(2)
}

const categoryText = (value) => value === 'debit' ? '储蓄卡' : '信用卡'

const currencyAmountText = (value, currency) => {
  const amount = amountText(value)
  if (amount === '空') return amount
  const currencyText = normalizeDisplayValue(currency)
  return currencyText === '空' ? amount : `${currencyText} ${amount}`
}

const qualificationText = (value) => {
  if (value === '1') return '已达标'
  if (value === '3') return '终免年费'
  return '未达标'
}

const dateText = (value) => {
  if (value === undefined || value === null || value === '') return '未设置'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '未设置'
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

const imageCountText = (images) => Array.isArray(images) && images.length > 0
  ? `${images.length} 张`
  : '未设置'

const appendFieldChange = (fields, label, oldValue, newValue) => {
  const oldText = normalizeDisplayValue(oldValue)
  const newText = normalizeDisplayValue(newValue)
  if (oldText !== newText) {
    fields.push({ label, oldValue: oldText, newValue: newText })
  }
}

// 新增或本机待同步记录使用完整字段快照，确保历史详情可追溯。
const snapshotFields = (card = {}, isNew = true) => {
  const values = [
    ['卡类别', categoryText(card.cardCategory)],
    ['国家 / 地区', normalizeDisplayValue(card.country)],
    ['发卡银行', normalizeDisplayValue(card.bank)],
    ['卡片别名', normalizeDisplayValue(card.alias)],
    ['卡片等级', normalizeDisplayValue(card.level)],
    ['卡号', maskCardNumber(card.cardNumber)],
    ['有效期', normalizeDisplayValue(card.valid)],
    ['额度', currencyAmountText(card.limit, card.type)],
    ['结算币种', normalizeDisplayValue(card.type)],
    ['共享额度', card.isSharedLimit ? '是' : '否'],
    ['账单日', normalizeDisplayValue(card.accountBillDate)],
    ['还款日', normalizeDisplayValue(card.dueDate)],
    ['账单日消费计入', card.billingDaySpendingToNextBill ? '下期账单' : '当期账单'],
    ['年费金额', currencyAmountText(card.annualFee, card.type)],
    ['年费状态', qualificationText(card.isQualified)],
    ['下次年费收取日', dateText(card.nextAnnualFeeCollectionTime)],
    ['上次提额时间', dateText(card.lastTime)],
    ['权益', normalizeDisplayValue(card.equity)],
    ['备注', normalizeDisplayValue(card.remark)],
    ['卡片图片', imageCountText(card.cardImages)]
  ]

  return values
    .filter(([, value]) => value !== '空' && value !== '未设置')
    .map(([label, value]) => ({
      label,
      oldValue: isNew ? '空' : value,
      newValue: isNew ? value : '空'
    }))
}

const fieldChanges = (before = {}, after = {}) => {
  const fields = []
  appendFieldChange(fields, '卡类别', categoryText(before.cardCategory), categoryText(after.cardCategory))
  appendFieldChange(fields, '国家 / 地区', before.country, after.country)
  appendFieldChange(fields, '发卡银行', before.bank, after.bank)
  appendFieldChange(fields, '卡片别名', before.alias, after.alias)
  appendFieldChange(fields, '卡片等级', before.level, after.level)
  appendFieldChange(fields, '卡号', maskCardNumber(before.cardNumber), maskCardNumber(after.cardNumber))
  appendFieldChange(fields, '有效期', before.valid, after.valid)
  appendFieldChange(fields, '额度', currencyAmountText(before.limit, before.type), currencyAmountText(after.limit, after.type))
  appendFieldChange(fields, '结算币种', before.type, after.type)
  appendFieldChange(fields, '共享额度', before.isSharedLimit ? '是' : '否', after.isSharedLimit ? '是' : '否')
  appendFieldChange(fields, '账单日', before.accountBillDate, after.accountBillDate)
  appendFieldChange(fields, '还款日', before.dueDate, after.dueDate)
  appendFieldChange(
    fields,
    '账单日消费计入',
    before.billingDaySpendingToNextBill ? '下期账单' : '当期账单',
    after.billingDaySpendingToNextBill ? '下期账单' : '当期账单'
  )
  appendFieldChange(fields, '年费金额', currencyAmountText(before.annualFee, before.type), currencyAmountText(after.annualFee, after.type))
  appendFieldChange(fields, '年费状态', qualificationText(before.isQualified), qualificationText(after.isQualified))
  appendFieldChange(fields, '下次年费收取日', dateText(before.nextAnnualFeeCollectionTime), dateText(after.nextAnnualFeeCollectionTime))
  appendFieldChange(fields, '上次提额时间', dateText(before.lastTime), dateText(after.lastTime))
  appendFieldChange(fields, '权益', before.equity, after.equity)
  appendFieldChange(fields, '备注', before.remark, after.remark)
  appendFieldChange(fields, '卡片图片', imageCountText(before.cardImages), imageCountText(after.cardImages))
  return fields.slice(0, 20)
}

const buildCardChange = (kind, before, after) => {
  const card = after || before
  if (!card) return null
  if (kind === 'added') {
    return {
      kind,
      cardId: card.id,
      cardName: cardDisplayName(card),
      fields: snapshotFields(card, true)
    }
  }
  if (kind === 'deleted') {
    return {
      kind,
      cardId: card.id,
      cardName: cardDisplayName(card),
      fields: snapshotFields(card, false)
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
    return {
      kind: 'modified',
      cardId: record.cardId,
      cardName: cardDisplayName(record.card),
      fields: snapshotFields(record.card, true)
    }
  }).filter(Boolean).sort((left, right) => left.cardName.localeCompare(right.cardName, 'zh-CN'))
}

class WebDAVSyncService {
  constructor() {
    this.generation = 0
    this.stopped = false
    this.publishTimer = null
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
      intervalMs: this.syncIntervalMs,
      syncProgress: {
        phase: '空闲',
        step: 0,
        total: 0,
        detail: '',
        totalBytes: 0,
        transferredBytes: 0
      }
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

  updateProgress(phase, step, total, detail = '', totalBytes = 0, transferredBytes = 0) {
    const elapsedMs = this.isSyncing && this.syncStartedAt
      ? Math.max(0, Date.now() - this.syncStartedAt)
      : 0
    this.status = {
      ...this.status,
      elapsedMs,
      syncProgress: {
        phase,
        step,
        total,
        detail,
        totalBytes: Math.max(0, Number(totalBytes || 0)),
        transferredBytes: Math.max(0, Number(transferredBytes || 0))
      }
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
    const generation = this.generation
    const normalized = {
      id: entry.id || globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`,
      startedAt: entry.startedAt || new Date().toISOString(), finishedAt: new Date().toISOString(),
      status: entry.status || 'success', message: entry.message || '', durationMs: Math.max(0, Number(entry.durationMs || 0)),
      uploadedFile: entry.uploadedFile || '', downloadedFiles: entry.downloadedFiles || [],
      localChanges: (entry.localChanges || []).slice(0, 30), remoteChanges: (entry.remoteChanges || []).slice(0, 30)
    }
    const history = [normalized, ...this.syncHistory].slice(0, SYNC_HISTORY_LIMIT)
    await localDataStore.set(STORAGE_KEYS.SYNC_HISTORY, history)
    if (generation !== this.generation || this.stopped) return
    this.syncHistory = history
    this.onHistoryChanged?.([...history])
  }

  async start(cards, onCardsChanged, onStatusChanged, onHistoryChanged) {
    this.stopped = false
    const generation = ++this.generation
    this.onCardsChanged = onCardsChanged
    this.onStatusChanged = onStatusChanged
    this.onHistoryChanged = onHistoryChanged
    this.loadSyncHistory()
    const records = await cardSyncLedger.initialize(cards)
    if (generation !== this.generation || this.stopped) return
    this.onCardsChanged?.(activeCards(records))
    if (!webdavClient.loadConfig()) {
      this.updateStatus('还未设置云同步，本机改动会先保存在本地', 'info')
      return
    }
    this.startAutoSync()
    this.updateStatus('正在后台检查云端数据...', 'info', cardSyncLedger.isPending())
    void this.synchronize(false)
  }

  async commitCards(cards, options = {}) {
    const generation = this.generation
    const before = cardSyncLedger.revision()
    await cardSyncLedger.commit(cards, options)
    if (generation !== this.generation || this.stopped) return
    this.onCardsChanged?.(activeCards(cardSyncLedger.load()))
    if (before === cardSyncLedger.revision()) return
    clearTimeout(this.publishTimer)
    this.publishTimer = setTimeout(() => { this.publishTimer = null; void this.synchronize(true) }, 800)
    this.updateStatus('本机修改已保存，等待同步', 'info', true)
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
    if (this.stopped || typeof window === 'undefined') return
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
    this.stopped = true
    this.generation++
    clearTimeout(this.publishTimer)
    this.publishTimer = null
    this.onCardsChanged = this.onStatusChanged = this.onHistoryChanged = null
    this.stopAutoSync()
    webdavClient.disconnect?.()
    this.syncHistory = []
    this.queuedPublishLocalChanges = false
    this.isSyncing = false
    this.syncStartedAt = null
    this.status = { message: '应用已锁定', type: 'info', pending: false, isSyncing: false, syncProgress: {} }
  }

  async synchronize(publishLocalChanges = false) {
    if (this.stopped || (localDataStore.vaultMetadata && !localDataStore.isUnlocked)) return
    const generation = this.generation
    const check = () => { if (generation !== this.generation || this.stopped) throw new DOMException('同步已取消', 'AbortError') }
    clearTimeout(this.publishTimer)
    this.publishTimer = null
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
    this.updateProgress('准备同步', 1, 6, '正在整理本地修改')
    const historyStartedAt = new Date().toISOString()
    let downloadedFiles = []
    let uploadedFile = ''
    let localChanges = []
    let remoteChanges = []
    try {
      if (!webdavClient.client) {
        await webdavClient.initialize(config)
        check()
      }
      this.updateProgress('读取云端', 2, 6, '正在查找云同步文件')
      const listResult = await webdavClient.getBackupList()
      check()
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
      const totalDownloadBytes = filesToRead.reduce((sum, file) => sum + Math.max(0, Number(file.size || 0)), 0)
      let downloadedBytes = 0
      let lastDownloadProgressReportAt = 0
      const reportDownloadDelta = (delta, force = false) => {
        if (generation !== this.generation || this.stopped || delta <= 0 || totalDownloadBytes <= 0) return
        downloadedBytes = Math.min(totalDownloadBytes, downloadedBytes + delta)
        const now = Date.now()
        if (!force && downloadedBytes < totalDownloadBytes && now - lastDownloadProgressReportAt < PROGRESS_UI_INTERVAL_MS) {
          return
        }
        lastDownloadProgressReportAt = now
        this.updateProgress(
          '读取同步文件',
          3,
          6,
          `正在并发下载最近 ${filesToRead.length} 个快照`,
          totalDownloadBytes,
          downloadedBytes
        )
      }
      this.updateProgress(
        '读取同步文件',
        3,
        6,
        `正在并发下载最近 ${filesToRead.length} 个快照`,
        totalDownloadBytes,
        0
      )
      const snapshots = await Promise.all(filesToRead.map(async (file) => {
        let fileDownloadedBytes = 0
        const restored = await webdavClient.restoreBackup(file.filename, (loaded) => {
          const delta = Number(loaded || 0) - fileDownloadedBytes
          if (delta > 0) {
            fileDownloadedBytes = Number(loaded || 0)
            reportDownloadDelta(delta)
          }
        })
        const remainingBytes = Math.max(0, Number(file.size || 0) - fileDownloadedBytes)
        if (remainingBytes > 0) {
          reportDownloadDelta(remainingBytes, true)
        }
        check()
        if (!restored.success || restored.data == null) throw new Error('部分同步文件下载失败，未合并或清理云端数据。')
        const snapshot = await decryptSyncEnvelopeV4(restored.data, syncPassword)
        check()
        if (snapshot.schemaVersion !== SYNC_SCHEMA_VERSION || !Array.isArray(snapshot.records)) throw new Error('同步文件格式不兼容，未合并或清理云端数据。')
        return snapshot
      }))
      if (filesToRead.length > 0 && snapshots.filter(Boolean).length === 0) {
        throw new Error('无法解密云端同步文件，请检查同步密钥')
      }
      check()
      const remoteRecords = snapshots.flatMap(snapshot => snapshot.records)
      this.updateProgress('合并数据', 4, 6, '正在合并本地与云端修改')
      // 下载期间允许本地编辑；从提交队列中读取最新账本，不能写回下载前的旧副本。
      const beforeLatestMerge = cardSyncLedger.load()
      const snapshotRevision = cardSyncLedger.revision()
      const merged = await cardSyncLedger.merge(remoteRecords)
      check()
      const changedByRemote = JSON.stringify(merged) !== JSON.stringify(beforeLatestMerge)
      const activeCardsAfterMerge = activeCards(merged)
      this.onCardsChanged?.(activeCardsAfterMerge)
      remoteChanges = changedByRemote ? diffCards(activeCardsBeforeMerge, activeCardsAfterMerge) : []
      if (changedByRemote || cardSyncLedger.isPending() ||
          (automaticFiles.length === 0 && merged.length > 0)) {
        let lastUploadProgressReportAt = 0
        webdavClient.setProgressCallback?.((type, loaded, total) => {
          if (generation !== this.generation || this.stopped || type !== 'upload') return
          const uploadedBytes = Number(loaded || 0)
          const totalBytes = Number(total || 0)
          const now = Date.now()
          if (uploadedBytes < totalBytes && now - lastUploadProgressReportAt < PROGRESS_UI_INTERVAL_MS) {
            return
          }
          lastUploadProgressReportAt = now
          this.updateProgress(
            '上传合并快照',
            5,
            6,
            '正在写入 WebDAV 加密快照',
            totalBytes,
            uploadedBytes
          )
        })
        this.updateProgress('上传合并快照', 5, 6, '正在写入 WebDAV 加密快照')
        uploadedFile = await webdavClient.uploadSyncSnapshot(createSnapshot(merged), syncPassword)
        webdavClient.setProgressCallback?.(null)
        check()
        this.queuedPublishLocalChanges = await cardSyncLedger.acknowledgeUpload(uploadedFile, snapshotRevision) || this.queuedPublishLocalChanges
        check()
        // 只清理本轮确实读取并成功合并的旧快照，保留上传期间其他设备新增的文件。
        const deletable = filesToRead.slice(4).filter(file => file.filename !== uploadedFile)
        for (const file of deletable) {
          check()
          const removed = await webdavClient.deleteBackup(file.filename)
          check()
          if (!removed.success) break
        }
      } else if (newestFilename) {
        await cardSyncLedger.setLastWebDAVSnapshotFilename(newestFilename)
      }
      check()
      this.lastSuccessfulSyncAt = Date.now()
      const durationMs = this.finishTiming()
      this.updateProgress('同步完成', 6, 6, '本机与云端已更新')
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
      if (generation !== this.generation || this.stopped || error.name === 'AbortError') return
      webdavClient.setProgressCallback?.(null)
      await cardSyncLedger.setPending(true).catch(() => {})
      if (generation !== this.generation || this.stopped) return
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
      if (generation !== this.generation || this.stopped) return
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

if (typeof window !== 'undefined') window.addEventListener('wallet-vault-locked', () => webdavSyncService.stop())
