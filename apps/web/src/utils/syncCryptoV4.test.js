import { describe, it, expect } from 'vitest'
import { encryptSyncEnvelopeV4, decryptSyncEnvelopeV4 } from './syncCryptoV4'
describe('unchanged SyncV4 envelope and bounded parsing', () => {
  it('round-trips the existing cross-client metadata and payload', async () => {
    const snapshot = { schemaVersion: '4.0.0', records: [{ cardId: 'a', state: 'deleted' }] }
    const encrypted = await encryptSyncEnvelopeV4(snapshot, 'sync-password')
    expect(JSON.parse(encrypted).encryption.iterations).toBe(310000)
    expect(await decryptSyncEnvelopeV4(encrypted, 'sync-password')).toEqual(snapshot)
  })
  it('rejects malicious KDF values before invoking expensive work', async () => {
    const envelope = JSON.parse(await encryptSyncEnvelopeV4({ records: [] }, 'key'))
    envelope.encryption.iterations = 2147483647
    await expect(decryptSyncEnvelopeV4(envelope, 'key')).rejects.toThrow('参数无效')
  })
})
