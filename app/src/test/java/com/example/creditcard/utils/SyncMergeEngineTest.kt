package com.example.creditcard.utils

import com.example.creditcard.data.CardSyncRecord
import com.example.creditcard.data.SharedCard
import com.example.creditcard.data.SyncSnapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncMergeEngineTest {
    @Test
    fun newerEventWinsAndNormalizesEmbeddedCardIdentity() {
        val old = CardSyncRecord(
            cardId = "card-1",
            mutationId = "old",
            changedAt = "2026-05-28T10:00:00Z",
            state = "active",
            card = card("stale-id", bank = "旧银行")
        )
        val updated = CardSyncRecord(
            cardId = "card-1",
            mutationId = "new",
            changedAt = "2026-05-28T10:00:01.000Z",
            state = "active",
            card = card("stale-id", bank = "新银行")
        )

        val merged = SyncMergeEngine.merge(listOf(old), listOf(updated))

        assertEquals(1, merged.size)
        assertEquals("新银行", merged[0].card?.bank)
        assertEquals("card-1", merged[0].card?.id)
        assertEquals(SyncTime.parseMillis("2026-05-28T10:00:01.000Z"), merged[0].card?.lastModifyTime)
    }

    @Test
    fun deletionWinsAtSameTimestampAndDropsCardPayload() {
        val active = CardSyncRecord(
            cardId = "card-1",
            mutationId = "a",
            changedAt = "2026-05-28T10:00:00.000Z",
            state = "active",
            card = card("card-1")
        )
        val deleted = CardSyncRecord(
            cardId = "card-1",
            mutationId = "b",
            changedAt = "2026-05-28T10:00:00.000Z",
            state = "deleted",
            card = card("card-1")
        )

        val merged = SyncMergeEngine.merge(listOf(active), listOf(deleted))

        assertEquals("deleted", merged[0].state)
        assertNull(merged[0].card)
        assertTrue(SyncMergeEngine.extractActiveCards(merged).isEmpty())
    }

    @Test
    fun snapshotDecodeAcceptsLegacyFieldTypesFromOtherClients() {
        val json = """
            {
              "schemaVersion": "3.0.0",
              "snapshotId": "snapshot",
              "generatedAt": "2026-05-28T10:00:00.000Z",
              "source": "web",
              "records": [
                {
                  "cardId": "web-id",
                  "mutationId": "mutation",
                  "changedAt": "2026-05-28T10:00:00.000Z",
                  "state": "active",
                  "card": {
                    "id": "stale-id",
                    "country": 86,
                    "bank": "东亚银行",
                    "alias": "测试卡",
                    "level": "白金卡",
                    "cardNumber": 6224000000005468,
                    "cvv": 123,
                    "valid": "08/29",
                    "limit": "50000.50",
                    "type": "CNY",
                    "isSharedLimit": "1",
                    "accountBillDate": 10,
                    "dueDate": 28,
                    "billingDaySpendingToNextBill": "true",
                    "annualFee": "360",
                    "isQualified": 2,
                    "nextAnnualFeeCollectionTime": "2026-06-01",
                    "lastTime": "2026-01-01",
                    "lastModifyTime": 0,
                    "equity": "机场贵宾厅",
                    "remark": "备注"
                  }
                }
              ]
            }
        """.trimIndent()

        val snapshot = AppJson.json.decodeFromString<SyncSnapshot>(json)
        val activeCard = SyncMergeEngine.extractActiveCards(snapshot.records).single()

        assertEquals("web-id", activeCard.id)
        assertEquals("86", activeCard.country)
        assertEquals("6224000000005468", activeCard.cardNumber)
        assertEquals(50_000.50, activeCard.limit, 0.0)
        assertEquals(true, activeCard.isSharedLimit)
        assertEquals("10", activeCard.accountBillDate)
        assertEquals("28", activeCard.dueDate)
        assertEquals("2", activeCard.isQualified)
        assertNotNull(activeCard.nextAnnualFeeCollectionTime)
        assertEquals(SyncTime.parseMillis("2026-05-28T10:00:00.000Z"), activeCard.lastModifyTime)
    }

    private fun card(id: String, bank: String = "银行") = SharedCard(
        id = id,
        country = "中国",
        bank = bank,
        cardNumber = "6224000000005468",
        billingDaySpendingToNextBill = true,
        isSharedLimit = true,
        lastModifyTime = 0
    )
}
