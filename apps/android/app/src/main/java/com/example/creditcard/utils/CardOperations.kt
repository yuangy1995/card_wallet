package com.example.creditcard.utils

import com.example.creditcard.data.SharedCard

data class CardBatchUpdate(val status: String? = null, val annualFee: Double? = null, val nextAnnualFeeDate: Long? = null,
    val valid: String? = null, val cardCategory: String? = null)

object CardOperations {
    fun annualStatus(status: String, card: SharedCard, now: Long = System.currentTimeMillis()): SharedCard {
        if(card.cardCategory == "debit" || status !in listOf("1", "2", "3")) return card
        if(status == "1" && card.isQualified == "1" && CardReminderRules.annualFeeDetection(card, nowMillis=now) == null) return card
        val result = card.copy(isQualified=status, nextAnnualFeeCollectionTime=when(status) {
            "1" -> CardReminderRules.timestampByAddingOneYear(card.nextAnnualFeeCollectionTime)
            "3" -> null
            else -> card.nextAnnualFeeCollectionTime
        })
        return if(result == card) card else result.copy(lastModifyTime=now)
    }
    fun batch(cards: List<SharedCard>, ids: Set<String>, update: CardBatchUpdate, now: Long = System.currentTimeMillis()): List<SharedCard> = cards.map { card ->
        if(card.id !in ids) return@map card
        var result = card.copy(cardCategory=update.cardCategory?.let { if(it == "debit") "debit" else "credit" } ?: card.cardCategory)
        if(result.cardCategory != "debit") {
            val status = update.status
            if(status in listOf("1", "2", "3")) {
                result = if(status == "1" && update.nextAnnualFeeDate == null) annualStatus("1", result, now)
                    else result.copy(isQualified=status!!)
            }
            val fee = update.annualFee
            if(fee != null && fee.isFinite() && fee >= 0) result = result.copy(annualFee=fee)
            result = result.copy(nextAnnualFeeCollectionTime=if(result.isQualified == "3") null else update.nextAnnualFeeDate ?: result.nextAnnualFeeCollectionTime)
        }
        result = result.copy(valid=update.valid ?: result.valid)
        if(result == card) card else result.copy(lastModifyTime=now)
    }
}
