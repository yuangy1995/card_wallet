package com.example.creditcard.utils

import com.example.creditcard.data.CardSyncRecord
import com.example.creditcard.data.SharedCard
import org.junit.Assert.assertEquals
import org.junit.Test

class SyncMergeEngineTest {
    @Test
    fun mergeKeepsBlankCurrencyAndDefaultsBlankCategoryToCredit() {
        val record = CardSyncRecord(
            cardId = "card-1",
            mutationId = "mutation-1",
            changedAt = "2026-06-12T12:54:41.000Z",
            state = "active",
            card = SharedCard(id = "card-1", cardCategory = "", type = "")
        )

        val merged = SyncMergeEngine.merge(listOf(record))
        val card = merged.single().card

        assertEquals("credit", card?.cardCategory)
        assertEquals("", card?.type)
    }
}
