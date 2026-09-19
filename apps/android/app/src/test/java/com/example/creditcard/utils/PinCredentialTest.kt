package com.example.creditcard.utils

import org.junit.Assert.*
import org.junit.Test

class PinCredentialTest {
    @Test fun independentPbkdf2VectorAndWrongPin() {
        // Synthetic vector independently produced with Python hashlib.pbkdf2_hmac.
        val record = "pin-v2\$pbkdf2-sha256\$600000\$000102030405060708090a0b0c0d0e0f\$93922e39f17be3ac82ee49e41b689b2f825ffcb9b18c64406350c92b4fa3c59c"
        assertTrue(PinCredential.verify("123456", record))
        assertFalse(PinCredential.verify("123457", record))
    }
    @Test fun randomSaltForEveryRecordAndUnicodeNumericPinRoundTrips() {
        val first = PinCredential.create("１２３４５６")
        val second = PinCredential.create("１２３４５６")
        assertNotEquals(first, second)
        assertTrue(PinCredential.verify("１２３４５６", first))
        assertFalse(PinCredential.verify("123456", first))
        assertEquals("600000", first.split('$')[2])
        assertEquals(32, first.split('$')[3].length)
        assertEquals(64, first.split('$')[4].length)
    }
    @Test fun unknownTruncatedOrUnboundedRecordsFailClosed() {
        val record = PinCredential.create("123456")
        for (bad in listOf("", "garbage", record.dropLast(1), record.replace("pin-v2", "pin-v3"),
                record.replace("sha256", "sha1"), record.replace("600000", "1"),
                record.replace("600000", "2147483647"), record.replace("600000", "2000001"),
                record.replace("600000", "0599999"), record + "\$extra")) {
            assertFalse(PinCredential.verify("123456", bad))
        }
    }
    @Test fun legacyVerifierIsReadOnlyAndDoesNotAcceptModernFormats() {
        val hash = "76eb14fe26d238c214b0f4ac405cfb0ee651fe0b21e972d1b0ea81211237c33a"
        assertTrue(PinCredential.verifyLegacy("123456", hash))
        assertFalse(PinCredential.verifyLegacy("000000", hash))
        assertFalse(PinCredential.verifyLegacy("123456", "not-a-hash"))
        assertFalse(PinCredential.verify("123456", hash))
    }
}
