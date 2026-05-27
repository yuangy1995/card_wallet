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

    private func card(_ id: String, bank: String = "银行") -> SharedCard {
        SharedCard(id: id, country: "中国", bank: bank, cardNumber: "1234", lastModifyTime: 0)
    }
}
