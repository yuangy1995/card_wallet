package com.example.creditcard.utils

import com.example.creditcard.data.SharedCard
import java.math.BigDecimal
import java.math.RoundingMode
import java.util.Locale

/** Rules v1: keep independent regions/currencies apart and never invent an exchange rate. */
object CardMetrics {
    data class PoolKey(val country: String, val bank: String, val currency: String)
    private val parentheses = Regex("\\s*[（(][^（）()]*[）)]\\s*")
    private val whitespace = Regex("\\s+")
    fun bankKey(value: String): String = value.trim().replace(parentheses, "")
        .replace(whitespace, "").lowercase(Locale.ROOT)
    fun currency(card: SharedCard): String = card.type.trim().uppercase(Locale.ROOT)
    fun poolKey(card: SharedCard) = PoolKey(card.country.trim(), bankKey(card.bank), currency(card))
    private fun money(value: Double): BigDecimal = if (value.isFinite() && value >= 0)
        BigDecimal.valueOf(value).setScale(2, RoundingMode.HALF_UP) else BigDecimal.ZERO

    fun creditLimits(cards: List<SharedCard>): Map<String, Double> {
        val sums = linkedMapOf<String, BigDecimal>()
        val pools = linkedMapOf<PoolKey, BigDecimal>()
        for (card in cards) {
            if (card.cardCategory == "debit") continue
            val amount = money(card.limit)
            if (card.isSharedLimit) {
                val key = poolKey(card)
                pools[key] = (pools[key] ?: BigDecimal.ZERO).max(amount)
            } else sums[currency(card)] = (sums[currency(card)] ?: BigDecimal.ZERO) + amount
        }
        for ((key, amount) in pools) sums[key.currency] = (sums[key.currency] ?: BigDecimal.ZERO) + amount
        return sums.mapValues { it.value.toDouble() }.toSortedMap()
    }
}
