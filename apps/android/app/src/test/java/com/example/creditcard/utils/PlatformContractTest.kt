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
    @org.junit.Test fun commonSearchAndSorting() {
        val search = cases("search")
        search.forEach { value ->
            val item = value.jsonObject
            val cards = AppJson.json.decodeFromJsonElement<List<SharedCard>>(item.getValue("cards"))
            val expected = item.getValue("expected").jsonArray.map { it.jsonPrimitive.content }
            assertEquals(expected, cards.filter { WalletCardRules.matches(it, item.getValue("query").jsonPrimitive.content) }.map { it.id }.sorted())
        }
        cases("sorting").forEach { value ->
            val item = value.jsonObject
            val cards = AppJson.json.decodeFromJsonElement<List<SharedCard>>(item.getValue("cards"))
            val expected = item.getValue("expected").jsonArray.map { it.jsonPrimitive.content }
            val key = item.getValue("key").jsonPrimitive.content
            val day = LocalDate.parse(item.getValue("today").jsonPrimitive.content)
            assertEquals(expected, WalletCardRules.sorted(cards, key, day).map { it.id })
            assertEquals(expected, WalletCardRules.sorted(cards.reversed(), key, day).map { it.id })
        }
    }
    @Test fun imageLimitsAndExistingImagePreservation() {
        val input = checkNotNull(javaClass.classLoader?.getResourceAsStream("card-images.json"))
        val spec = input.bufferedReader().use { Json.parseToJsonElement(it.readText()).jsonObject }
        assertEquals(20, CardImageCodec.MAX_COUNT)
        assertEquals(10485760, CardImageCodec.MAX_INPUT_BYTES)
        assertEquals(2097152, CardImageCodec.MAX_STORED_BYTES)
        spec.getValue("appendCases").jsonArray.forEach { value ->
            val c=value.jsonObject
            assertEquals(c.getValue("expected").jsonPrimitive.boolean, CardImageCodec.canAppend(c.getValue("existing").jsonPrimitive.int,c.getValue("incoming").jsonPrimitive.int))
        }
    }
    @Test fun annualConfirmationUsesCommonCases() {
        cases("annual-fees").forEach { value ->
            val c=value.jsonObject
            val card=SharedCard(id=c.getValue("id").jsonPrimitive.content, cardCategory=c.getValue("cardCategory").jsonPrimitive.content,
                isQualified=c.getValue("isQualified").jsonPrimitive.content, nextAnnualFeeCollectionTime=c.getValue("nextAnnualFeeCollectionTime").jsonPrimitive.long,
                cardImages=listOf(com.example.creditcard.data.CardImageAsset(id="existing",data="preserved")))
            val result=CardReminderRules.confirmAnnualFeeQualified(card,c.getValue("now").jsonPrimitive.long)
            assertEquals(c.getValue("expectedStatus").jsonPrimitive.content,result.isQualified)
            assertEquals(c.getValue("expectedDate").jsonPrimitive.long,result.nextAnnualFeeCollectionTime)
            assertEquals(card.cardImages,result.cardImages)
        }
    }
}
