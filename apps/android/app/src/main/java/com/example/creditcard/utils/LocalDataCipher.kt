package com.example.creditcard.utils

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Device-bound local protection, independent of the portable SyncV4 password/envelope. */
object LocalDataCipher {
    const val PREFIX = "card-wallet-local-v1:"
    private const val ALIAS = "com.applist.cardwallet.local-data.v1"
    @Synchronized private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        check(create) { "无法读取本机加密密钥，原数据已保留" }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    fun seal(plain: String, purpose: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(true))
        cipher.updateAAD(purpose.toByteArray(Charsets.UTF_8))
        val bytes = plain.toByteArray(Charsets.UTF_8)
        return try { PREFIX + Base64.encodeToString(cipher.iv + cipher.doFinal(bytes), Base64.NO_WRAP) }
            finally { bytes.fill(0) }
    }
    fun open(sealed: String, purpose: String): String {
        require(sealed.startsWith(PREFIX)) { "本地加密数据格式不受支持，原数据已保留" }
        val bytes = Base64.decode(sealed.removePrefix(PREFIX), Base64.NO_WRAP)
        require(bytes.size >= 28) { "本地加密数据校验失败" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, bytes.copyOfRange(0,12)))
        cipher.updateAAD(purpose.toByteArray(Charsets.UTF_8))
        val plain = cipher.doFinal(bytes,12,bytes.size-12)
        return try { plain.toString(Charsets.UTF_8) } finally { plain.fill(0) }
    }
}
