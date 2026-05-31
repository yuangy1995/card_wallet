import { cardSyncLedger } from '@/utils/syncLedger'
import { activeCards, createSnapshot, mergeRecords, SYNC_SCHEMA_VERSION } from '@/utils/syncProtocol'
import { webdavClient } from '@/utils/webdav'
import { decryptSyncEnvelopeV4 } from '@/utils/syncCryptoV4'

class WebDAVSyncService {
  constructor() {
    this.onCardsChanged = null
    this.onStatusChanged = null
    this.isSyncing = false
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

  async start(cards, onCardsChanged, onStatusChanged) {
    this.onCardsChanged = onCardsChanged
    this.onStatusChanged = onStatusChanged
    const records = cardSyncLedger.initialize(cards)
    this.onCardsChanged(activeCards(records))

    const config = webdavClient.loadConfig()
    if (!config) {
      this.updateStatus('还未设置云同步，本机改动会先保存在本地', 'info')
      return
    }
    try {
      this.startAutoSync()
      if (!webdavClient.client) {
        await webdavClient.initialize(config)
      }
      await this.synchronize(false)
    } catch (error) {
      this.updateStatus(`云同步暂时不可用：${error.message}`, 'warning')
    }
  }

  async commitCards(cards, options = {}) {
    cardSyncLedger.commit(cards, options)
    this.onCardsChanged?.(activeCards(cardSyncLedger.load()))
    await this.synchronize(true)
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
      if (!publishLocalChanges && automaticFiles.length === 0) {
        this.updateStatus('云端还没有新版同步文件，可点击“立即同步”用当前本地数据初始化云同步', 'warning', true)
        return
      }
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
      const localRecords = cardSyncLedger.load()
      const remoteRecords = snapshots.filter(Boolean).flatMap(snapshot => snapshot.records)
      const merged = mergeRecords(localRecords, remoteRecords)
      const changedByRemote = JSON.stringify(merged) !== JSON.stringify(localRecords)
      cardSyncLedger.save(merged)
      this.onCardsChanged?.(activeCards(merged))
      const snapshotRevision = cardSyncLedger.revision()

      if (publishLocalChanges || changedByRemote || cardSyncLedger.isPending() ||
          (automaticFiles.length === 0 && merged.length > 0)) {
        await webdavClient.uploadSyncSnapshot(createSnapshot(merged), syncPassword)
        if (cardSyncLedger.revision() === snapshotRevision) {
          cardSyncLedger.setPending(false)
        } else {
          cardSyncLedger.setPending(true)
          this.queuedPublishLocalChanges = true
        }
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
      }
      this.lastSuccessfulSyncAt = Date.now()
      const durationMs = this.finishTiming()
      this.updateStatus(
        this.queuedPublishLocalChanges ? '本次同步完成，检测到期间又有新修改，正在继续同步' : '云端数据已更新',
        this.queuedPublishLocalChanges ? 'info' : 'success',
        cardSyncLedger.isPending(),
        { lastDurationMs: durationMs }
      )
    } catch (error) {
      cardSyncLedger.setPending(true)
      this.lastFailedSyncAt = Date.now()
      const durationMs = this.finishTiming()
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
