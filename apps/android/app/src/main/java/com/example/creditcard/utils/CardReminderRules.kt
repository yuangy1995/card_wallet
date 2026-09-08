package com.example.creditcard.utils

import com.example.creditcard.data.SharedCard
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.Calendar
import kotlin.math.abs
import kotlin.math.ceil

enum class AnnualFeeDetectionKind {
    UNQUALIFIED,
    WARNING,
    OVERDUE
}

data class AnnualFeeDetectionResult(
    val kind: AnnualFeeDetectionKind,
    val days: Int,
    val diffDays: Int
)

enum class CardExpiryStatus {
    EXPIRED,
    SOON_EXPIRING,
    NORMAL
}

data class CardExpiryStats(
    val expiredCards: Int,
    val soonExpiring: Int,
    val normalCards: Int
)

enum class BillingCycleReminderKind {
    BILL,
    REPAYMENT
}

data class BillingCycleReminderResult(
    val kind: BillingCycleReminderKind,
    val days: Int,
    val date: LocalDate,
    val title: String
)

data class DataQualityIssue(
    val severity: String,
    val title: String,
    val detail: String,
    val cardName: String = ""
)

object CardReminderRules {
    const val ANNUAL_FEE_WARNING_DAYS = 60
    const val EXPIRY_WARNING_MONTHS = 6L
    const val BILL_WARNING_DAYS = 3
    const val REPAYMENT_WARNING_DAYS = 7

    private const val DAY_MS = 24 * 60 * 60 * 1000.0

    fun annualFeeRemainingDays(nextAnnualFeeCollectionTime: Long?, nowMillis: Long = System.currentTimeMillis()): Int? {
        val targetMillis = nextAnnualFeeCollectionTime ?: return null
        return ceil((targetMillis - nowMillis) / DAY_MS).toInt()
    }

    /** 以卡片中保存的年费日期为基准增加一个日历年。 */
    fun timestampByAddingOneYear(timestamp: Long?): Long? {
        val value = timestamp ?: return null
        return Calendar.getInstance().apply {
            timeInMillis = value
            add(Calendar.YEAR, 1)
        }.timeInMillis
    }

    /** 确认当前年费周期达标，并同步顺延下一次年费日期。 */
    fun confirmAnnualFeeQualified(card: SharedCard): SharedCard = card.copy(
        isQualified = "1",
        nextAnnualFeeCollectionTime = timestampByAddingOneYear(card.nextAnnualFeeCollectionTime)
    )

    fun annualFeeDetection(
        card: SharedCard,
        warningDays: Int = ANNUAL_FEE_WARNING_DAYS,
        nowMillis: Long = System.currentTimeMillis()
    ): AnnualFeeDetectionResult? {
        if (card.cardCategory == "debit" || card.isQualified == "3") return null
        val diffDays = annualFeeRemainingDays(card.nextAnnualFeeCollectionTime, nowMillis) ?: return null

        if (card.isQualified == "2" && diffDays <= warningDays && diffDays > 0) {
            return AnnualFeeDetectionResult(AnnualFeeDetectionKind.UNQUALIFIED, diffDays, diffDays)
        }

        if (diffDays <= warningDays && diffDays > 0 && card.isQualified != "2") {
            return AnnualFeeDetectionResult(AnnualFeeDetectionKind.WARNING, diffDays, diffDays)
        }

        if (diffDays <= 0 && diffDays > -warningDays) {
            return AnnualFeeDetectionResult(AnnualFeeDetectionKind.OVERDUE, abs(diffDays), diffDays)
        }

        return null
    }

    fun annualFeeAlerts(cards: List<SharedCard>): List<Pair<SharedCard, AnnualFeeDetectionResult>> {
        return cards.mapNotNull { card ->
            annualFeeDetection(card)?.let { result -> card to result }
        }.sortedWith(compareBy<Pair<SharedCard, AnnualFeeDetectionResult>> { it.second.diffDays }.thenBy { it.first.bank })
    }

    fun cardExpiryStatus(valid: String?, today: LocalDate = LocalDate.now()): CardExpiryStatus? {
        val expiryDate = parseExpiryDate(valid) ?: return null
        if (expiryDate.isBefore(today)) return CardExpiryStatus.EXPIRED
        if (expiryDate.isBefore(today.plusMonths(EXPIRY_WARNING_MONTHS))) return CardExpiryStatus.SOON_EXPIRING
        return CardExpiryStatus.NORMAL
    }

    fun cardExpiryAlerts(cards: List<SharedCard>): List<Pair<SharedCard, CardExpiryStatus>> {
        return cards.mapNotNull { card ->
            val status = cardExpiryStatus(card.valid) ?: return@mapNotNull null
            if (status == CardExpiryStatus.NORMAL) null else card to status
        }.sortedWith(compareBy<Pair<SharedCard, CardExpiryStatus>> {
            when (it.second) {
                CardExpiryStatus.EXPIRED -> 0
                CardExpiryStatus.SOON_EXPIRING -> 1
                CardExpiryStatus.NORMAL -> 2
            }
        }.thenBy { it.first.bank })
    }

    fun cardExpiryStats(cards: List<SharedCard>): CardExpiryStats {
        var expired = 0
        var soonExpiring = 0
        var normal = 0

        cards.forEach { card ->
            when (cardExpiryStatus(card.valid)) {
                CardExpiryStatus.EXPIRED -> expired += 1
                CardExpiryStatus.SOON_EXPIRING -> soonExpiring += 1
                CardExpiryStatus.NORMAL -> normal += 1
                null -> Unit
            }
        }

        return CardExpiryStats(expired, soonExpiring, normal)
    }

    fun billingCycleReminders(
        card: SharedCard,
        today: LocalDate = LocalDate.now(),
        billWarningDays: Int = BILL_WARNING_DAYS,
        repaymentWarningDays: Int = REPAYMENT_WARNING_DAYS
    ): List<BillingCycleReminderResult> {
        if (card.cardCategory == "debit") return emptyList()
        val reminders = mutableListOf<BillingCycleReminderResult>()

        nextBillDate(card.accountBillDate, today)?.let { date ->
            val days = ChronoUnit.DAYS.between(today, date).toInt()
            if (days in 0..billWarningDays) {
                reminders += BillingCycleReminderResult(
                    BillingCycleReminderKind.BILL,
                    days,
                    date,
                    if (days == 0) "今天是账单日" else "${days} 天后账单日"
                )
            }
        }

        nextDueDate(card.accountBillDate, card.dueDate, today)?.let { date ->
            val days = ChronoUnit.DAYS.between(today, date).toInt()
            if (days in 0..repaymentWarningDays) {
                reminders += BillingCycleReminderResult(
                    BillingCycleReminderKind.REPAYMENT,
                    days,
                    date,
                    if (days == 0) "今天是还款日" else "${days} 天后还款日"
                )
            }
        }

        return reminders
    }

    fun billingCycleAlerts(cards: List<SharedCard>): List<Pair<SharedCard, BillingCycleReminderResult>> {
        return cards.flatMap { card ->
            billingCycleReminders(card).map { reminder -> card to reminder }
        }.sortedWith(compareBy<Pair<SharedCard, BillingCycleReminderResult>> {
            when (it.second.kind) {
                BillingCycleReminderKind.REPAYMENT -> 0
                BillingCycleReminderKind.BILL -> 1
            }
        }.thenBy { it.second.days }.thenBy { it.first.bank })
    }

    fun analyzeDataQuality(cards: List<SharedCard>): List<DataQualityIssue> {
        val issues = mutableListOf<DataQualityIssue>()
        val numberGroups = linkedMapOf<String, MutableList<SharedCard>>()

        fun cardName(card: SharedCard): String {
            return "${card.bank.ifBlank { "未知银行" }} - ${card.alias.ifBlank { "未命名卡片" }}"
        }

        fun add(severity: String, title: String, detail: String, card: SharedCard? = null) {
            issues += DataQualityIssue(severity, title, detail, card?.let { cardName(it) }.orEmpty())
        }

        cards.forEach { card ->
            val cleanNumber = card.cardNumber.replace(Regex("\\D"), "")
            if (cleanNumber.isBlank()) {
                add("严重", "卡号缺失", "无法用于验卡或重复检测。", card)
            } else {
                numberGroups.getOrPut(cleanNumber) { mutableListOf() }.add(card)
            }

            if (card.bank.isBlank()) {
                add("警告", "银行缺失", "建议补全发卡银行，便于统计和同步审计。", card)
            }

            if (card.valid.isNotBlank() && cardExpiryStatus(card.valid) == null) {
                add("严重", "有效期格式异常", "当前有效期为“${card.valid}”，建议使用 MM/YY。", card)
            }

            if (card.cardCategory != "debit") {
                val billDay = dayNumber(card.accountBillDate)
                val dueDay = dayNumber(card.dueDate)
                if (card.accountBillDate.isBlank() || card.dueDate.isBlank()) {
                    add("警告", "账单/还款配置缺失", "无法计算还款提醒和免息期。", card)
                } else {
                    if (billDay == null) add("严重", "账单日非法", "账单日必须是 1-31 之间的数字。", card)
                    if (dueDay == null) add("严重", "还款日非法", "还款日必须是 1-31 之间的数字。", card)
                }
                if (card.isQualified != "3" && card.nextAnnualFeeCollectionTime == null) {
                    add("警告", "年费日期缺失", "非终免年费卡片缺少下次年费收取时间。", card)
                }
            } else if (
                card.accountBillDate.isNotBlank() ||
                card.dueDate.isNotBlank() ||
                card.annualFee > 0.0 ||
                card.nextAnnualFeeCollectionTime != null
            ) {
                add("提示", "储蓄卡包含信用卡字段", "储蓄卡不会参与账单、还款和年费提醒，建议清理相关字段。", card)
            }
        }

        numberGroups.values.filter { it.size > 1 }.forEach { group ->
            add("严重", "卡号重复", group.joinToString("、") { cardName(it) })
        }

        cards.filter { it.cardCategory != "debit" && it.isSharedLimit }
            .groupBy { "${it.country}|${it.bank}|${it.type}" }
            .values
            .filter { it.size > 1 }
            .forEach { group ->
                if (group.map { it.limit }.toSet().size > 1) {
                    add("警告", "共享额度不一致", group.joinToString("、") { "${it.alias.ifBlank { "未命名卡片" }}：${it.limit}" })
                }
            }

        val weight = mapOf("严重" to 0, "警告" to 1, "提示" to 2)
        return issues.sortedBy { weight[it.severity] ?: 9 }
    }

    private fun parseExpiryDate(valid: String?): LocalDate? {
        val trimmed = valid?.trim().orEmpty()
        if (trimmed.isEmpty()) return null

        val mmYy = Regex("^(\\d{1,2})/(\\d{2}|\\d{4})$").matchEntire(trimmed)
        if (mmYy != null) {
            val month = mmYy.groupValues[1].toIntOrNull() ?: return null
            var year = mmYy.groupValues[2].toIntOrNull() ?: return null
            if (year < 100) year += 2000
            if (month !in 1..12) return null
            return LocalDate.of(year, month, 1)
        }

        return runCatching {
            val parsed = LocalDate.parse(trimmed)
            LocalDate.of(parsed.year, parsed.month, 1)
        }.getOrNull()
    }

    private fun dayNumber(value: String?): Int? {
        val day = value?.trim()?.toIntOrNull() ?: return null
        return day.takeIf { it in 1..31 }
    }

    private fun monthDayDate(day: Int, baseDate: LocalDate, monthOffset: Long = 0): LocalDate {
        val targetMonth = baseDate.plusMonths(monthOffset)
        val normalizedDay = minOf(day, targetMonth.lengthOfMonth())
        return LocalDate.of(targetMonth.year, targetMonth.month, normalizedDay)
    }

    private fun nextBillDate(accountBillDate: String?, today: LocalDate): LocalDate? {
        val day = dayNumber(accountBillDate) ?: return null
        val current = monthDayDate(day, today)
        return if (!current.isBefore(today)) current else monthDayDate(day, today, 1)
    }

    private fun dueDateForBillMonth(accountBillDate: String?, dueDate: String?, today: LocalDate, monthOffset: Long = 0): LocalDate? {
        val billDay = dayNumber(accountBillDate) ?: return null
        val dueDay = dayNumber(dueDate) ?: return null
        val dueMonthOffset = monthOffset + if (dueDay < billDay) 1 else 0
        return monthDayDate(dueDay, today, dueMonthOffset)
    }

    private fun nextDueDate(accountBillDate: String?, dueDate: String?, today: LocalDate): LocalDate? {
        val current = dueDateForBillMonth(accountBillDate, dueDate, today) ?: return null
        return if (!current.isBefore(today)) current else dueDateForBillMonth(accountBillDate, dueDate, today, 1)
    }
}
