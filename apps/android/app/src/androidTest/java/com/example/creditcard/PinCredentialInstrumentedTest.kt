package com.example.creditcard

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.creditcard.utils.PinCredential
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import android.os.SystemClock

@RunWith(AndroidJUnit4::class)
class PinCredentialInstrumentedTest {
    @Test fun realDeviceVerifierSupportsThePinnedFormatAndReportsCost() {
        val start = SystemClock.elapsedRealtimeNanos()
        val record = PinCredential.create("123456")
        val created = SystemClock.elapsedRealtimeNanos()
        assertTrue(PinCredential.verify("123456", record))
        val verified = SystemClock.elapsedRealtimeNanos()
        assertFalse(PinCredential.verify("000000", record))
        // Only aggregate timings; never emit a PIN, salt, verifier or real credential.
        println("PIN_BENCHMARK iterations=${PinCredential.ITERATIONS} create_ms=${(created-start)/1_000_000} verify_ms=${(verified-created)/1_000_000}")
    }
}
