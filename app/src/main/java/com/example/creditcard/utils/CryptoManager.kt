package com.example.creditcard.utils

import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * 信用卡数据加解密管理工具类
 * 与 Web 端及 Mac 端 CryptoJS/OpenSSL AES 算法 100% 互通
 */
object CryptoManager {
    private const val DEFAULT_PASSWORD = "defAult.@.Password."
    private val MAGIC_NUMBER = "Salted__".toByteArray(Charsets.UTF_8)

    /**
     * 还原 OpenSSL EVP_BytesToKey / CryptoJS 密钥派生算法
     * 派生出 48 字节数据 (32 字节 Key + 16 字节 IV)
     */
    private fun deriveKeyAndIV(password: String, salt: ByteArray): Pair<ByteArray, ByteArray> {
        val keyAndIV = ByteArray(48)
        var lastDigest = ByteArray(0)
        val passwordBytes = password.toByteArray(Charsets.UTF_8)

        var offset = 0
        val md = MessageDigest.getInstance("MD5")
        while (offset < 48) {
            md.reset()
            md.update(lastDigest)
            md.update(passwordBytes)
            md.update(salt)
            lastDigest = md.digest()

            val bytesToCopy = minOf(lastDigest.size, 48 - offset)
            System.arraycopy(lastDigest, 0, keyAndIV, offset, bytesToCopy)
            offset += bytesToCopy
        }

        val key = keyAndIV.copyOfRange(0, 32)
        val iv = keyAndIV.copyOfRange(32, 48)
        return Pair(key, iv)
    }

    /**
     * 100% 互通解密 Web/Mac 端 CryptoJS 生成的 AES 密文
     *
     * @param cipherText 加密密文（带 default: 或 encrypted: 前缀）
     * @param password 自定义密码（若前缀是 encrypted:，该值必填）
     * @return 解密后的原始 JSON 字符串
     */
    fun decrypt(cipherText: String, password: String? = null): String {
        // 过滤由于数据传输或 JSON 包装产生的两侧双引号、空白和换行符，进行极致清洗
        val cleanCipher = cipherText.trim().removeSurrounding("\"")
        val isDefault = cleanCipher.startsWith("default:")
        val isEncrypted = cleanCipher.startsWith("encrypted:")

        if (!isDefault && !isEncrypted) {
            throw IllegalArgumentException("密文损坏：魔数验证失败")
        }

        // 剥离前缀
        val prefixLength = if (isDefault) 8 else 10
        val actualBase64 = cleanCipher.substring(prefixLength).trim()
        val decodedBytes = Base64.decode(actualBase64, Base64.DEFAULT)

        // 校验 OpenSSL "Salt__" 头 (8 字节魔数: 0x53616c7465645f5f)
        if (decodedBytes.size <= 16 || !decodedBytes.copyOfRange(0, 8).contentEquals(MAGIC_NUMBER)) {
            throw IllegalArgumentException("密文损坏：不是 CryptoJS 格式")
        }

        // 提取盐值 (8 字节) 和真正密文
        val salt = decodedBytes.copyOfRange(8, 16)
        val encryptedData = decodedBytes.copyOfRange(16, decodedBytes.size)

        // 决定使用默认密码还是自定义密码
        val activePassword = if (isDefault) {
            DEFAULT_PASSWORD
        } else {
            password ?: throw IllegalArgumentException("请输入自定义解密密码")
        }

        // 派生 Key 和 IV
        val (key, iv) = deriveKeyAndIV(activePassword, salt)

        // 执行 AES/CBC/PKCS5Padding 解密
        try {
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
            val decryptedBytes = cipher.doFinal(encryptedData)
            return String(decryptedBytes, Charsets.UTF_8)
        } catch (e: Exception) {
            throw IllegalArgumentException("解密失败，可能密码错误或数据损坏", e)
        }
    }

    /**
     * 生成兼容 CryptoJS 格式的 AES 密文，供同步或导出使用
     *
     * @param plainText 要加密的 JSON 原始字符串
     * @param password 自定义加密密码，留空则使用内置默认密码
     * @return 加密密文（自动加上前缀）
     */
    fun encrypt(plainText: String, password: String? = null): String {
        val isDefault = password.isNullOrEmpty()
        val activePassword = if (isDefault) DEFAULT_PASSWORD else password

        // 生成 8 字节随机盐值
        val salt = ByteArray(8)
        SecureRandom().nextBytes(salt)

        // 派生 Key 和 IV
        val (key, iv) = deriveKeyAndIV(activePassword, salt)

        // 执行 AES/CBC/PKCS5Padding 加密
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
        val encryptedData = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))

        // 拼装 OpenSSL 密文结构: MagicNumber (8字节) + Salt (8字节) + EncryptedBytes
        val outputBytes = ByteArray(MAGIC_NUMBER.size + salt.size + encryptedData.size)
        System.arraycopy(MAGIC_NUMBER, 0, outputBytes, 0, MAGIC_NUMBER.size)
        System.arraycopy(salt, 0, outputBytes, MAGIC_NUMBER.size, salt.size)
        System.arraycopy(encryptedData, 0, outputBytes, MAGIC_NUMBER.size + salt.size, encryptedData.size)

        val base64Cipher = Base64.encodeToString(outputBytes, Base64.NO_WRAP)
        val prefix = if (isDefault) "default:" else "encrypted:"
        return "$prefix$base64Cipher"
    }
}
