package com.example.creditcard.utils

import com.example.creditcard.ui.main.getCardBrand
import com.example.creditcard.data.SharedCard
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.Locale

/** Contract v1; no UI state and no changes to the SyncV4 wire model. */
object WalletCardRules {
    data class CreditPool(val country: String, val bank: String, val currency: String)
    fun currency(card: SharedCard): String = card.type.trim().uppercase(Locale.ROOT)
    fun pool(card: SharedCard) = CreditPool(card.country.trim(), normalizeBankNameForMatch(card.bank), currency(card))
    private fun cents(value: Double): BigDecimal = if (value.isFinite() && value >= 0)
        BigDecimal.valueOf(value).movePointRight(2).setScale(0, RoundingMode.HALF_UP) else BigDecimal.ZERO

    fun creditLimits(cards: List<SharedCard>): Map<String, Double> {
        val shared = mutableMapOf<CreditPool, BigDecimal>()
        val totals = mutableMapOf<String, BigDecimal>()
        cards.filter { it.cardCategory != "debit" }.forEach { card ->
            val key = pool(card)
            val amount = cents(card.limit)
            if (card.isSharedLimit && key.bank.isNotEmpty()) {
                shared[key] = (shared[key] ?: BigDecimal.ZERO).max(amount)
            } else totals[key.currency] = (totals[key.currency] ?: BigDecimal.ZERO) + amount
        }
        shared.forEach { (key, amount) -> totals[key.currency] = (totals[key.currency] ?: BigDecimal.ZERO) + amount }
        return totals.mapValues { it.value.movePointLeft(2).toDouble() }.toSortedMap()
    }

    fun interestFreeDays(card: SharedCard, today: LocalDate = LocalDate.now()): Int {
        if (card.cardCategory == "debit") return -1
        val bill = card.accountBillDate.trim().toIntOrNull() ?: return -1
        val due = card.dueDate.trim().toIntOrNull() ?: return -1
        if (bill !in 1..31 || due !in 1..31) return -1
        val actualBill = minOf(bill, today.lengthOfMonth())
        val next = if (card.billingDaySpendingToNextBill) today.dayOfMonth >= actualBill else today.dayOfMonth > actualBill
        val month = today.withDayOfMonth(1).plusMonths(if (next) 1 else 0)
        val dueMonth = month.plusMonths(if (due <= bill) 1 else 0)
        val target = dueMonth.withDayOfMonth(minOf(due, dueMonth.lengthOfMonth()))
        return ChronoUnit.DAYS.between(today, target).toInt().coerceAtLeast(0)
    }

    fun searchText(card: SharedCard): String = listOf(card.bank, card.alias, card.cardNumber,
        card.level, card.type, card.country, card.equity, card.remark, card.limit.toString(),
        if (card.cardCategory == "debit") "储蓄卡 儲蓄卡 debit" else "信用卡 credit",
        getCardBrand(card.cardNumber, card.level)).joinToString("\n").lowercase(Locale.ROOT)

    fun matches(card: SharedCard, query: String, index: String = searchText(card)): Boolean {
        val text = query.trim().lowercase(Locale.ROOT)
        if (text.isEmpty()) return true
        val compact = text.replace(Regex("[\\s-]"), "")
        if (compact.isEmpty()) return false
        val number = card.cardNumber.replace(Regex("[\\s-]"), "")
        return index.contains(text) || (compact.all { it in '0'..'9' } && number.contains(compact))
    }

    fun sorted(cards: List<SharedCard>, key: String, today: LocalDate = LocalDate.now()): List<SharedCard> {
        val days = if (key.startsWith("interest-")) cards.associate { it.id to interestFreeDays(it, today) } else emptyMap()
        return cards.sortedWith { a, b ->
            val order = when (key) {
                "limit-desc", "limit-asc" -> {
                    val left = if (a.cardCategory == "debit") 0.0 else a.limit.coerceAtLeast(0.0)
                    val right = if (b.cardCategory == "debit") 0.0 else b.limit.coerceAtLeast(0.0)
                    if (key == "limit-asc") left.compareTo(right) else right.compareTo(left)
                }
                "interest-desc", "interest-asc" -> {
                    val left = days.getValue(a.id); val right = days.getValue(b.id)
                    when {
                        left < 0 && right >= 0 -> 1
                        left >= 0 && right < 0 -> -1
                        key == "interest-asc" -> left.compareTo(right)
                        else -> right.compareTo(left)
                    }
                }
                "modifyTime" -> b.lastModifyTime.compareTo(a.lastModifyTime)
                "bank-asc" -> compareValuesBy(a, b, { it.bank }, { it.alias })
                else -> compareValuesBy(a, b, { it.country }, { it.bank }, { it.alias })
            }
            if (order != 0) order else a.id.compareTo(b.id)
        }
    }
}
