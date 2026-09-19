package com.example.creditcard.utils

import android.content.Context
import com.example.creditcard.data.DatabaseHelper
import com.example.creditcard.data.SharedCard
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.math.BigDecimal
import com.example.creditcard.R
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import android.content.SharedPreferences
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.isActive
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

    private const val KEY_PIN_RECORD = "app_security_pin_v2"
    private const val KEY_PIN_VERSION = "app_security_pin_version"
    private val pinOperations = Mutex()
    private val stateGuard = Any()
    private val securityEpoch = AtomicLong(0)
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

    fun refreshLockState(context: Context) = synchronized(stateGuard) {
        val prefs = prefs(context)
        val enabled = hasPassword(context)
        if (!enabled) {
            _state.value = SecurityLockState()
            return@synchronized
        }

        val now = System.currentTimeMillis()
        val lastActivity = prefs.getLong(KEY_LAST_ACTIVITY, 0L)
        val shouldAutoLock = lastActivity <= 0L || now - lastActivity > AUTO_LOCK_TIMEOUT_MS
        val shouldLock = prefs.getBoolean(KEY_IS_LOCKED, false) || shouldAutoLock
        if (shouldLock) {
            securityEpoch.incrementAndGet()
            prefs.edit().putBoolean(KEY_IS_LOCKED, true).apply()
        }
        publishState(context)
    }

    fun markInactive(context: Context) {
        securityEpoch.incrementAndGet()
        if (!hasPassword(context) || state.value.locked) return
        prefs(context).edit()
            .putLong(KEY_LAST_ACTIVITY, System.currentTimeMillis())
            .apply()
        publishState(context)
    }

    // KDF and durable preference commits run off the UI thread. A lock/leave event invalidates
    // work already in flight; serial verification preserves attempt counts and upgrade ordering.
    private suspend fun passwordOperation(
        context: Context,
        work: suspend (Long) -> SecurityVerificationResult
    ): SecurityVerificationResult {
        val ticket = securityEpoch.get()
        return withContext(Dispatchers.Default) {
            pinOperations.withLock {
                currentCoroutineContext().ensureActive()
                try { work(ticket) }
                catch (cancelled: CancellationException) { throw cancelled }
                catch (_: Exception) { SecurityVerificationResult(false, context.getString(R.string.security_pin_storage_error)) }
            }
        }
    }

    suspend fun setPassword(context: Context, password: String): SecurityVerificationResult = passwordOperation(context) { ticket ->
        val normalized = password.trim()
        if (normalized.length < 6) return@passwordOperation SecurityVerificationResult(false, "数字密码至少需要 6 位")
        if (!normalized.all(Char::isDigit)) return@passwordOperation SecurityVerificationResult(false, "数字密码只能包含数字")
        val original = synchronized(stateGuard) {
            if (ticket != securityEpoch.get()) return@passwordOperation retryResult(context)
            readPinRecord(prefs(context))
        }
        val record = PinCredential.create(normalized)
        val coroutineContext = currentCoroutineContext()
        coroutineContext.ensureActive()
        synchronized(stateGuard) {
            coroutineContext.ensureActive()
            if (ticket != securityEpoch.get() || readPinRecord(prefs(context)) != original) return@synchronized retryResult(context)
            if (!savePinRecord(prefs(context), record, original)) return@synchronized storageError(context)
            if (!coroutineContext.isActive || ticket != securityEpoch.get()) {
                restorePinRecord(prefs(context), original)
                coroutineContext.ensureActive()
                return@synchronized retryResult(context)
            }
            securityEpoch.incrementAndGet()
            unlockState(context)
            SecurityVerificationResult(true, "密码已设置")
        }
    }

    suspend fun verifyPassword(context: Context, password: String): SecurityVerificationResult =
        verifyPasswordOperation(context, password, disable = false)

    suspend fun disableWithPassword(context: Context, password: String): SecurityVerificationResult =
        verifyPasswordOperation(context, password, disable = true)

    private suspend fun verifyPasswordOperation(context: Context, password: String, disable: Boolean): SecurityVerificationResult =
        passwordOperation(context) { ticket ->
            val preferences = prefs(context)
            val original = synchronized(stateGuard) {
                if (ticket != securityEpoch.get()) return@passwordOperation retryResult(context)
                if (!hasPassword(context)) return@passwordOperation SecurityVerificationResult(false, "尚未设置安全锁")
                val until = preferences.getLong(KEY_LOCKOUT_UNTIL, 0L)
                val now = System.currentTimeMillis()
                if (until > now) {
                    publishState(context)
                    return@passwordOperation SecurityVerificationResult(false, "尝试次数过多，请 ${(until - now) / 1000L + 1} 秒后再试")
                }
                readPinRecord(preferences)
            }
            val normalized = password.trim()
            val isLegacy = !original.present && original.version == 0
            val validInput = normalized.isNotEmpty() && normalized.all(Char::isDigit)
            val matches = validInput && if (isLegacy) {
                original.legacy?.let { PinCredential.verifyLegacy(normalized, it) } ?: false
            } else {
                // Presence and the version floor are authoritative, even for malformed records.
                // Never fall back to an old SHA-256 hash when a newer record exists.
                original.version == 2 && original.current?.let { PinCredential.verify(normalized, it) } == true
            }
            currentCoroutineContext().ensureActive()
            val upgraded = if (matches && isLegacy && !disable) PinCredential.create(normalized) else null
            val coroutineContext = currentCoroutineContext()
            coroutineContext.ensureActive()
            synchronized(stateGuard) {
                coroutineContext.ensureActive()
                if (ticket != securityEpoch.get() || readPinRecord(preferences) != original) return@synchronized retryResult(context)
                if (!matches) {
                    val now = System.currentTimeMillis()
                    val expired = preferences.getLong(KEY_LOCKOUT_UNTIL, 0L) in 1..now
                    val attempts = (if (expired) 0 else preferences.getInt(KEY_FAILED_ATTEMPTS, 0)) + 1
                    val until = if (attempts >= MAX_FAILED_ATTEMPTS) now + TEMP_LOCKOUT_MS else 0L
                    preferences.edit().putInt(KEY_FAILED_ATTEMPTS, attempts).putLong(KEY_LOCKOUT_UNTIL, until).apply()
                    publishState(context)
                    SecurityVerificationResult(false, if (until > 0L) "密码错误次数过多，请稍后再试" else "密码错误")
                } else {
                    if (upgraded != null && !savePinRecord(preferences, upgraded, original)) return@synchronized storageError(context)
                    coroutineContext.ensureActive()
                    if (ticket != securityEpoch.get()) return@synchronized retryResult(context)
                    if (disable) {
                        // One authenticated operation: no verify -> unlock -> separate clear race.
                        val before = preferences.all
                        if (!preferences.edit().clear().commit()) {
                            restorePreferences(preferences, before)
                            return@synchronized storageError(context)
                        }
                        if (!coroutineContext.isActive || ticket != securityEpoch.get()) {
                            restorePreferences(preferences, before)
                            coroutineContext.ensureActive()
                            return@synchronized retryResult(context)
                        }
                        securityEpoch.incrementAndGet()
                        _state.value = SecurityLockState()
                        SecurityVerificationResult(true, "安全锁已关闭")
                    } else {
                        securityEpoch.incrementAndGet()
                        unlockState(context)
                        SecurityVerificationResult(true, "解锁成功")
                    }
                }
            }
        }

    private data class PinRecord(val current: String?, val legacy: String?, val version: Int, val present: Boolean)
    private fun readPinRecord(preferences: SharedPreferences) = PinRecord(
        preferences.getString(KEY_PIN_RECORD, null), preferences.getString(KEY_PASSWORD_HASH, null),
        preferences.getInt(KEY_PIN_VERSION, 0), preferences.contains(KEY_PIN_RECORD)
    )

    private fun savePinRecord(preferences: SharedPreferences, value: String, old: PinRecord): Boolean {
        if (preferences.edit().putString(KEY_PIN_RECORD, value).putInt(KEY_PIN_VERSION, 2)
                .remove(KEY_PASSWORD_HASH).commit()) return true
        // SharedPreferences updates its memory before a failed disk commit. Restore the old
        // verifier in memory too. A process interruption still leaves either whole valid format.
        restorePinRecord(preferences, old)
        return false
    }

    private fun restorePinRecord(preferences: SharedPreferences, old: PinRecord) {
        val rollback = preferences.edit()
        if (old.present) rollback.putString(KEY_PIN_RECORD, old.current) else rollback.remove(KEY_PIN_RECORD)
        if (old.legacy != null) rollback.putString(KEY_PASSWORD_HASH, old.legacy) else rollback.remove(KEY_PASSWORD_HASH)
        if (old.version == 0) rollback.remove(KEY_PIN_VERSION) else rollback.putInt(KEY_PIN_VERSION, old.version)
        rollback.commit()
    }

    private fun restorePreferences(preferences: SharedPreferences, values: Map<String, *>) {
        val editor = preferences.edit().clear()
        values.forEach { (key, value) ->
            when (value) {
                is String -> editor.putString(key, value)
                is Boolean -> editor.putBoolean(key, value)
                is Int -> editor.putInt(key, value)
                is Long -> editor.putLong(key, value)
                is Float -> editor.putFloat(key, value)
            }
        }
        editor.commit()
    }
    private fun retryResult(context: Context) = SecurityVerificationResult(false, context.getString(R.string.security_pin_retry))
    private fun storageError(context: Context) = SecurityVerificationResult(false, context.getString(R.string.security_pin_storage_error))

    fun unlock(context: Context) {
        securityEpoch.incrementAndGet() // A biometric success supersedes pending PIN work; it cannot migrate a PIN.
        synchronized(stateGuard) { unlockState(context) }
    }

    private fun unlockState(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_IS_LOCKED, false)
            .putInt(KEY_FAILED_ATTEMPTS, 0)
            .putLong(KEY_LOCKOUT_UNTIL, 0L)
            .putLong(KEY_LAST_ACTIVITY, System.currentTimeMillis())
            .apply()
        publishState(context)
    }

    fun lock(context: Context) {
        // Invalidate before waiting for a short preference commit, not after a late unlock.
        securityEpoch.incrementAndGet()
        synchronized(stateGuard) {
            if (hasPassword(context)) {
                prefs(context).edit().putBoolean(KEY_IS_LOCKED, true).apply()
                publishState(context)
            }
        }
    }

    fun setBiometricEnabled(context: Context, enabled: Boolean) = synchronized(stateGuard) {
        if (!hasPassword(context) && enabled) return@synchronized
        prefs(context).edit().putBoolean(KEY_BIOMETRIC_ENABLED, enabled).apply()
        publishState(context)
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
        return prefs(context).let { it.contains(KEY_PASSWORD_HASH) || it.contains(KEY_PIN_RECORD) || it.contains(KEY_PIN_VERSION) }
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

    private fun normalizeDigits(value: String): String = value.filter { it.isDigit() }

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
