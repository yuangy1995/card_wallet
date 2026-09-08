package com.example.creditcard.utils

import com.example.creditcard.data.SyncSnapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class SyncSnapshotCompatibilityTest {
    @Test
    fun decodesIosStyleSyncSnapshot() {
        val json = """
            {
              "schemaVersion": "4.0.0",
              "snapshotId": "ios-snapshot-1",
              "generatedAt": "2026-06-14T05:16:23.641Z",
              "source": "ios",
              "records": [
                {
                  "cardId": "card-1",
                  "mutationId": "mutation-1",
                  "changedAt": "2026-06-14T05:16:23.641Z",
                  "state": "active",
                  "card": {
                    "id": "card-1",
                    "cardCategory": "debit",
                    "country": "香港特别行政区",
                    "bank": "汇丰银行",
                    "cardNumber": "1234567890129148",
                    "alias": "蓝狮子扣账卡（老妈）",
                    "level": null,
                    "type": null,
                    "limit": null,
                    "cvv": null,
                    "valid": "12/34",
                    "annualFee": null,
                    "isQualified": "2",
                    "nextAnnualFeeCollectionTime": null,
                    "lastTime": null,
                    "accountBillDate": null,
                    "dueDate": null,
                    "billingDaySpendingToNextBill": true,
                    "equity": null,
                    "remark": null,
                    "lastModifyTime": 1781428583641.0,
                    "isSharedLimit": true,
                    "cardImages": [
                      {
                        "id": "image-1",
                        "mimeType": "image/jpeg",
                        "data": "data:image/jpeg;base64,AAAA",
                        "createdAt": 1781428583641.0,
                        "source": "ios_photo_scan",
                        "name": "ios_photo_scan_1.jpg"
                      }
                    ]
                  }
                }
              ]
            }
        """.trimIndent()

        val snapshot = AppJson.json.decodeFromString(SyncSnapshot.serializer(), json)

        assertEquals("4.0.0", snapshot.schemaVersion)
        assertEquals("ios", snapshot.source)
        assertEquals(1, snapshot.records.size)
        val card = snapshot.records.single().card
        assertNotNull(card)
        assertEquals("蓝狮子扣账卡（老妈）", card?.alias)
        assertEquals("", card?.type)
        assertEquals(1781428583641L, card?.lastModifyTime)
        assertEquals(1781428583641L, card?.cardImages?.single()?.createdAt)
    }

    @Test
    fun decodesNullableCardImagesAsEmptyList() {
        val json = """
            {
              "schemaVersion": "4.0.0",
              "snapshotId": "snapshot-with-null-array",
              "generatedAt": "2026-06-14T05:16:23.641Z",
              "source": "web",
              "records": [
                {
                  "cardId": "card-1",
                  "changedAt": "2026-06-14T05:16:23.641Z",
                  "state": "active",
                  "card": {
                    "id": "card-1",
                    "cardCategory": "credit",
                    "country": "中国",
                    "bank": "测试银行",
                    "cardNumber": "1234",
                    "lastModifyTime": "2026-06-14T05:16:23.641Z",
                    "cardImages": null
                  }
                }
              ]
            }
        """.trimIndent()

        val snapshot = AppJson.json.decodeFromString(SyncSnapshot.serializer(), json)

        assertEquals(emptyList<Any>(), snapshot.records.single().card?.cardImages)
    }
}
