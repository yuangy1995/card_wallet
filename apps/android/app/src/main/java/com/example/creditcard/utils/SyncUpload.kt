package com.example.creditcard.utils

import android.util.Base64
import android.util.Base64OutputStream
import com.example.creditcard.data.SyncEncryptionMetadata
import com.example.creditcard.data.SyncSnapshot
import java.io.Closeable
import java.io.File
import java.io.OutputStream
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.CipherOutputStream
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.encodeToStream
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody
import okio.BufferedSink

/** A repeatable upload backed by an encrypted, app-private temporary file, never plaintext. */
internal class SyncUpload private constructor(val file: File) : Closeable {
    val size: Long get() = file.length()

    fun requestBody(onProgress: ((Long) -> Unit)? = null): RequestBody = object : RequestBody() {
        override fun contentType() = "text/plain; charset=utf-8".toMediaType()
        override fun contentLength() = size
        override fun writeTo(sink: BufferedSink) {
            // Open a new stream for every attempt. A retry must not reuse an exhausted stream.
            file.inputStream().use { input ->
                val buffer = ByteArray(16 * 1024)
                var sent = 0L
                onProgress?.invoke(sent)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    sink.write(buffer, 0, count)
                    sent += count
                    onProgress?.invoke(sent)
                }
            }
        }
    }

    override fun close() { file.delete() }

    companion object {
        /** Preserve SyncV4 metadata, PBKDF2 parameters and GCM tag placement for all clients. */
        @OptIn(ExperimentalSerializationApi::class)
        fun prepare(directory: File, snapshot: SyncSnapshot, password: String,
            checkpoint: () -> Unit = {}): SyncUpload {
            val normalized = password.trim()
            require(normalized.isNotEmpty()) { "请输入同步加密密码" }
            check(directory.isDirectory || directory.mkdirs()) { "无法创建同步临时目录" }
            val file = File.createTempFile("snapshot-", ".enc", directory)
            try {
                val salt = ByteArray(16)
                val iv = ByteArray(12)
                SecureRandom().apply { nextBytes(salt); nextBytes(iv) }
                val spec = PBEKeySpec(normalized.toCharArray(), salt, 310000, 256)
                val key = try {
                    SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
                } finally { spec.clearPassword() }
                try {
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
                    file.outputStream().buffered(16 * 1024).use { output ->
                        val metadata = SyncEncryptionMetadata(iterations = 310000,
                            salt = Base64.encodeToString(salt, Base64.NO_WRAP),
                            iv = Base64.encodeToString(iv, Base64.NO_WRAP))
                        output.write("{\"schemaVersion\":\"4.0.0\",\"encryption\":".toByteArray())
                        AppJson.json.encodeToStream(SyncEncryptionMetadata.serializer(), metadata, output)
                        output.write(",\"ciphertext\":\"".toByteArray())
                        val base64 = Base64OutputStream(output, Base64.NO_WRAP or Base64.NO_CLOSE)
                        CipherOutputStream(base64, cipher).use { encrypted ->
                            val checked = object : OutputStream() {
                                override fun write(value: Int) { checkpoint(); encrypted.write(value) }
                                override fun write(bytes: ByteArray, offset: Int, length: Int) {
                                    checkpoint(); encrypted.write(bytes, offset, length)
                                }
                            }
                            // Avoid whole-snapshot JSON, UTF-8, ciphertext and Base64 copies.
                            AppJson.json.encodeToStream(SyncSnapshot.serializer(), snapshot, checked)
                        }
                        output.write("\"}".toByteArray())
                    }
                } finally { key.fill(0) }
                checkpoint()
                return SyncUpload(file)
            } catch (failure: Throwable) {
                file.delete()
                throw failure
            }
        }
    }
}
