import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { webcrypto } from 'node:crypto'
import { PlatformAuthenticator } from './platformAuthenticator'
import { localDataStore } from './indexedDbStorage'
import { createDatabase } from './vaultDatabase.testUtils'
const password = 'local-test-password'
const encoder = new TextEncoder()
const base64url = data => Buffer.from(data).toString('base64url')
let values, credentialKey, prf, supportsPRF, badRP, badID, makeAssertion
beforeEach(async () => {
  vi.stubGlobal('crypto', webcrypto)
  vi.stubGlobal('window', { isSecureContext: true, location: { origin: 'https://wallet.example', hostname: 'wallet.example' }, dispatchEvent: () => {} })
  vi.stubGlobal('PublicKeyCredential', { isUserVerifyingPlatformAuthenticatorAvailable: async () => true })
  window.PublicKeyCredential = PublicKeyCredential
  values = new Map()
  vi.stubGlobal('localStorage', { getItem: k => values.get(k) ?? null, setItem: (k,v) => values.set(k,v), removeItem: k => values.delete(k) })
  vi.stubGlobal('indexedDB', createDatabase().indexedDB)
  await localDataStore.resetForTests(); await localDataStore.initialize(); await localDataStore.enableVault(password)
  await localDataStore.set('cards', [{ bank: 'CONFIDENTIAL_BANK' }])
  credentialKey = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign','verify'])
  const spki = await crypto.subtle.exportKey('spki', credentialKey.publicKey)
  prf = crypto.getRandomValues(new Uint8Array(32))
  supportsPRF = true; badRP = false; badID = false
  makeAssertion = async ({ publicKey }) => {
    const clientDataJSON = encoder.encode(JSON.stringify({ type: 'webauthn.get', challenge: base64url(publicKey.challenge), origin: window.location.origin }))
    const auth = new Uint8Array(37)
    auth.set(new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(badRP ? 'evil.example' : 'wallet.example'))))
    auth[32] = 5
    const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', clientDataJSON))
    const signed = new Uint8Array(69); signed.set(auth); signed.set(hash,37)
    const signature = await crypto.subtle.sign({ name:'ECDSA',hash:'SHA-256' },credentialKey.privateKey,signed)
    return { rawId: new Uint8Array([badID ? 9 : 1,2,3]).buffer, response: { clientDataJSON, authenticatorData: auth, signature },
      getClientExtensionResults: () => supportsPRF ? { prf: { results: { first: prf.buffer } } } : {} }
  }
  vi.stubGlobal('navigator', { credentials: {
    create: async ({ publicKey }) => ({ rawId: new Uint8Array([1,2,3]).buffer, response: {
      getPublicKey: () => spki, getPublicKeyAlgorithm: () => -7,
      clientDataJSON: encoder.encode(JSON.stringify({ type:'webauthn.create',challenge:base64url(publicKey.challenge),origin:window.location.origin })) },
      getClientExtensionResults: () => ({ prf: { enabled: supportsPRF } }) }),
    get: vi.fn(options => makeAssertion(options))
  } })
})
afterEach(async () => { await localDataStore.resetForTests(); vi.unstubAllGlobals() })
describe('PRF-backed platform unlock', () => {
  it('stores only a PRF-wrapped master key and actually decrypts on authentication', async () => {
    await PlatformAuthenticator.register(password)
    const stored = JSON.parse(values.get(PlatformAuthenticator.CREDENTIAL_KEY))
    expect(stored.vault.wrappedKey.format).toBe('card-wallet-sealed-v1')
    expect(JSON.stringify(stored)).not.toContain(password)
    expect(JSON.stringify(stored)).not.toContain('CONFIDENTIAL_BANK')
    localDataStore.lock()
    expect(await PlatformAuthenticator.authenticate()).toBe(true)
    expect(localDataStore.get('cards')).toEqual([{ bank: 'CONFIDENTIAL_BANK' }])
  })
  it('does not offer old signature-only credentials as encrypted unlock', () => {
    values.set(PlatformAuthenticator.CREDENTIAL_KEY, JSON.stringify({ enabled:true,credentialId:'old',publicKey:'key' }))
    expect(PlatformAuthenticator.isStored()).toBe(false)
  })
  it('refuses registration without PRF instead of storing an unencrypted key', async () => {
    supportsPRF = false
    await expect(PlatformAuthenticator.register(password)).rejects.toThrow('尚不支持加密')
    expect(values.has(PlatformAuthenticator.CREDENTIAL_KEY)).toBe(false)
  })
  it('does not unlock when the assertion lacks PRF even with a valid signature', async () => {
    await PlatformAuthenticator.register(password); localDataStore.lock(); supportsPRF = false
    await expect(PlatformAuthenticator.authenticate()).rejects.toThrow('无法解密')
    expect(localDataStore.isUnlocked).toBe(false)
  })
  it('rejects a signed assertion for a different relying party', async () => {
    await PlatformAuthenticator.register(password); localDataStore.lock(); badRP = true
    await expect(PlatformAuthenticator.authenticate()).rejects.toThrow('站点')
    expect(localDataStore.isUnlocked).toBe(false)
  })
  it('rejects a credential ID mismatch', async () => {
    await PlatformAuthenticator.register(password); localDataStore.lock(); badID = true
    await expect(PlatformAuthenticator.authenticate()).rejects.toThrow()
    expect(localDataStore.isUnlocked).toBe(false)
  })
})
