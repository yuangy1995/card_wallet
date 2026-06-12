package com.example.creditcard.utils

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object SyncTime {
    private const val SECOND_MILLIS_THRESHOLD = 100_000_000_000L

    private val isoOutput = object : ThreadLocal<SimpleDateFormat>() {
        override fun initialValue(): SimpleDateFormat {
            return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
                isLenient = false
            }
        }
    }

    private val inputFormats = listOf(
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSSX",
        "yyyy-MM-dd'T'HH:mm:ssX",
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'Z'",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
        "yyyy/MM/dd HH:mm:ss",
        "yyyy/MM/dd"
    )

    fun nowMillis(): Long = System.currentTimeMillis()

    fun nowIso(): String = isoFromMillis(nowMillis())

    fun isoFromMillis(epochMillis: Long): String {
        return isoOutput.get()!!.format(Date(epochMillis))
    }

    fun normalizeIso(value: String?): String {
        return isoFromMillis(parseMillis(value) ?: nowMillis())
    }

    fun parseMillis(value: String?): Long? {
        val trimmed = value?.trim().orEmpty()
        if (trimmed.isEmpty()) return null

        trimmed.toDoubleOrNull()?.let { return normalizeNumericTimestamp(it) }

        for (pattern in inputFormats) {
            val parsed = tryParse(trimmed, pattern)
            if (parsed != null) return parsed
        }

        return null
    }

    fun normalizeNumericTimestamp(value: Double): Long? {
        if (!value.isFinite() || value <= 0.0) return null
        val millis = if (value < SECOND_MILLIS_THRESHOLD) value * 1000 else value
        return millis.toLong()
    }

    fun compareIsoLike(lhs: String, rhs: String): Int {
        val lhsMillis = parseMillis(lhs) ?: Long.MIN_VALUE
        val rhsMillis = parseMillis(rhs) ?: Long.MIN_VALUE
        return lhsMillis.compareTo(rhsMillis)
    }

    fun formatLocalDateTime(value: String, fallback: String = "未知时间"): String {
        val millis = parseMillis(value) ?: return fallback
        return SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.CHINA).apply {
            timeZone = TimeZone.getDefault()
            isLenient = false
        }.format(Date(millis))
    }

    private fun tryParse(value: String, pattern: String): Long? {
        return try {
            val formatter = SimpleDateFormat(pattern, Locale.US).apply {
                isLenient = false
                if (pattern.endsWith("'Z'") || pattern.contains("X")) {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
            }
            formatter.parse(value)?.time
        } catch (_: Exception) {
            null
        }
    }
}
