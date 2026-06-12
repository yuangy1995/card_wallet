package com.example.creditcard.utils

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.TimeZone

class SyncTimeTest {
    @Test
    fun formatLocalDateTimeUsesDeviceTimeZone() {
        val originalTimeZone = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"))

            assertEquals(
                "2026-06-12 20:54:41",
                SyncTime.formatLocalDateTime("2026-06-12T12:54:41.000Z")
            )
        } finally {
            TimeZone.setDefault(originalTimeZone)
        }
    }
}
