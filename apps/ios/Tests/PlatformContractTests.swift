import XCTest
#if !WALLET_CONTRACT_CLI
@testable import CreditCardIOS
#endif

final class PlatformContractTests: XCTestCase {
    private func cases(_ name: String) throws -> [[String: Any]] {
        #if WALLET_CONTRACT_CLI
        let url = URL(fileURLWithPath: ProcessInfo.processInfo.environment["WALLET_CONTRACT_DIR"]!).appendingPathComponent(name + ".json")
        #else
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        #endif
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
    }
    private func card(_ value: Any) throws -> SharedCard {
        try JSONDecoder().decode(SharedCard.self, from: JSONSerialization.data(withJSONObject: value))
    }
    private func day(_ value: Any?) throws -> Date {
        let parts = try XCTUnwrap(value as? String).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { throw NSError(domain: "fixture", code: 1) }
        return try XCTUnwrap(CardCalendarRules.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)))
    }
    func testSearch() throws {
        for row in try cases("search") {
            XCTAssertEqual(CardSearch.matches(try card(row["card"]!), query: row["query"] as! String), row["expected"] as! Bool, row["name"] as! String)
        }
    }
    func testSorting() throws {
        for row in try cases("sorting") {
            let cards = try (row["cards"] as! [Any]).map(card)
            let today = try day(row["today"])
            XCTAssertEqual(CardSearch.sorted(cards, mode: row["mode"] as! String, today: today).map(\.id), row["expected"] as! [String])
            XCTAssertEqual(CardSearch.sorted(cards.reversed(), mode: row["mode"] as! String, today: today).map(\.id), row["expected"] as! [String])
        }
    }
    func testCreditLimits() throws {
        for row in try cases("credit-limits") {
            let cards = try (row["cards"] as! [Any]).map(card)
            let expected = row["expected"] as! [String: Double]
            XCTAssertEqual(CardMetrics.creditLimits(cards: cards), expected, row["name"] as! String)
            XCTAssertEqual(CardMetrics.creditLimits(cards: cards.reversed()), expected, row["name"] as! String)
        }
    }
    func testBillingDates() throws {
        for row in try cases("billing-dates") {
            let card = try card(row["card"]!)
            let today = try day(row["today"])
            let expected = row["expected"] as! Int
            XCTAssertEqual(DateCalculator.calculateInterestFreeDays(card: card, today: today), expected, row["name"] as! String)
            if card.cardCategory != "debit" {
                XCTAssertEqual(DateCalculator.calculateInterestFreePeriod(accountBillDate: card.accountBillDate ?? "", dueDate: card.dueDate ?? "", billingDayToNextBill: card.billingDaySpendingToNextBill, today: today), expected)
            }
        }
    }
    func testExpiryMonth() throws {
        for row in try cases("expiry") {
            let actual = DateCalculator.cardExpiryStatus(valid: row["valid"] as? String, now: try day(row["today"]))
            let text: String? = actual.map { value in
                switch value { case .expired: return "expired"; case .soonExpiring: return "soonExpiring"; case .normal: return "normal" }
            }
            XCTAssertEqual(text, row["expected"] as? String, row["name"] as! String)
        }
    }
    func testAnnualFees() throws {
        for row in try cases("annual-fees") {
            let timestamp = try day(row["target"]).timeIntervalSince1970 * 1000
            let today = try day(row["today"])
            XCTAssertEqual(DateCalculator.annualFeeRemainingDays(timestamp, now: today), row["expectedDays"] as? Int, row["name"] as! String)
            let result = DateCalculator.annualFeeDetection(isQualified: row["status"] as? String, nextAnnualFeeDate: timestamp, now: today)
            let kind: String? = result.map { value in
                switch value.kind { case .unqualified: return "unqualified"; case .warning: return "warning"; case .overdue: return "overdue" }
            }
            XCTAssertEqual(kind, row["expectedKind"] as? String, row["name"] as! String)
        }
    }
    func testMonotonicLocalEdits() {
        let existing = CardSyncRecord(cardId: "a", mutationId: "z", changedAt: "2026-09-18T00:00:00.000Z", state: .deleted, card: nil)
        let edit = CardSyncRecord(cardId: "a", mutationId: "a", changedAt: "2026-09-17T00:00:00.000Z", state: .deleted, card: nil)
        let events = CardSyncMergeEngine.localEvents([edit, edit], after: [existing])
        XCTAssertEqual(events.map(\.changedAt), ["2026-09-18T00:00:00.001Z", "2026-09-18T00:00:00.002Z"])
    }
    func testReminders() throws {
        for row in try cases("reminders") {
            let card = try card(row["card"]!)
            let reminders = DateCalculator.billingCycleReminders(for: card, now: try day(row["today"]))
            let expected = row["expected"] as! [[String: Any]]
            XCTAssertEqual(reminders.count, expected.count, row["name"] as! String)
            for (reminder, result) in zip(reminders, expected) {
                XCTAssertEqual(reminder.kind == .bill ? "bill" : "repayment", result["kind"] as? String)
                XCTAssertEqual(reminder.days, result["days"] as? Int)
            }
        }
    }
    func testSyncConvergence() throws {
        for row in try cases("sync-conflicts") {
            let records = try JSONDecoder().decode([CardSyncRecord].self, from: JSONSerialization.data(withJSONObject: row["records"]!))
            let expected = row["expected"] as! [[String: String]]
            func summary(_ values: [CardSyncRecord]) -> [[String: String]] {
                CardSyncMergeEngine.merge([values]).map { ["cardId": $0.cardId, "mutationId": $0.mutationId, "state": $0.state.rawValue] }
            }
            XCTAssertEqual(summary(records), expected, row["name"] as! String)
            XCTAssertEqual(summary(records.reversed()), expected)
            XCTAssertEqual(summary(records + records), expected)
        }
    }

    func testBatchOperations() throws {
        for row in try cases("batch-operations") {
            var source = try card(row["card"]!)
            source.nextAnnualFeeCollectionTime = try day(row["target"]).timeIntervalSince1970 * 1000
            let update = row["update"] as! [String: Any], expected = row["expected"] as! [String: Any]
            let request = CardBatchUpdate(status: update["status"] as? String, annualFee: update["annualFee"] as? Double,
                nextAnnualFeeDate: try (update["nextDate"] as? String).map { try day($0).timeIntervalSince1970 * 1000 },
                valid: update["valid"] as? String, cardCategory: update["cardCategory"] as? String)
            let result = CardOperations.batch([source], ids: Set(row["selected"] as! [String]), update: request, now: try day(row["today"]))[0]
            XCTAssertEqual(result.isQualified, expected["isQualified"] as? String, row["name"] as! String)
            XCTAssertEqual(result.annualFee, expected["annualFee"] as? Double)
            XCTAssertEqual(result.valid, expected["valid"] as? String)
            XCTAssertEqual(result.nextAnnualFeeCollectionTime, try (expected["nextDate"] as? String).map { try day($0).timeIntervalSince1970 * 1000 })
            XCTAssertEqual(result.lastModifyTime != source.lastModifyTime, expected["changed"] as? Bool)
            XCTAssertEqual(result.cardImages, source.cardImages)
            XCTAssertEqual(result.extraFields, source.extraFields)
        }
    }
    func testImageRoundtrip() throws {
        for row in try cases("image-roundtrip") {
            var value = try card(row["card"]!); value.remark = "只修改备注"
            let saved = try JSONDecoder().decode(SharedCard.self, from: JSONEncoder().encode(value))
            let input = try card(row["card"]!)
            XCTAssertEqual(saved.cardImages, input.cardImages, row["name"] as! String)
            XCTAssertEqual(saved.extraFields, input.extraFields)
            XCTAssertNotNil(saved.extraFields["futureBenefit"])
            XCTAssertNotNil(saved.cardImages.first?.extraFields["futureCrop"])
            XCTAssertFalse(CardAttachmentPolicy.canAppend(existingCount: 12, additionalCount: 1))
            XCTAssertTrue(CardAttachmentPolicy.canAppend(existingCount: 11, additionalCount: 1))
        }
    }
    func testLocalFavorites() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "wallet-test-" + UUID().uuidString))
        defaults.removeObject(forKey: LocalCardPreferences.favoritesKey)
        LocalCardPreferences.toggleFavorite("a", in: defaults)
        LocalCardPreferences.toggleFavorite("b", in: defaults)
        XCTAssertEqual(LocalCardPreferences.favorites(in: defaults), ["a", "b"])
        // Only confirmed tombstones, not a filtered/empty visible list, prune saved favorites.
        LocalCardPreferences.removeDeleted([], in: defaults)
        XCTAssertEqual(LocalCardPreferences.favorites(in: defaults), ["a", "b"])
        LocalCardPreferences.removeDeleted(["a"], in: defaults)
        XCTAssertEqual(LocalCardPreferences.favorites(in: defaults), ["b"])
        LocalCardPreferences.toggleFavorite("b", in: defaults)
        XCTAssertTrue(LocalCardPreferences.favorites(in: defaults).isEmpty)
        defaults.removeObject(forKey: LocalCardPreferences.favoritesKey)
    }
}
