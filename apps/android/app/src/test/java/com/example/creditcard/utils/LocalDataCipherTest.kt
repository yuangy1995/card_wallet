package com.example.creditcard.utils
import javax.crypto.KeyGenerator
import org.junit.Assert.*
import org.junit.Test

class LocalDataCipherTest {
    private fun cipher(): LocalRecordCipher {
        val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        return AesLocalRecordCipher { key }
    }
    @Test fun randomIVAndAuthenticatedPurpose() {
        val cipher = cipher(); val original = "synthetic-card-payload".toByteArray()
        val a = cipher.seal(original, "card/1"); val b = cipher.seal(original, "card/1")
        assertFalse(a.contentEquals(b)); assertArrayEquals(original, cipher.open(a, "card/1"))
        assertThrows(Exception::class.java) { cipher.open(a, "card/2") }
        a[a.lastIndex] = (a.last().toInt() xor 1).toByte()
        assertThrows(Exception::class.java) { cipher.open(a, "card/1") }
        assertThrows(Exception::class.java) { cipher().open(b, "card/1") }
    }
    @Test fun localTimesRemainMonotonicWithinSameMillisecond() {
        val now = 1789700000000L
        val a = SyncTime.nextMillis(SyncTime.isoFromMillis(now), now)
        val b = SyncTime.nextMillis(SyncTime.isoFromMillis(a), now)
        assertEquals(now + 1, a); assertEquals(now + 2, b)
    }
}
