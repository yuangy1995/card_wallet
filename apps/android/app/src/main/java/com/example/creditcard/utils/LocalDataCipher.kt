package com.example.creditcard.utils

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Local-only encryption. Never use this key or envelope for SyncV4/export files. */
interface LocalRecordCipher {
    fun seal(plaintext: ByteArray, purpose: String): ByteArray
    fun open(envelope: ByteArray, purpose: String): ByteArray
}

class AesLocalRecordCipher(private val key: (Boolean) -> SecretKey) : LocalRecordCipher {
    override fun seal(plaintext: ByteArray, purpose: String): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(true)) // AndroidKeyStore generates the unique IV.
        cipher.updateAAD(purpose.toByteArray(Charsets.UTF_8))
        return cipher.iv + cipher.doFinal(plaintext)
    }
    override fun open(envelope: ByteArray, purpose: String): ByteArray {
        require(envelope.size >= 28) { "本地数据格式不完整；原数据已保留" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, envelope.copyOfRange(0, 12)))
        cipher.updateAAD(purpose.toByteArray(Charsets.UTF_8))
        return cipher.doFinal(envelope, 12, envelope.size - 12)
    }
}

class AndroidLocalDataCipher(context: Context, private val alias: String = "card_wallet_local_data_v1") : LocalRecordCipher {
    private val marker = File(context.filesDir, "$alias.marker")
    private val delegate = AesLocalRecordCipher { allowCreation -> loadKey(allowCreation) }
    override fun seal(plaintext: ByteArray, purpose: String) = delegate.seal(plaintext, purpose)
    override fun open(envelope: ByteArray, purpose: String) = delegate.open(envelope, purpose)

    private fun loadKey(allowCreation: Boolean): SecretKey = synchronized(keyLock) {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return@synchronized it }
        check(allowCreation && !marker.exists()) { "未能读取本地加密密钥；请保留原数据并从备份恢复" }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256).setRandomizedEncryptionRequired(true).build())
        val key = generator.generateKey()
        marker.parentFile?.mkdirs()
        marker.writeText("1")
        key
    }
    companion object { private val keyLock = Any() }
}

/** Only legacy reads use the old fixed-password wrapper; successful writes upgrade atomically. */
object LocalSecretEnvelope {
    const val PREFIX = "local-secret-v1:"
    fun seal(value: String, purpose: String, cipher: LocalRecordCipher): String {
        val bytes = value.toByteArray(Charsets.UTF_8)
        return try { PREFIX + Base64.encodeToString(cipher.seal(bytes, purpose), Base64.NO_WRAP) }
        finally { bytes.fill(0) }
    }
    fun open(value: String, purpose: String, cipher: LocalRecordCipher): String {
        if (!value.startsWith(PREFIX)) return CryptoManager.decrypt(value)
        val bytes = cipher.open(Base64.decode(value.removePrefix(PREFIX), Base64.NO_WRAP), purpose)
        return try { bytes.toString(Charsets.UTF_8) } finally { bytes.fill(0) }
    }
}
