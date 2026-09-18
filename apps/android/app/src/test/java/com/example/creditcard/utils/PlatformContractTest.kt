package com.example.creditcard.utils

import com.example.creditcard.data.SharedCard
import com.example.creditcard.data.CardSyncRecord
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

class PlatformContractTest {
    private val json = Json { ignoreUnknownKeys = true }
    private fun cases(name: String) = json.parseToJsonElement(checkNotNull(javaClass.getResourceAsStream("/$name.json"))
        .bufferedReader().use { it.readText() }).jsonArray.map { it.jsonObject }
    private fun JsonObject.text(key: String) = getValue(key).jsonPrimitive.content
    private fun JsonObject.card() = json.decodeFromString<SharedCard>(getValue("card").toString())
    private fun millis(text: String) = LocalDate.parse(text).atTime(12,0).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
    @Test fun batchOperations() {
        for(row in cases("batch-operations")) {
            val source = row.card().copy(nextAnnualFeeCollectionTime=millis(row.text("target")))
            val update = row.getValue("update").jsonObject; val expected = row.getValue("expected").jsonObject
            fun JsonObject.optional(key: String) = get(key)?.jsonPrimitive?.contentOrNull
            val request = CardBatchUpdate(status=update.optional("status"),annualFee=update["annualFee"]?.jsonPrimitive?.double,
                nextAnnualFeeDate=update.optional("nextDate")?.let(::millis),valid=update.optional("valid"),cardCategory=update.optional("cardCategory"))
            val result = CardOperations.batch(listOf(source), row.getValue("selected").jsonArray.map { it.jsonPrimitive.content }.toSet(),request,millis(row.text("today"))).single()
            assertEquals(row.text("name"),expected.text("isQualified"),result.isQualified)
            assertEquals(expected["annualFee"]!!.jsonPrimitive.double,result.annualFee,0.0)
            assertEquals(expected.text("valid"),result.valid)
            assertEquals(expected.optional("nextDate")?.let(::millis),result.nextAnnualFeeCollectionTime)
            assertEquals(expected["changed"]!!.jsonPrimitive.boolean, result.lastModifyTime != source.lastModifyTime)
            assertEquals(source.extraFields,result.extraFields); assertEquals(source.cardImages,result.cardImages)
        }
    }
    @Test fun imageRoundtrip() {
        for(row in cases("image-roundtrip")) {
            val source = row.card(); val edited=source.copy(remark="只修改备注")
            val result = json.decodeFromString<SharedCard>(json.encodeToString(SharedCard.serializer(),edited))
            assertEquals(source.cardImages,result.cardImages)
            assertEquals(source.extraFields,result.extraFields)
            assertNotNull(result.extraFields["futureBenefit"])
            assertNotNull(result.cardImages.first().extraFields["futureCrop"])
        }
        assertFalse(CardAttachmentPolicy.canAppend(12,1)); assertTrue(CardAttachmentPolicy.canAppend(11,1))
    }
    @Test fun search() {
        for (row in cases("search")) assertEquals(row.text("name"), row.getValue("expected").jsonPrimitive.boolean,
            CardSearch.matches(row.card(), row.text("query")))
    }
    @Test fun sorting() {
        for (row in cases("sorting")) {
            val cards = json.decodeFromString<List<SharedCard>>(row.getValue("cards").toString())
            val expected = row.getValue("expected").jsonArray.map { it.jsonPrimitive.content }
            val today = LocalDate.parse(row.text("today"))
            assertEquals(expected, CardSearch.sorted(cards, row.text("mode"), today).map { it.id })
            assertEquals(expected, CardSearch.sorted(cards.reversed(), row.text("mode"), today).map { it.id })
        }
    }
    @Test fun creditLimits() {
        for (row in cases("credit-limits")) {
            val cards = json.decodeFromString<List<SharedCard>>(row.getValue("cards").toString())
            val expected = row.getValue("expected").jsonObject.mapValues { it.value.jsonPrimitive.double }
            assertEquals(row.text("name"), expected, CardMetrics.creditLimits(cards))
            assertEquals(expected, CardMetrics.creditLimits(cards.reversed()))
        }
    }
    @Test fun billingDates() {
        for (row in cases("billing-dates")) assertEquals(row.text("name"), row.getValue("expected").jsonPrimitive.int,
            CardReminderRules.currentInterestFreeDays(row.card(), LocalDate.parse(row.text("today"))))
    }
    @Test fun expiryMonth() {
        for (row in cases("expiry")) {
            val result = CardReminderRules.cardExpiryStatus(row.text("valid"), LocalDate.parse(row.text("today")))
            val kind = when(result) { CardExpiryStatus.EXPIRED -> "expired"; CardExpiryStatus.SOON_EXPIRING -> "soonExpiring"; CardExpiryStatus.NORMAL -> "normal"; null -> null }
            assertEquals(row.text("name"), row.getValue("expected").jsonPrimitive.contentOrNull, kind)
        }
    }
    @Test fun annualFees() {
        for (row in cases("annual-fees")) {
            val target = millis(row.text("target")); val today = millis(row.text("today"))
            assertEquals(row.text("name"), row.getValue("expectedDays").jsonPrimitive.int, CardReminderRules.annualFeeRemainingDays(target, today))
            val result = CardReminderRules.annualFeeDetection(SharedCard(isQualified=row.text("status"),nextAnnualFeeCollectionTime=target), nowMillis=today)
            val kind = when(result?.kind) { AnnualFeeDetectionKind.UNQUALIFIED -> "unqualified"; AnnualFeeDetectionKind.WARNING -> "warning"; AnnualFeeDetectionKind.OVERDUE -> "overdue"; null -> null }
            assertEquals(row.getValue("expectedKind").jsonPrimitive.contentOrNull, kind)
        }
    }
    @Test fun reminders() {
        for (row in cases("reminders")) {
            val result = CardReminderRules.billingCycleReminders(row.card(), LocalDate.parse(row.text("today"))).map {
                buildJsonObject { put("kind", if(it.kind == BillingCycleReminderKind.BILL) "bill" else "repayment"); put("days",it.days) }
            }
            assertEquals(row.text("name"), row.getValue("expected"), JsonArray(result))
        }
    }
    @Test fun syncConvergence() {
        for (row in cases("sync-conflicts")) {
            val records = json.decodeFromString<List<CardSyncRecord>>(row.getValue("records").toString())
            fun summary(records: List<CardSyncRecord>) = JsonArray(SyncMergeEngine.merge(records).map {
                buildJsonObject { put("cardId",it.cardId); put("mutationId",it.mutationId); put("state",it.state) }
            })
            assertEquals(row.text("name"), row.getValue("expected"), summary(records))
            assertEquals(summary(records), summary(records.reversed()))
            assertEquals(summary(records), summary(records+records))
        }
    }
}
