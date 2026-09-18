import XCTest
@testable import CreditCardIOS

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
    private struct SearchCase: Decodable { let name: String; let query: String; let cards: [SharedCard]; let expected: [String] }
    private struct SortCase: Decodable { let name: String; let key: String; let today: String; let cards: [SharedCard]; let expected: [String] }
    func testUnifiedSearchFieldsAndSeparators() throws {
        let cases: [SearchCase] = try fixtures("search")
        for item in cases {
            XCTAssertEqual(item.cards.filter { WalletCardRules.matches($0, query: item.query) }.map(\.id).sorted(), item.expected, item.name)
        }
    }
    func testStableSortingAndInvalidDatesLast() throws {
        let cases: [SortCase] = try fixtures("sorting")
        let formatter = ISO8601DateFormatter()
        for item in cases {
            let today = try XCTUnwrap(formatter.date(from: item.today + "T12:00:00Z"))
            for cards in [item.cards, Array(item.cards.reversed())] {
                XCTAssertEqual(WalletCardRules.sorted(cards, key: item.key, today: today, timeZone: TimeZone(secondsFromGMT: 0)!).map(\.id), item.expected, item.name)
            }
        }
    }
    private struct AppendCase: Decodable { let existing: Int; let incoming: Int; let expected: Bool }
    private struct ImageCases: Decodable { let limits: [String: Int]; let appendCases: [AppendCase] }
    private struct AnnualCase: Decodable {
        let id: String; let cardCategory: String; let isQualified: String
        let nextAnnualFeeCollectionTime: Double; let now: Double; let expectedDate: Double; let expectedStatus: String
    }
    func testSharedImagePolicy() throws {
        let input: ImageCases = try fixtures("card-images")
        XCTAssertEqual(input.limits, ["count": CardImagePolicy.maximumCount, "inputBytes": CardImagePolicy.maximumInputBytes, "storedBytes": CardImagePolicy.maximumStoredBytes, "edge": CardImagePolicy.maximumEdge])
        for c in input.appendCases { XCTAssertEqual(CardImagePolicy.canAppend(existing: c.existing, incoming: c.incoming), c.expected) }
        XCTAssertNil(CardImagePolicy.jpeg(from: Data("not-an-image".utf8)))
        XCTAssertNil(CardImagePolicy.jpeg(from: Data(repeating: 0, count: CardImagePolicy.maximumInputBytes + 1)))
    }
    func testAnnualConfirmationAndExistingImagePreservation() throws {
        let cases: [AnnualCase] = try fixtures("annual-fees")
        for c in cases {
            var card = SharedCard(id: c.id, country: "", bank: "Synthetic", cardNumber: "")
            card.cardCategory = c.cardCategory; card.isQualified = c.isQualified
            card.nextAnnualFeeCollectionTime = c.nextAnnualFeeCollectionTime
            card.cardImages = [CardImageAsset(id: "preserved", data: "existing-data")]
            let updated = WalletCardRules.settingAnnualStatus("1", for: card, now: Date(timeIntervalSince1970: c.now / 1000))
            XCTAssertEqual(updated.isQualified, c.expectedStatus, c.id)
            XCTAssertEqual(updated.nextAnnualFeeCollectionTime, c.expectedDate, c.id)
            XCTAssertEqual(updated.cardImages, card.cardImages)
        }
    }
}
