package com.example.creditcard.utils

import org.bouncycastle.crypto.digests.SHA256Digest
import org.bouncycastle.crypto.generators.PKCS5S2ParametersGenerator
import org.bouncycastle.crypto.params.KeyParameter
import java.security.MessageDigest
import java.security.SecureRandom

/** PIN verifier only: never used as the card database key or the SyncV4 password. */
internal object PinCredential {
    const val ITERATIONS = 600_000
    private const val MAX_ITERATIONS = 2_000_000
    private val legacy = Regex("^[0-9a-f]{64}$")

    fun create(pin: String): String {
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val hash = derive(pin, salt, ITERATIONS)
        return try { "pin-v2\$pbkdf2-sha256\$$ITERATIONS\$${hex(salt)}\$${hex(hash)}" }
        finally { salt.fill(0); hash.fill(0) }
    }

    fun verify(pin: String, record: String): Boolean {
        // Bounded parsing before any expensive work; unknown versions/algorithms fail closed.
        if (record.length > 160) return false
        val parts = record.split('$')
        if (parts.size != 5 || parts[0] != "pin-v2" || parts[1] != "pbkdf2-sha256") return false
        if (!Regex("^[0-9]{6,7}$").matches(parts[2]) || !Regex("^[0-9a-f]{32}$").matches(parts[3]) || !legacy.matches(parts[4])) return false
        val rounds = parts[2].toIntOrNull() ?: return false
        if (rounds !in ITERATIONS..MAX_ITERATIONS) return false
        val salt = bytes(parts[3]); val expected = bytes(parts[4])
        val actual = derive(pin, salt, rounds)
        return try { MessageDigest.isEqual(expected, actual) }
        finally { salt.fill(0); expected.fill(0); actual.fill(0) }
    }

    fun verifyLegacy(pin: String, record: String): Boolean {
        if (!legacy.matches(record)) return false
        val input = (pin + "app_salt_2024").toByteArray(Charsets.UTF_8)
        val expected = bytes(record)
        val actual = try { MessageDigest.getInstance("SHA-256").digest(input) } finally { input.fill(0) }
        return try { MessageDigest.isEqual(expected, actual) } finally { expected.fill(0); actual.fill(0) }
    }

    private fun derive(pin: String, salt: ByteArray, rounds: Int): ByteArray {
        // Android 23-25 lack platform PBKDF2-HMAC-SHA256. The pinned lightweight implementation
        // keeps one identical format on ALL supported Android versions, without a global provider.
        val password = pin.toByteArray(Charsets.UTF_8)
        return try {
            val generator = PKCS5S2ParametersGenerator(SHA256Digest())
            generator.init(password, salt, rounds)
            (generator.generateDerivedParameters(256) as KeyParameter).key
        } finally { password.fill(0) }
    }
    private fun hex(value: ByteArray) = value.joinToString("") { "%02x".format(it.toInt() and 255) }
    private fun bytes(value: String) = ByteArray(value.length / 2) { value.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
}
