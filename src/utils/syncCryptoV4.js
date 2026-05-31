const ENVELOPE_SCHEMA_VERSION = '4.0.0'
const KDF_ITERATIONS = 310000
const SALT_BYTES = 16
const IV_BYTES = 12

const getSubtleCrypto = () => {
  const subtle = globalThis.crypto?.subtle
  if (!subtle) {
    throw new Error('当前环境不支持安全云同步加密')
  }
  return subtle
}

const randomBytes = (length) => {
  const bytes = new Uint8Array(length)
  globalThis.crypto.getRandomValues(bytes)
  return bytes
}

const bytesToBase64 = (bytes) => {
  let binary = ''
  const chunkSize = 0x8000
  for (let index = 0; index < bytes.length; index += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(index, index + chunkSize))
  }
  return btoa(binary)
}

const base64ToBytes = (value) => {
  const binary = atob(value)
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index)
  }
  return bytes
}

const deriveAesKey = async (password, salt, iterations) => {
  const normalizedPassword = String(password || '').trim()
  if (!normalizedPassword) {
    throw new Error('请输入同步密钥')
  }
  const subtle = getSubtleCrypto()
  const passwordBytes = new TextEncoder().encode(normalizedPassword)
  const baseKey = await subtle.importKey(
    'raw',
    passwordBytes,
    { name: 'PBKDF2' },
    false,
    ['deriveKey']
  )
  return subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt,
      iterations,
      hash: 'SHA-256'
    },
    baseKey,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  )
}

export const encryptSyncEnvelopeV4 = async (snapshot, password) => {
  const subtle = getSubtleCrypto()
  const salt = randomBytes(SALT_BYTES)
  const iv = randomBytes(IV_BYTES)
  const key = await deriveAesKey(password, salt, KDF_ITERATIONS)
  const plaintext = new TextEncoder().encode(JSON.stringify(snapshot))
  const encrypted = await subtle.encrypt({ name: 'AES-GCM', iv }, key, plaintext)

  return JSON.stringify({
    schemaVersion: ENVELOPE_SCHEMA_VERSION,
    encryption: {
      version: 1,
      algorithm: 'AES-256-GCM',
      kdf: 'PBKDF2-HMAC-SHA256',
      iterations: KDF_ITERATIONS,
      salt: bytesToBase64(salt),
      iv: bytesToBase64(iv)
    },
    ciphertext: bytesToBase64(new Uint8Array(encrypted))
  })
}

export const decryptSyncEnvelopeV4 = async (rawEnvelope, password) => {
  const subtle = getSubtleCrypto()
  const envelope = typeof rawEnvelope === 'string' ? JSON.parse(rawEnvelope) : rawEnvelope
  if (envelope?.schemaVersion !== ENVELOPE_SCHEMA_VERSION || !envelope?.encryption || !envelope?.ciphertext) {
    throw new Error('不是有效的云同步加密文件')
  }
  const encryption = envelope.encryption
  if (encryption.algorithm !== 'AES-256-GCM' || encryption.kdf !== 'PBKDF2-HMAC-SHA256') {
    throw new Error('不支持的云同步加密算法')
  }

  const salt = base64ToBytes(encryption.salt)
  const iv = base64ToBytes(encryption.iv)
  const ciphertext = base64ToBytes(envelope.ciphertext)
  const key = await deriveAesKey(password, salt, encryption.iterations || KDF_ITERATIONS)

  try {
    const decrypted = await subtle.decrypt({ name: 'AES-GCM', iv }, key, ciphertext)
    return JSON.parse(new TextDecoder().decode(decrypted))
  } catch (error) {
    throw new Error('云同步解密失败，请检查同步密钥是否正确')
  }
}
