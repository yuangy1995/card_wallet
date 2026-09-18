// 本地保险库与 SyncV4 分离，不改变云端格式。仅支持 HTTPS/localhost 的 Web Crypto。
export const VAULT_META_KEY = 'walletLocalVaultV1'
export const VAULT_ITERATIONS = 600000
const encoder = new TextEncoder()
const decoder = new TextDecoder()
const subtle = () => {
  if (!globalThis.crypto?.subtle) throw new Error('本地加密需要安全连接，请使用 HTTPS 或 localhost 打开。')
  return globalThis.crypto.subtle
}
export const randomBytes = length => crypto.getRandomValues(new Uint8Array(length))
export const toBase64 = bytes => {
  let text = ''
  for (let i = 0; i < bytes.length; i += 32768) text += String.fromCharCode(...bytes.subarray(i, i + 32768))
  return btoa(text)
}
export const fromBase64 = text => Uint8Array.from(atob(text), char => char.charCodeAt(0))
export const importVaultKey = bytes => subtle().importKey('raw', bytes, 'AES-GCM', false, ['encrypt', 'decrypt'])
async function passwordKey(password, salt) {
  const bytes = encoder.encode(password)
  try {
    const base = await subtle().importKey('raw', bytes, 'PBKDF2', false, ['deriveKey'])
    return await subtle().deriveKey({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations: VAULT_ITERATIONS }, base, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt'])
  } finally { bytes.fill(0) }
}
export async function sealBytes(bytes, key, purpose) {
  const iv = randomBytes(12)
  const encrypted = await subtle().encrypt({ name: 'AES-GCM', iv, additionalData: encoder.encode(purpose), tagLength: 128 }, key, bytes)
  return { format: 'card-wallet-sealed-v1', iv: toBase64(iv), ciphertext: toBase64(new Uint8Array(encrypted)) }
}
export async function openBytes(value, key, purpose) {
  if (value?.format !== 'card-wallet-sealed-v1') throw new Error('本地加密数据格式无效，未修改原数据。')
  const iv = fromBase64(value.iv)
  if (iv.length !== 12) throw new Error('本地加密数据校验失败。')
  return new Uint8Array(await subtle().decrypt({ name: 'AES-GCM', iv, additionalData: encoder.encode(purpose), tagLength: 128 }, key, fromBase64(value.ciphertext)))
}
export async function sealValue(value, key, vaultId, storageKey) {
  const bytes = encoder.encode(JSON.stringify(value))
  try { return await sealBytes(bytes, key, `wallet:${vaultId}:row:${storageKey}`) }
  finally { bytes.fill(0) }
}
export async function openValue(value, key, vaultId, storageKey) {
  const bytes = await openBytes(value, key, `wallet:${vaultId}:row:${storageKey}`)
  try { return JSON.parse(decoder.decode(bytes)) }
  finally { bytes.fill(0) }
}
export function validateMetadata(metadata) {
  if (metadata?.format !== 'card-wallet-local-v1' || metadata.iterations !== VAULT_ITERATIONS ||
      typeof metadata.id !== 'string' || !metadata.id || fromBase64(metadata.salt).length !== 16) {
    throw new Error('本地保险库版本或参数不受支持，原数据已保留。')
  }
}
export async function unwrapMaster(password, metadata) {
  validateMetadata(metadata)
  const key = await passwordKey(password, fromBase64(metadata.salt))
  return openBytes(metadata.wrappedKey, key, `wallet:${metadata.id}:master:v1`)
}
export async function wrapMaster(password, bytes, id = crypto.randomUUID()) {
  const salt = randomBytes(16)
  const key = await passwordKey(password, salt)
  return { format: 'card-wallet-local-v1', id, iterations: VAULT_ITERATIONS, salt: toBase64(salt),
    wrappedKey: await sealBytes(bytes, key, `wallet:${id}:master:v1`) }
}
export async function createVault(password) {
  const bytes = randomBytes(32)
  try {
    const metadata = await wrapMaster(password, bytes)
    const key = await importVaultKey(bytes)
    metadata.check = await sealValue('card-wallet-vault-check', key, metadata.id, '$check')
    metadata.revision = 0
    return { metadata, key }
  } finally { bytes.fill(0) }
}
export async function verifyMaster(bytes, metadata) {
  const key = await importVaultKey(bytes)
  if (await openValue(metadata.check, key, metadata.id, '$check') !== 'card-wallet-vault-check') throw new Error('本地保险库校验失败。')
  return key
}
