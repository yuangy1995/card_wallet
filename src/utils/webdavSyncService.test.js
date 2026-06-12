import { beforeEach, describe, expect, it, vi } from 'vitest'

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

describe('webdav sync service', () => {
  beforeEach(async () => {
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
    await Promise.resolve()
  })
})
