import XCTest
@testable import CreditCardMac

final class SelectiveMergeTests: XCTestCase {
    private static func isOnMainThread() -> Bool { Thread.isMainThread }
    private func card(_ id: String, limit: Double) -> SharedCard {
        SharedCard(id: id, country: "中国", bank: "测试银行", cardNumber: "4111111111118000", type: "CNY", limit: limit, valid: "12/29", accountBillDate: "31", dueDate: "28", lastModifyTime: 1_700_000_000_000)
    }

    @MainActor
    func testBackgroundCatalogPreservesFilteringOrderingAndSharedLimits() async {
        let cards = [card("a", limit: 30000), card("b", limit: 80000)]
        let query = CardCatalogQuery(search: "8000", group: .bank, sort: .limitDesc)
        let expected = CardCatalog.groups(items: cards.map(CardCatalogItem.init), query: query)
        let (actual, usedMainThread) = await Task.detached {
            (CardCatalog.groups(items: cards.map(CardCatalogItem.init), query: query), Self.isOnMainThread())
        }.value
        XCTAssertFalse(usedMainThread)
        XCTAssertEqual(actual.map(\.id), expected.map(\.id))
        XCTAssertEqual(actual.flatMap(\.items).map(\.id), ["b", "a"])
        XCTAssertEqual(actual.first?.limits["CNY"], 80000)
    }

    @MainActor
    func testBackgroundNotificationPlanningPreservesMonthEndDates() async throws {
        let calendar = Calendar.current
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12)))
        let cards = [card("notification-test", limit: 80000)]
        let expected = CardSystemNotificationCenter.buildPlans(cards: cards, now: now)
        let (actual, usedMainThread) = await Task.detached {
            (CardSystemNotificationCenter.buildPlans(cards: cards, now: now), Self.isOnMainThread())
        }.value
        XCTAssertFalse(usedMainThread)
        XCTAssertEqual(actual.map(\.identifier), expected.map(\.identifier))
        XCTAssertEqual(actual.map(\.fireDate), expected.map(\.fireDate))
        let februaryBill = try XCTUnwrap(actual.first {
            $0.identifier.hasPrefix("card_scheduled_bill_") && calendar.component(.year, from: $0.fireDate) == 2026 && calendar.component(.month, from: $0.fireDate) == 2
        })
        XCTAssertEqual(calendar.component(.day, from: februaryBill.fireDate), 28 - DateCalculator.billWarningDays)
    }

    @MainActor
    func testSnapshotEncryptedOffMainThreadRetainsSyncV4Compatibility() async throws {
        let card = card("encryption-test", limit: 80000)
        let password = "test-only-sync-password"
        let (ciphertext, usedMainThread) = try await Task.detached {
            let snapshot = WebDAVSyncSnapshotV4(source: "macos", records: [.legacyActive(card)])
            let data = try JSONEncoder().encode(snapshot)
            let json = String(decoding: data, as: UTF8.self)
            return (try CryptoManager.encryptSyncEnvelopeV4(plainText: json, password: password), Self.isOnMainThread())
        }.value
        XCTAssertFalse(usedMainThread)
        let json = try CryptoManager.decryptSyncEnvelopeV4(envelopeText: ciphertext, password: password)
        let restored = try JSONDecoder().decode(WebDAVSyncSnapshotV4.self, from: Data(json.utf8))
        XCTAssertEqual(CardSyncMergeEngine.activeCards(from: restored.records), [card])
    }
}
