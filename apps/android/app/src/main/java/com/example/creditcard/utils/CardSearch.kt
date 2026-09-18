package com.example.creditcard.utils

import com.example.creditcard.data.SharedCard
import java.math.BigDecimal
import java.time.LocalDate
import java.util.Locale

/** Same searchable fields and ordering contract as the other clients. No sensitive-field index. */
object CardSearch {
    fun index(card: SharedCard): String = listOf(card.bank, CardMetrics.bankKey(card.bank), card.alias,
        card.cardNumber, card.cardNumber.filter { it in '0'..'9' }, card.level, card.type, card.country,
        card.equity, card.remark, if(card.limit.isFinite()) BigDecimal.valueOf(card.limit).stripTrailingZeros().toPlainString() else "",
        if(card.cardCategory == "debit") "储蓄卡 儲蓄卡 debit" else "信用卡 credit")
        .joinToString("\u001f").lowercase(Locale.ROOT)

    fun matches(index: String, query: String): Boolean {
        val query = query.trim().lowercase(Locale.ROOT)
        if(query.isEmpty() || index.contains(query)) return true
        val compact = query.replace(Regex("[\\s-]"), "")
        return compact.isNotEmpty() && compact.all { it in '0'..'9' } && index.contains(compact)
    }
    fun matches(card: SharedCard, query: String): Boolean = matches(index(card), query)

    fun sorted(cards: List<SharedCard>, mode: String, today: LocalDate = LocalDate.now()): List<SharedCard> {
        val days = if(mode.startsWith("interest-")) cards.associate { it.id to CardReminderRules.currentInterestFreeDays(it, today) } else emptyMap()
        fun limit(card: SharedCard) = if(card.cardCategory != "debit" && card.limit.isFinite()) maxOf(0.0, card.limit) else 0.0
        return cards.sortedWith { a, b ->
            val order = when(mode) {
                "limit-asc" -> limit(a).compareTo(limit(b))
                "limit-desc" -> limit(b).compareTo(limit(a))
                "modified-desc" -> b.lastModifyTime.compareTo(a.lastModifyTime)
                "bank-asc" -> CardMetrics.bankKey(a.bank).compareTo(CardMetrics.bankKey(b.bank))
                "interest-asc", "interest-desc" -> {
                    val left = days[a.id] ?: -1; val right = days[b.id] ?: -1
                    when { left < 0 && right >= 0 -> 1; right < 0 && left >= 0 -> -1
                        mode == "interest-asc" -> left.compareTo(right); else -> right.compareTo(left) }
                }
                else -> 0
            }
            if(order == 0) a.id.compareTo(b.id) else order
        }
    }
}
