package com.example.creditcard.utils

import com.example.creditcard.data.SharedCard
import com.example.creditcard.data.CardSyncRecord
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class PlatformContractTest {
    private fun cases(name: String): JsonArray {
        val input = checkNotNull(javaClass.classLoader?.getResourceAsStream("$name.json"))
        return input.bufferedReader().use { Json.parseToJsonElement(it.readText()).jsonArray }
    }
    @Test fun creditPoolsAreOrderIndependent() {
        cases("credit-limits").forEach { value ->
            val item = value.jsonObject
            val cards = AppJson.json.decodeFromJsonElement<List<SharedCard>>(item.getValue("cards"))
            val expected = item.getValue("expected").jsonObject.mapValues { it.value.jsonPrimitive.double }
            assertEquals(item.getValue("name").toString(), expected, WalletCardRules.creditLimits(cards))
            assertEquals(expected, WalletCardRules.creditLimits(cards.reversed()))
        }
    }
    @Test fun datesUseActualMonthEnd() {
        cases("billing-dates").forEach { value ->
            val item = value.jsonObject
            val card = AppJson.json.decodeFromJsonElement<SharedCard>(item.getValue("card"))
            val today = LocalDate.parse(item.getValue("today").jsonPrimitive.content)
            assertEquals(item.getValue("name").toString(), item.getValue("expected").jsonPrimitive.int, WalletCardRules.interestFreeDays(card, today))
        }
    }
    @Test fun syncPermutationIdempotenceAndRoundTrip() {
        fun outcomes(records: List<CardSyncRecord>) = records.map {
            buildJsonObject { put("cardId", it.cardId); put("state", it.state); put("mutationId", it.mutationId) }
        }
        cases("sync-cases").forEach { value ->
            val item = value.jsonObject
            val collections = AppJson.json.decodeFromJsonElement<List<List<CardSyncRecord>>>(item.getValue("collections"))
            val expected = item.getValue("expected").jsonArray.toList()
            val merged = SyncMergeEngine.merge(*collections.toTypedArray())
            assertEquals(expected, outcomes(merged))
            assertEquals(expected, outcomes(SyncMergeEngine.merge(*collections.reversed().toTypedArray())))
            assertEquals(expected, outcomes(SyncMergeEngine.merge(merged, merged)))
            val decoded = AppJson.json.decodeFromString<List<CardSyncRecord>>(AppJson.json.encodeToString(merged))
            assertEquals(expected, outcomes(SyncMergeEngine.merge(decoded)))
        }
    }
}
