package com.example.creditcard.data

internal object CardFutureFields {
    private val transient = setOf("showCardNumber", "showCVV", "countryRowSpan", "showCountry", "bankRowSpan", "showBank", "limitRowSpan", "showLimit", "lastTimeRowSpan", "showLastTime", "cardId", "uuid", "legacyId")
    fun allowed(name: String) = !name.startsWith("_") && name !in transient
}
