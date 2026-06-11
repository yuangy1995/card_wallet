package com.example.creditcard.utils

import android.content.Context
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.math.BigDecimal
import java.security.MessageDigest
import kotlin.math.roundToLong
import kotlin.random.Random

data class SecurityLockState(
    val enabled: Boolean = false,
    val locked: Boolean = false,
    val biometricEnabled: Boolean = false,
    val failedAttempts: Int = 0,
    val lockoutUntilMs: Long = 0L
)

data class SecurityVerificationResult(
    val success: Boolean,
    val message: String
)

enum class SecurityRecoveryQuestionType {
    ANY_CARD_NUMBER,
    CVV,
    EXPIRY,
    LIMIT
}

data class SecurityRecoveryQuestion(
    val type: SecurityRecoveryQuestionType,
    val question: String,
    val placeholder: String,
    val acceptedAnswers: List<String> = emptyList(),
    val expectedAnswer: String = ""
)

object SecurityLockManager {
    private const val PREFS_NAME = "credit_card_security_prefs"
    private const val KEY_PASSWORD_HASH = "app_security_password_hash"
    private const val KEY_IS_LOCKED = "app_lock_state"
    private const val KEY_FAILED_ATTEMPTS = "password_failed_attempts"
    private const val KEY_LOCKOUT_UNTIL = "password_lockout_until"
    private const val KEY_LAST_ACTIVITY = "last_activity_time"
    private const val KEY_BIOMETRIC_ENABLED = "biometric_unlock_enabled"

    private const val PASSWORD_SALT = "app_salt_2024"
    private const val AUTO_LOCK_TIMEOUT_MS = 5 * 60 * 1000L
    private const val TEMP_LOCKOUT_MS = 60 * 1000L
    private const val MAX_FAILED_ATTEMPTS = 5

    private val _state = MutableStateFlow(SecurityLockState())
    val state: StateFlow<SecurityLockState> = _state.asStateFlow()

    fun init(context: Context) {
        refreshLockState(context)
    }

    fun lockIfEnabled(context: Context) {
        if (hasPassword(context)) {
            lock(context)
        }
    }

    fun refreshLockState(context: Context) {
        val prefs = prefs(context)
        val enabled = hasPassword(context)
        if (!enabled) {
            _state.value = SecurityLockState()
            return
        }

        val now = System.currentTimeMillis()
        val lastActivity = prefs.getLong(KEY_LAST_ACTIVITY, 0L)
        val shouldAutoLock = lastActivity <= 0L || now - lastActivity > AUTO_LOCK_TIMEOUT_MS
        val shouldLock = prefs.getBoolean(KEY_IS_LOCKED, false) || shouldAutoLock
        if (shouldLock) {
            prefs.edit().putBoolean(KEY_IS_LOCKED, true).apply()
        }
        publishState(context)
    }

    fun markInactive(context: Context) {
        if (!hasPassword(context) || state.value.locked) return
        prefs(context).edit()
            .putLong(KEY_LAST_ACTIVITY, System.currentTimeMillis())
            .apply()
        publishState(context)
    }

    fun setPassword(context: Context, password: String): SecurityVerificationResult {
        val normalized = normalizePassword(password)
        if (normalized.length < 6) {
            return SecurityVerificationResult(false, "数字密码至少需要 6 位")
        }
        if (normalized.length != password.trim().length) {
            return SecurityVerificationResult(false, "数字密码只能包含数字")
        }

        prefs(context).edit()
            .putString(KEY_PASSWORD_HASH, hashPassword(normalized))
            .putBoolean(KEY_IS_LOCKED, false)
            .putInt(KEY_FAILED_ATTEMPTS, 0)
            .putLong(KEY_LOCKOUT_UNTIL, 0L)
            .putLong(KEY_LAST_ACTIVITY, System.currentTimeMillis())
            .apply()
        publishState(context)
        return SecurityVerificationResult(true, "密码已设置")
    }

    fun verifyPassword(context: Context, password: String): SecurityVerificationResult {
        val prefs = prefs(context)
        val expectedHash = prefs.getString(KEY_PASSWORD_HASH, null)
            ?: return SecurityVerificationResult(false, "尚未设置安全锁")
        val now = System.currentTimeMillis()
        val lockoutUntil = prefs.getLong(KEY_LOCKOUT_UNTIL, 0L)
        if (lockoutUntil > now) {
            val seconds = ((lockoutUntil - now) / 1000L).coerceAtLeast(1L)
            publishState(context)
            return SecurityVerificationResult(false, "尝试次数过多，请 $seconds 秒后再试")
        }

        val normalized = normalizePassword(password)
        return if (hashPassword(normalized) == expectedHash) {
            unlock(context)
            SecurityVerificationResult(true, "解锁成功")
        } else {
            val nextAttempts = prefs.getInt(KEY_FAILED_ATTEMPTS, 0) + 1
            val nextLockout = if (nextAttempts >= MAX_FAILED_ATTEMPTS) now + TEMP_LOCKOUT_MS else 0L
            prefs.edit()
                .putInt(KEY_FAILED_ATTEMPTS, nextAttempts)
                .putLong(KEY_LOCKOUT_UNTIL, nextLockout)
                .apply()
            publishState(context)
            val message = if (nextLockout > 0L) "密码错误次数过多，请稍后再试" else "密码错误"
            SecurityVerificationResult(false, message)
        }
    }

    fun unlock(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_IS_LOCKED, false)
            .putInt(KEY_FAILED_ATTEMPTS, 0)
            .putLong(KEY_LOCKOUT_UNTIL, 0L)
            .putLong(KEY_LAST_ACTIVITY, System.currentTimeMillis())
            .apply()
        publishState(context)
    }

    fun lock(context: Context) {
        if (!hasPassword(context)) return
        prefs(context).edit()
            .putBoolean(KEY_IS_LOCKED, true)
            .apply()
        publishState(context)
    }

    fun setBiometricEnabled(context: Context, enabled: Boolean) {
        if (!hasPassword(context) && enabled) return
        prefs(context).edit()
            .putBoolean(KEY_BIOMETRIC_ENABLED, enabled)
            .apply()
        publishState(context)
    }

    fun clearSecurityData(context: Context) {
        prefs(context).edit().clear().apply()
        _state.value = SecurityLockState()
    }

    fun generateRecoveryQuestions(context: Context): List<SecurityRecoveryQuestion> {
        val cards = DatabaseHelper(context.applicationContext).use { it.getAllCards() }
        if (cards.isEmpty()) {
            throw IllegalStateException("没有找到已保存的卡片数据，无法找回密码")
        }

        val cardNumbers = cards.mapNotNull { normalizeDigits(it.cardNumber).ifBlank { null } }
        if (cardNumbers.isEmpty()) {
            throw IllegalStateException("已保存卡片缺少卡号，无法生成找回问题")
        }

        val cvvCards = cards.filter { normalizeDigits(it.cvv).isNotBlank() && normalizeDigits(it.cardNumber).isNotBlank() }
        val expiryCards = cards.filter { parseExpiry(it.valid) != null && normalizeDigits(it.cardNumber).isNotBlank() }
        val limitCards = cards.filter { it.cardCategory != "debit" && normalizeLimitAnswer(it.limit).isNotBlank() && it.limit > 0.0 }
        if (cvvCards.isEmpty() && expiryCards.isEmpty()) {
            throw IllegalStateException("已保存卡片缺少 CVV 或有效期，无法生成找回问题")
        }
        if (limitCards.isEmpty()) {
            throw IllegalStateException("已保存卡片缺少信用额度，无法生成找回问题")
        }

        val random = Random(System.currentTimeMillis())
        val questions = mutableListOf<SecurityRecoveryQuestion>()
        questions += SecurityRecoveryQuestion(
            type = SecurityRecoveryQuestionType.ANY_CARD_NUMBER,
            question = "请输入当前正在使用的任意卡片的完整卡号",
            placeholder = "请输入完整卡号",
            acceptedAnswers = cardNumbers
        )

        val askCvv = when {
            cvvCards.isNotEmpty() && expiryCards.isNotEmpty() -> random.nextBoolean()
            cvvCards.isNotEmpty() -> true
            else -> false
        }
        if (askCvv) {
            val card = cvvCards.random(random)
            questions += SecurityRecoveryQuestion(
                type = SecurityRecoveryQuestionType.CVV,
                question = "请输入尾号为 ${lastFourDigits(card.cardNumber)} 的卡片 CVV",
                placeholder = "请输入 CVV",
                expectedAnswer = normalizeDigits(card.cvv)
            )
        } else {
            val card = expiryCards.random(random)
            questions += SecurityRecoveryQuestion(
                type = SecurityRecoveryQuestionType.EXPIRY,
                question = "请输入尾号为 ${lastFourDigits(card.cardNumber)} 的卡片有效期",
                placeholder = "格式：MM/YY，例如 08/30",
                expectedAnswer = formatExpiryAnswer(card.valid)
            )
        }

        val limitCard = limitCards.random(random)
        questions += SecurityRecoveryQuestion(
            type = SecurityRecoveryQuestionType.LIMIT,
            question = "${buildCardDisplayName(limitCard)} 的信用额度是多少？",
            placeholder = "请输入纯数字金额",
            expectedAnswer = normalizeLimitAnswer(limitCard.limit)
        )
        return questions
    }

    fun verifyRecoveryAnswer(question: SecurityRecoveryQuestion, answer: String): Boolean {
        return when (question.type) {
            SecurityRecoveryQuestionType.ANY_CARD_NUMBER -> {
                val normalized = normalizeDigits(answer)
                normalized.isNotBlank() && question.acceptedAnswers.any { it == normalized }
            }
            SecurityRecoveryQuestionType.CVV -> normalizeDigits(answer) == question.expectedAnswer
            SecurityRecoveryQuestionType.EXPIRY -> {
                val input = parseExpiry(answer)
                val expected = parseExpiry(question.expectedAnswer)
                input != null && expected != null && input == expected
            }
            SecurityRecoveryQuestionType.LIMIT -> normalizeDigits(answer) == question.expectedAnswer
        }
    }

    fun verifyRecoveryAnswers(
        questions: List<SecurityRecoveryQuestion>,
        answers: List<String>
    ): List<Boolean> {
        return questions.mapIndexed { index, question ->
            verifyRecoveryAnswer(question, answers.getOrNull(index).orEmpty())
        }
    }

    fun hasPassword(context: Context): Boolean {
        return !prefs(context).getString(KEY_PASSWORD_HASH, null).isNullOrBlank()
    }

    private fun publishState(context: Context) {
        val prefs = prefs(context)
        val enabled = hasPassword(context)
        _state.value = SecurityLockState(
            enabled = enabled,
            locked = enabled && prefs.getBoolean(KEY_IS_LOCKED, false),
            biometricEnabled = enabled && prefs.getBoolean(KEY_BIOMETRIC_ENABLED, false),
            failedAttempts = prefs.getInt(KEY_FAILED_ATTEMPTS, 0),
            lockoutUntilMs = prefs.getLong(KEY_LOCKOUT_UNTIL, 0L)
        )
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun normalizePassword(password: String): String = password.trim().filter { it.isDigit() }

    private fun normalizeDigits(value: String): String = value.filter { it.isDigit() }

    private fun hashPassword(password: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest((password + PASSWORD_SALT).toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }

    private fun lastFourDigits(cardNumber: String): String {
        val digits = normalizeDigits(cardNumber)
        return if (digits.length >= 4) digits.takeLast(4) else digits.padStart(4, '*')
    }

    private fun buildCardDisplayName(card: SharedCard): String {
        return listOf(card.country, card.bank, card.alias)
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .ifEmpty { listOf("未知卡片") }
            .joinToString(" ")
    }

    private fun normalizeLimitAnswer(limit: Double): String {
        if (!limit.isFinite() || limit <= 0.0) return ""
        val whole = limit.roundToLong()
        val normalized = if (kotlin.math.abs(limit - whole.toDouble()) < 0.000001) {
            whole.toString()
        } else {
            BigDecimal.valueOf(limit).stripTrailingZeros().toPlainString()
        }
        return normalizeDigits(normalized)
    }

    private fun formatExpiryAnswer(value: String): String {
        val parsed = parseExpiry(value) ?: return value
        return "${parsed.first.toString().padStart(2, '0')}/${parsed.second.toString().takeLast(2).padStart(2, '0')}"
    }

    private fun parseExpiry(value: String): Pair<Int, Int>? {
        val trimmed = value.trim().replace("\\s".toRegex(), "")
        if (trimmed.isBlank()) return null

        Regex("^(\\d{1,2})/(\\d{2})$").matchEntire(trimmed)?.let { match ->
            val month = match.groupValues[1].toInt()
            val year = 2000 + match.groupValues[2].toInt()
            if (month in 1..12) return month to year
        }

        Regex("^(\\d{4})-(\\d{1,2})$").matchEntire(trimmed)?.let { match ->
            val year = match.groupValues[1].toInt()
            val month = match.groupValues[2].toInt()
            if (month in 1..12) return month to year
        }

        Regex("^(\\d{4})(\\d{2})$").matchEntire(trimmed)?.let { match ->
            val year = match.groupValues[1].toInt()
            val month = match.groupValues[2].toInt()
            if (month in 1..12) return month to year
        }

        Regex("^(\\d{1,2})-(\\d{2})$").matchEntire(trimmed)?.let { match ->
            val month = match.groupValues[1].toInt()
            val year = 2000 + match.groupValues[2].toInt()
            if (month in 1..12) return month to year
        }

        return null
    }
}
