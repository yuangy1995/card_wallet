import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const mocks = vi.hoisted(() => {
  const snapshot = {
    schemaVersion: '4.0.0',
    records: [{
      cardId: 'remote-card',
      mutationId: 'remote-mutation',
      changedAt: '2026-06-01T00:00:00.000Z',
      state: 'active',
      card: {
        id: 'remote-card',
        country: 'CN',
        bank: 'Remote Bank',
        cardNumber: '6224000000005468',
        lastModifyTime: Date.parse('2026-06-01T00:00:00.000Z')
      }
    }]
  }
  return {
    snapshot,
    envelopeObject: {
      schemaVersion: '4.0.0',
      encryption: {
        algorithm: 'AES-256-GCM',
        kdf: 'PBKDF2-HMAC-SHA256'
      },
      ciphertext: 'encrypted'
    },
    decryptSyncEnvelopeV4: vi.fn(async () => snapshot),
    webdavClient: {
      client: {},
      loadConfig: vi.fn(() => ({ syncPassword: ' sync-key-with-spaces ' })),
      initialize: vi.fn(),
      getBackupList: vi.fn(async () => ({
        success: true,
        data: [{
          filename: '2026-06-01---(1)[SyncV4][Web][自].json',
          lastModified: Date.parse('2026-06-01T00:00:00.000Z')
        }]
      })),
      restoreBackup: vi.fn(async () => ({ success: true, data: null })),
      uploadSyncSnapshot: vi.fn(async () => 'uploaded.json'),
      deleteBackup: vi.fn(async () => ({ success: true }))
    }
  }
})

vi.mock('@/utils/syncCryptoV4', () => ({
  decryptSyncEnvelopeV4: mocks.decryptSyncEnvelopeV4
}))

vi.mock('@/utils/webdav', () => ({
  webdavClient: mocks.webdavClient
}))

import { webdavSyncService } from './webdavSyncService'
import { localDataStore } from './indexedDbStorage'
import { createIndexedDbMock } from './indexedDbStorage.testUtils'
import { STORAGE_KEYS } from '@/config/constants'
import { cardSyncLedger } from './syncLedger'
import { activeCards } from './syncProtocol'

describe('webdav sync service', () => {
  afterEach(() => { webdavSyncService.stop(); vi.useRealTimers() })
  beforeEach(async () => {
    webdavSyncService.stop()
    webdavSyncService.stopped = false
    const values = new Map()
    vi.stubGlobal('localStorage', {
      getItem: (key) => values.has(key) ? values.get(key) : null,
      setItem: (key, value) => values.set(key, String(value)),
      removeItem: (key) => values.delete(key),
      clear: () => values.clear()
    })
    vi.stubGlobal('indexedDB', createIndexedDbMock())
    await localDataStore.resetForTests()
    await localDataStore.initialize()
    vi.clearAllMocks()
    mocks.webdavClient.client = {}
    mocks.webdavClient.loadConfig.mockReturnValue({ syncPassword: ' sync-key-with-spaces ' })
    mocks.webdavClient.getBackupList.mockResolvedValue({
      success: true,
      data: [{
        filename: '2026-06-01---(1)[SyncV4][Web][自].json',
        lastModified: Date.parse('2026-06-01T00:00:00.000Z')
      }]
    })
    mocks.webdavClient.restoreBackup.mockResolvedValue({ success: true, data: mocks.envelopeObject })
    mocks.decryptSyncEnvelopeV4.mockResolvedValue(mocks.snapshot)
    webdavSyncService.isSyncing = false
    webdavSyncService.queuedPublishLocalChanges = false
    webdavSyncService.onCardsChanged = null
    webdavSyncService.onStatusChanged = null
  })

  it('decrypts cloud sync files even when restoreBackup already parsed the JSON envelope', async () => {
    const onCardsChanged = vi.fn()
    webdavSyncService.onCardsChanged = onCardsChanged

    await webdavSyncService.synchronize(false)

    expect(mocks.decryptSyncEnvelopeV4).toHaveBeenCalledWith(mocks.envelopeObject, 'sync-key-with-spaces')
    expect(onCardsChanged).toHaveBeenCalledWith([
      expect.objectContaining({ id: 'remote-card', bank: 'Remote Bank' })
    ])
    expect(mocks.webdavClient.uploadSyncSnapshot).toHaveBeenCalled()
  })

  it('starts initial cloud sync in the background without blocking app entry', async () => {
    const onCardsChanged = vi.fn()
    const onStatusChanged = vi.fn()
    let resolveBackupList
    mocks.webdavClient.getBackupList.mockReturnValue(new Promise((resolve) => {
      resolveBackupList = resolve
    }))

    const result = await webdavSyncService.start([
      {
        id: 'local-card',
        country: 'CN',
        bank: 'Local Bank',
        cardNumber: '6224000000000000',
        lastModifyTime: Date.parse('2026-06-01T00:00:00.000Z')
      }
    ], onCardsChanged, onStatusChanged)

    expect(result).toBeUndefined()
    expect(onCardsChanged).toHaveBeenCalledWith([
      expect.objectContaining({ id: 'local-card', bank: 'Local Bank' })
    ])
    expect(mocks.webdavClient.getBackupList).toHaveBeenCalled()
    expect(onStatusChanged).toHaveBeenCalledWith(
      expect.objectContaining({ message: '正在后台检查云端数据...', isSyncing: false })
    )

    resolveBackupList({ success: true, data: [] })
    await vi.waitFor(() => expect(webdavSyncService.isSyncing).toBe(false))
  })

  it('does not download or upload when a manual sync sees the same latest cloud snapshot', async () => {
    await localDataStore.set(STORAGE_KEYS.SYNC_LAST_SNAPSHOT, '2026-06-01---(1)[SyncV4][Web][自].json')
    await localDataStore.set(STORAGE_KEYS.SYNC_PENDING, false)

    await webdavSyncService.synchronize(true)

    expect(mocks.webdavClient.restoreBackup).not.toHaveBeenCalled()
    expect(mocks.decryptSyncEnvelopeV4).not.toHaveBeenCalled()
    expect(mocks.webdavClient.uploadSyncSnapshot).not.toHaveBeenCalled()
  })
  it('does not upload or delete backups when any selected snapshot cannot be decrypted', async () => {
    mocks.webdavClient.getBackupList.mockResolvedValue({ success: true, data: [
      { filename: 'a[SyncV4][自].json' }, { filename: 'b[SyncV4][自].json' }
    ] })
    mocks.decryptSyncEnvelopeV4.mockResolvedValueOnce(mocks.snapshot).mockRejectedValueOnce(new Error('bad ciphertext'))
    await webdavSyncService.synchronize(true)
    expect(mocks.webdavClient.uploadSyncSnapshot).not.toHaveBeenCalled()
    expect(mocks.webdavClient.deleteBackup).not.toHaveBeenCalled()
    expect(cardSyncLedger.load()).toEqual([])
  })

  it('preserves a newer local edit made while downloading cloud snapshots', async () => {
    await cardSyncLedger.initialize([])
    let finish
    mocks.webdavClient.restoreBackup.mockReturnValue(new Promise(resolve => { finish = resolve }))
    const syncing = webdavSyncService.synchronize(true)
    await vi.waitFor(() => expect(finish).toBeTypeOf('function'))
    await cardSyncLedger.commit([{ ...mocks.snapshot.records[0].card, bank: 'EDITED WHILE DOWNLOADING' }])
    finish({ success: true, data: mocks.envelopeObject })
    await syncing
    expect(activeCards(cardSyncLedger.load())[0].bank).toBe('EDITED WHILE DOWNLOADING')
    expect(mocks.webdavClient.uploadSyncSnapshot.mock.calls[0][0].records[0].card.bank).toBe('EDITED WHILE DOWNLOADING')
  })

  it('drops callbacks and further network actions if locked during a download', async () => {
    let finish
    mocks.webdavClient.restoreBackup.mockReturnValue(new Promise(resolve => { finish = resolve }))
    const changed = vi.fn()
    webdavSyncService.onCardsChanged = changed
    const syncing = webdavSyncService.synchronize(true)
    await vi.waitFor(() => expect(finish).toBeTypeOf('function'))
    webdavSyncService.stop()
    finish({ success: true, data: mocks.envelopeObject })
    await syncing
    expect(changed).not.toHaveBeenCalled()
    expect(mocks.webdavClient.uploadSyncSnapshot).not.toHaveBeenCalled()
    expect(mocks.webdavClient.deleteBackup).not.toHaveBeenCalled()
    expect(webdavSyncService.syncHistory).toEqual([])
    expect(webdavSyncService.syncTimer).toBeNull()
  })

  it('saves a burst of edits immediately but coalesces uploads', async () => {
    vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] })
    const synchronize = vi.spyOn(webdavSyncService, 'synchronize').mockResolvedValue(undefined)
    try {
      for (let i = 0; i < 10; i++) await webdavSyncService.commitCards([{ id: 'local', bank: String(i), country: 'CN', cardNumber: '1234' }])
      expect(activeCards(cardSyncLedger.load())[0].bank).toBe('9')
      expect(synchronize).not.toHaveBeenCalled()
      await vi.advanceTimersByTimeAsync(800)
      expect(synchronize).toHaveBeenCalledTimes(1)
    } finally { synchronize.mockRestore() }
  })

  it('does not clear a pending edit when acknowledging an older upload', async () => {
    await cardSyncLedger.initialize([])
    await cardSyncLedger.commit([{ id: 'a', bank: 'first' }])
    const revision = cardSyncLedger.revision()
    await cardSyncLedger.commit([{ id: 'a', bank: 'second' }])
    expect(await cardSyncLedger.acknowledgeUpload('snapshot.json', revision)).toBe(true)
    expect(cardSyncLedger.isPending()).toBe(true)
  })

})
