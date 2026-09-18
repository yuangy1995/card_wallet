package com.example.creditcard.data

/** Keep opaque fields from newer clients; never sync local UI state or legacy identities. */
internal object CardFutureFields {
    private val transient = setOf("showCardNumber", "showCVV", "countryRowSpan", "showCountry", "bankRowSpan", "showBank", "limitRowSpan", "showLimit", "lastTimeRowSpan", "showLastTime", "cardId", "uuid", "legacyId", "annualFeeDate", "extraFields", "constructor", "prototype")
    fun allowed(name: String) = !name.startsWith("_") && name !in transient
}
