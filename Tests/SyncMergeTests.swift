import XCTest
import CreditCardMac

final class SyncMergeTests: XCTestCase {
    func testNewerEventWinsAndUpdatesActiveCardTimestamp() {
        let old = CardSyncRecord.active(card("one"), changedAt: "2026-05-26T10:00:00.000Z")
        let updated = CardSyncRecord.active(card("one", bank: "新银行"), changedAt: "2026-05-26T10:00:01.000Z")

        let merged = CardSyncMergeEngine.merge([[old], [updated]])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].card?.bank, "新银行")
        XCTAssertEqual(merged[0].card?.lastModifyTime, DataMigrationManager.timestampMilliseconds(from: "2026-05-26T10:00:01.000Z"))
    }

    func testDeletionWinsAtSameTimeAndPreventsResurrection() {
        let active = CardSyncRecord.active(card("one"), changedAt: "2026-05-26T10:00:00.000Z")
        let deleted = CardSyncRecord.deleted(cardId: "one", changedAt: "2026-05-26T10:00:00.000Z")

        let merged = CardSyncMergeEngine.merge([[active], [deleted]])

        XCTAssertEqual(merged[0].state, .deleted)
        XCTAssertTrue(CardSyncMergeEngine.activeCards(from: merged).isEmpty)
    }

    func testSnapshotRoundTripIncludesTombstoneWithoutCardPayload() throws {
        let snapshot = WebDAVSyncSnapshotV3(
            source: "macos",
            records: [CardSyncRecord.deleted(cardId: "removed", changedAt: "2026-05-26T10:00:00.000Z")]
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WebDAVSyncSnapshotV3.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, "3.0.0")
        XCTAssertEqual(decoded.records[0].state, .deleted)
        XCTAssertNil(decoded.records[0].card)
    }

    func testDecodedRecordNormalizesEmbeddedCardIdAndTimestamp() throws {
        let json = """
        {
          "cardId": "web-id",
          "mutationId": "mutation",
          "changedAt": "2026-05-26T10:00:00.000Z",
          "state": "active",
          "card": {
            "id": "stale-local-id",
            "country": "中国",
            "bank": "东亚银行",
            "cardNumber": "6224000000005468",
            "lastModifyTime": 0,
            "billingDaySpendingToNextBill": true,
            "isSharedLimit": true
          }
        }
        """

        let decoded = try JSONDecoder().decode(CardSyncRecord.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.cardId, "web-id")
        XCTAssertEqual(decoded.card?.id, "web-id")
        XCTAssertEqual(decoded.card?.lastModifyTime, DataMigrationManager.timestampMilliseconds(from: "2026-05-26T10:00:00.000Z"))
    }

    func testBackupJSONParserReadsV3SnapshotCards() throws {
        let snapshot = WebDAVSyncSnapshotV3(
            source: "web",
            records: [CardSyncRecord.active(card("web-id", cardNumber: "6224000000005468"), changedAt: "2026-05-26T10:00:00.000Z")]
        )
        let data = try JSONEncoder().encode(snapshot)
        let json = String(data: data, encoding: .utf8)!

        let cards = DataMigrationManager.cardsFromBackupJSON(json)

        XCTAssertEqual(cards?.count, 1)
        XCTAssertEqual(cards?.first?.id, "web-id")
    }

    func testLegacyMigrationPreservesCardIdAliasInsteadOfGeneratingNewID() {
        let migrated = DataMigrationManager.migrateSingleCard([
            "cardId": "stable-legacy-id",
            "country": "中国",
            "bank": "东亚银行",
            "cardNumber": "6224000000005468",
            "lastModifyTime": "2026-05-27T10:00:00.000Z"
        ])

        XCTAssertEqual(migrated.id, "stable-legacy-id")
    }

    func testSameCardNumberWithDifferentIDsDoesNotRekeyCardIdentity() {
        let local = CardSyncRecord.active(
            card("mac-id", bank: "东亚银行", cardNumber: "6224000000005468", limit: 50_000),
            changedAt: "2026-05-27T10:00:00.000Z"
        )
        let remote = CardSyncRecord.active(
            card("web-id", bank: "东亚银行", cardNumber: "6224000000005468", limit: 150_000),
            changedAt: "2026-05-26T10:00:00.000Z"
        )

        let merged = CardSyncMergeEngine.merge([[local], [remote]])
        let activeCards = CardSyncMergeEngine.activeCards(from: merged)

        XCTAssertEqual(activeCards.count, 2)
        XCTAssertTrue(activeCards.contains { $0.id == "mac-id" && $0.limit == 50_000 })
        XCTAssertTrue(activeCards.contains { $0.id == "web-id" && $0.limit == 150_000 })
    }

    func testSameIDCanUpdateCardNumberWithoutChangingIdentity() {
        let oldCard = CardSyncRecord.active(
            card("stable-id", cardNumber: "6224000000005468", limit: 90_000),
            changedAt: "2026-05-27T10:00:00.000Z"
        )
        let replacedCard = CardSyncRecord.active(
            card("stable-id", cardNumber: "6224000000009999", limit: 40_000),
            changedAt: "2026-05-27T11:00:00.000Z"
        )

        let merged = CardSyncMergeEngine.merge([[oldCard], [replacedCard]])
        let activeCards = CardSyncMergeEngine.activeCards(from: merged)

        XCTAssertEqual(activeCards.count, 1)
        XCTAssertEqual(activeCards.first?.id, "stable-id")
        XCTAssertEqual(activeCards.first?.cardNumber, "6224000000009999")
        XCTAssertEqual(activeCards.first?.limit, 40_000)
    }

    func testMergeDropsRecordsWithoutCardIdentity() {
        let valid = CardSyncRecord.active(card("valid"), changedAt: "2026-05-27T10:00:00.000Z")
        let invalid = CardSyncRecord.active(card(""), changedAt: "2026-05-27T11:00:00.000Z")

        let merged = CardSyncMergeEngine.merge([[valid, invalid]])

        XCTAssertEqual(merged.map(\.cardId), ["valid"])
    }

    func testDecodedLedgerNormalizesDuplicateRecords() throws {
        let json = """
        {
          "records": [
            {
              "cardId": "same",
              "mutationId": "old",
              "changedAt": "2026-05-27T10:00:00.000Z",
              "state": "active",
              "card": {
                "id": "same",
                "country": "中国",
                "bank": "旧银行",
                "cardNumber": "1234",
                "lastModifyTime": 0,
                "billingDaySpendingToNextBill": true,
                "isSharedLimit": true
              }
            },
            {
              "cardId": "same",
              "mutationId": "new",
              "changedAt": "2026-05-27T11:00:00.000Z",
              "state": "active",
              "card": {
                "id": "same",
                "country": "中国",
                "bank": "新银行",
                "cardNumber": "1234",
                "lastModifyTime": 0,
                "billingDaySpendingToNextBill": true,
                "isSharedLimit": true
              }
            }
          ]
        }
        """

        let ledger = try JSONDecoder().decode(SyncLedger.self, from: Data(json.utf8))

        XCTAssertEqual(ledger.records.count, 1)
        XCTAssertEqual(ledger.records.first?.card?.bank, "新银行")
    }

    func testBackupJSONParserRejectsUnknownObjects() {
        let cards = DataMigrationManager.cardsFromBackupJSON(#"{"hello":"world"}"#)

        XCTAssertNil(cards)
    }

    func testRestoreIdentityReviewCanKeepCurrentCardForSameCardNumber() {
        let current = card("current-id", bank: "东亚银行", cardNumber: "6224000000005468", limit: 50_000)
        let incoming = card("generated-id", bank: "东亚银行", cardNumber: "6224 0000 0000 5468", limit: 90_000)

        let resolved = CardRestoreIdentityResolver.resolve(
            incomingCards: [incoming],
            existingCards: [current],
            decide: { _ in .keepCurrent }
        )

        XCTAssertEqual(resolved?.count, 1)
        XCTAssertEqual(resolved?.first?.id, "current-id")
        XCTAssertEqual(resolved?.first?.limit, 50_000)
    }

    func testRestoreIdentityReviewCanKeepIncomingDataUnderCurrentID() {
        let current = card("current-id", bank: "东亚银行", cardNumber: "6224000000005468", limit: 50_000)
        let incoming = card("generated-id", bank: "东亚银行", cardNumber: "6224 0000 0000 5468", limit: 90_000)

        let resolved = CardRestoreIdentityResolver.resolve(
            incomingCards: [incoming],
            existingCards: [current],
            decide: { _ in .keepIncoming }
        )

        XCTAssertEqual(resolved?.count, 1)
        XCTAssertEqual(resolved?.first?.id, "current-id")
        XCTAssertEqual(resolved?.first?.limit, 90_000)
    }

    func testRestoreIdentityReviewCanKeepSameNumberAsSeparateCardWithFreshID() {
        let current = card("current-id", bank: "东亚银行", cardNumber: "6224000000005468", limit: 50_000)
        let incoming = card("generated-id", bank: "东亚银行", cardNumber: "6224 0000 0000 5468", limit: 90_000)

        let resolved = CardRestoreIdentityResolver.resolve(
            incomingCards: [incoming],
            existingCards: [current],
            makeNewID: { "fresh-id" },
            decide: { _ in .keepSeparate }
        )

        XCTAssertEqual(resolved?.count, 2)
        XCTAssertTrue(resolved?.contains { $0.id == "current-id" && $0.limit == 50_000 } == true)
        XCTAssertTrue(resolved?.contains { $0.id == "fresh-id" && $0.limit == 90_000 } == true)
        XCTAssertFalse(resolved?.contains { $0.id == "generated-id" } == true)
    }

    private func card(
        _ id: String,
        bank: String = "银行",
        cardNumber: String = "1234",
        limit: Double = 0
    ) -> SharedCard {
        SharedCard(id: id, country: "中国", bank: bank, cardNumber: cardNumber, limit: limit, lastModifyTime: 0)
    }
}
