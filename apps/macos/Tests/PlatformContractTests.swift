import XCTest
@testable import CreditCardMac

final class PlatformContractTests: XCTestCase {
    private struct Limits: Decodable { let name: String; let cards: [SharedCard]; let expected: [String: Double] }
    private struct Billing: Decodable { let name: String; let today: String; let card: SharedCard; let expected: Int }
    private struct Outcome: Codable, Equatable { let cardId: String; let state: String; let mutationId: String }
    private struct SyncCase: Decodable { let name: String; let collections: [[CardSyncRecord]]; let expected: [Outcome] }
    private func fixtures<T: Decodable>(_ name: String) throws -> T {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json", subdirectory: "fixtures"))
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
    func testSharedCreditFixturesInBothOrders() throws {
        let cases: [Limits] = try fixtures("credit-limits")
        for item in cases {
            XCTAssertEqual(WalletCardRules.creditLimits(item.cards), item.expected, item.name)
            XCTAssertEqual(WalletCardRules.creditLimits(Array(item.cards.reversed())), item.expected, item.name)
        }
    }
    func testCivilDatesAndClippedMonthEnd() throws {
        let cases: [Billing] = try fixtures("billing-dates")
        let formatter = ISO8601DateFormatter()
        for item in cases {
            let today = try XCTUnwrap(formatter.date(from: item.today + "T12:00:00Z"))
            XCTAssertEqual(WalletCardRules.interestFreeDays(item.card, today: today, timeZone: TimeZone(secondsFromGMT: 0)!), item.expected, item.name)
        }
    }
    func testSyncPermutationIdempotenceAndRoundTrip() throws {
        let cases: [SyncCase] = try fixtures("sync-cases")
        func outcomes(_ records: [CardSyncRecord]) -> [Outcome] {
            records.map { Outcome(cardId: $0.cardId, state: $0.state.rawValue, mutationId: $0.mutationId) }
        }
        for item in cases {
            let merged = CardSyncMergeEngine.merge(item.collections)
            XCTAssertEqual(outcomes(merged), item.expected, item.name)
            XCTAssertEqual(outcomes(CardSyncMergeEngine.merge(Array(item.collections.reversed()))), item.expected, item.name)
            XCTAssertEqual(outcomes(CardSyncMergeEngine.merge([merged, merged])), item.expected, item.name)
            let decoded = try JSONDecoder().decode([CardSyncRecord].self, from: JSONEncoder().encode(merged))
            XCTAssertEqual(outcomes(CardSyncMergeEngine.merge([decoded])), item.expected, item.name)
        }
    }
}
