import { StorageManager } from './storage'
import { getAppName } from './appName'
import { localDataStore } from './indexedDbStorage'
import { VAULT_META_KEY, unwrapMaster, verifyMaster, importVaultKey, sealBytes, openBytes } from './localVaultCrypto'

const CREDENTIAL_KEY = 'platform_unlock_credential'
const APP_NAME = getAppName()
const USER_NAME = 'credit-card-local-user'

const toBase64Url = (buffer) => {
  const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer)
  let binary = ''
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte)
  })
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '')
}

const fromBase64Url = (value) => {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/')
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=')
  const binary = atob(padded)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}

const randomBytes = (length = 32) => {
  const bytes = new Uint8Array(length)
  crypto.getRandomValues(bytes)
  return bytes
}

const concatBuffers = (first, second) => {
  const a = new Uint8Array(first)
  const b = new Uint8Array(second)
  const combined = new Uint8Array(a.length + b.length)
  combined.set(a, 0)
  combined.set(b, a.length)
  return combined.buffer
}

const decodeClientData = (clientDataJSON) => {
  const text = new TextDecoder().decode(clientDataJSON)
  return JSON.parse(text)
}

const normalizeEcdsaSignature = (signature) => {
  const bytes = new Uint8Array(signature)
  if (bytes.length === 64) return signature
  if (bytes[0] !== 0x30) return signature

  let offset = 2
  if (bytes[1] & 0x80) {
    offset = 2 + (bytes[1] & 0x7f)
  }

  if (bytes[offset] !== 0x02) return signature
  const rLength = bytes[offset + 1]
  let r = bytes.slice(offset + 2, offset + 2 + rLength)
  offset += 2 + rLength

  if (bytes[offset] !== 0x02) return signature
  const sLength = bytes[offset + 1]
  let s = bytes.slice(offset + 2, offset + 2 + sLength)

  if (r.length > 32) r = r.slice(r.length - 32)
  if (s.length > 32) s = s.slice(s.length - 32)

  const raw = new Uint8Array(64)
  raw.set(r, 32 - r.length)
  raw.set(s, 64 - s.length)
  return raw.buffer
}

const getAlgorithmConfig = (algorithm) => {
  if (algorithm === -7) {
    return {
      importAlgorithm: { name: 'ECDSA', namedCurve: 'P-256' },
      verifyAlgorithm: { name: 'ECDSA', hash: 'SHA-256' }
    }
  }

  if (algorithm === -257) {
    return {
      importAlgorithm: { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      verifyAlgorithm: { name: 'RSASSA-PKCS1-v1_5' }
    }
  }

  throw new Error('当前设备返回的解锁密钥格式暂不支持')
}

export class PlatformAuthenticator {
  static CREDENTIAL_KEY = CREDENTIAL_KEY
  static pending = new Set()
  static cancelPending() { this.pending.forEach(controller => controller.abort()); this.pending.clear() }
  static async credentialRequest(kind, options) {
    const controller = new AbortController()
    this.pending.add(controller)
    try { return await navigator.credentials[kind]({ ...options, signal: controller.signal }) }
    finally { this.pending.delete(controller) }
  }

  static isStored() {
    const credential = StorageManager.get(CREDENTIAL_KEY)
    return Boolean(credential?.enabled && credential?.credentialId && credential?.publicKey &&
      credential?.vault?.id === localDataStore.vaultMetadata?.id && credential?.vault?.wrappedKey && credential?.prfSalt)
  }

  static getStoredCredential() {
    return StorageManager.get(CREDENTIAL_KEY)
  }

  static disable() {
    StorageManager.remove(CREDENTIAL_KEY)
  }

  static async isAvailable() {
    if (typeof window === 'undefined') return false
    if (!window.isSecureContext) return false
    if (!window.PublicKeyCredential || !navigator.credentials) return false
    if (!PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable) return false

    try {
      return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()
    } catch {
      return false
    }
  }

  static async register(password) {
    if (!localDataStore.isUnlocked || !password) throw new Error('请先输入当前密码，再开启系统解锁。')
    if (!(await this.isAvailable())) throw new Error('当前浏览器或设备暂不支持系统解锁')
    const session = localDataStore.session
    const metadata = localDataStore.vaultMetadata
    let master
    try { master = await unwrapMaster(password, metadata) }
    catch { throw new Error('当前密码不正确') }
    try {
      const challenge = randomBytes()
      const userId = randomBytes(16)
      const prfSalt = randomBytes()
      if (session !== localDataStore.session) throw new Error('应用已锁定。')
      const credential = await this.credentialRequest('create', { publicKey: {
        challenge, rp: { name: APP_NAME, id: window.location.hostname },
        user: { id: userId, name: USER_NAME, displayName: APP_NAME },
        pubKeyCredParams: [{ type: 'public-key', alg: -7 }, { type: 'public-key', alg: -257 }],
        authenticatorSelection: { authenticatorAttachment: 'platform', residentKey: 'preferred', userVerification: 'required' },
        extensions: { prf: { eval: { first: prfSalt } } }, timeout: 60000, attestation: 'none'
      } })
      if (!credential?.rawId || !credential.response?.getPublicKey?.()) throw new Error('系统解锁注册失败，请更新浏览器后重试。')
      const client = decodeClientData(credential.response.clientDataJSON)
      if (client.type !== 'webauthn.create' || client.challenge !== toBase64Url(challenge) || client.origin !== window.location.origin || client.crossOrigin) throw new Error('系统解锁注册来源或请求不匹配。')
      if (!credential.getClientExtensionResults?.().prf?.enabled) throw new Error('此设备尚不支持加密系统解锁，请继续使用密码。')
      const stored = { enabled: true, credentialId: toBase64Url(credential.rawId),
        publicKey: toBase64Url(credential.response.getPublicKey()), algorithm: credential.response.getPublicKeyAlgorithm?.() || -7,
        userId: toBase64Url(userId), createdAt: Date.now(), prfSalt: toBase64Url(prfSalt) }
      // 再次验证凭证并获得 PRF 输出；不能用“签名成功”替代实际解密能力。
      const secret = await this.assertCredential(stored)
      try {
        const wrappingKey = await importVaultKey(secret)
        stored.vault = { id: metadata.id, wrappedKey: await sealBytes(master, wrappingKey, `wallet:${metadata.id}:credential:${stored.credentialId}`) }
      } finally { secret.fill(0) }
      if (session !== localDataStore.session || !localDataStore.isUnlocked) throw new Error('应用已锁定，请重新开启系统解锁。')
      if (!StorageManager.set(CREDENTIAL_KEY, stored)) throw new Error('系统解锁设置未能保存。')
      return true
    } finally { master.fill(0) }
  }

  static async authenticate() {
    if (!this.isStored()) throw new Error('请先使用密码解锁，再重新开启加密系统解锁。')
    const stored = this.getStoredCredential()
    const session = localDataStore.session
    const secret = await this.assertCredential(stored)
    let master
    try {
      const wrappingKey = await importVaultKey(secret)
      master = await openBytes(stored.vault.wrappedKey, wrappingKey, `wallet:${stored.vault.id}:credential:${stored.credentialId}`)
      const entries = await localDataStore.readEntries()
      const metadata = entries.find(entry => entry.key === VAULT_META_KEY)?.value
      if (metadata?.id !== stored.vault.id) throw new Error('本地保险库已更改，请使用密码解锁。')
      const key = await verifyMaster(master, metadata)
      await localDataStore.openVaultEntries(entries, metadata, key, session)
      return true
    } finally { secret.fill(0); master?.fill(0) }
  }

  static async assertCredential(stored) {
    if (!stored?.enabled || !stored?.credentialId || !stored?.publicKey) {
      throw new Error('尚未开启系统解锁')
    }

    if (!(await this.isAvailable())) {
      throw new Error('当前浏览器或设备暂不支持系统解锁')
    }

    const challenge = randomBytes()
    const assertion = await this.credentialRequest('get', {
      publicKey: {
        challenge,
        allowCredentials: [
          {
            type: 'public-key',
            id: fromBase64Url(stored.credentialId)
          }
        ],
        userVerification: 'required',
        rpId: window.location.hostname,
        extensions: { prf: { eval: { first: fromBase64Url(stored.prfSalt) } } },
        timeout: 60000
      }
    })

    if (!assertion?.response || toBase64Url(assertion.rawId) !== stored.credentialId) {
      throw new Error('系统解锁失败')
    }

    const clientData = decodeClientData(assertion.response.clientDataJSON)
    if (clientData.type !== 'webauthn.get') {
      throw new Error('系统解锁响应无效')
    }

    if (clientData.challenge !== toBase64Url(challenge)) {
      throw new Error('系统解锁请求已失效')
    }

    if (clientData.origin !== window.location.origin || clientData.crossOrigin) {
      throw new Error('系统解锁来源不匹配')
    }

    const authenticatorBytes = new Uint8Array(assertion.response.authenticatorData)
    const rpHash = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(window.location.hostname)))
    if (authenticatorBytes.length < 37 || !rpHash.every((value, index) => value === authenticatorBytes[index])) throw new Error('系统解锁站点不匹配。')
    const flags = authenticatorBytes[32]
    const userPresent = Boolean(flags & 0x01)
    const userVerified = Boolean(flags & 0x04)
    if (!userPresent || !userVerified) {
      throw new Error('请完成本机身份验证')
    }

    const clientDataHash = await crypto.subtle.digest('SHA-256', assertion.response.clientDataJSON)
    const signedData = concatBuffers(assertion.response.authenticatorData, clientDataHash)
    const algorithmConfig = getAlgorithmConfig(stored.algorithm)
    const publicKey = await crypto.subtle.importKey(
      'spki',
      fromBase64Url(stored.publicKey),
      algorithmConfig.importAlgorithm,
      false,
      ['verify']
    )

    const signature = stored.algorithm === -7
      ? normalizeEcdsaSignature(assertion.response.signature)
      : assertion.response.signature
    const verified = await crypto.subtle.verify(
      algorithmConfig.verifyAlgorithm,
      publicKey,
      signature,
      signedData
    )

    if (!verified) {
      throw new Error('系统解锁验证失败')
    }

    const first = assertion.getClientExtensionResults?.().prf?.results?.first
    if (!first || first.byteLength !== 32) throw new Error('此设备无法解密本地保险库，请使用密码。')
    return new Uint8Array(first).slice()
  }
}

if (typeof window !== 'undefined' && window.addEventListener) window.addEventListener('wallet-vault-locked', () => PlatformAuthenticator.cancelPending())
