import XCTest
@testable import CreditCardMac

final class LocalParityTests: XCTestCase {
    func testFavoritesReadLatestAndPersistWithoutChangingCards() throws {
        let name = "wallet-favorites-test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        LocalCardPreferences.toggle("one", defaults: defaults)
        LocalCardPreferences.toggle("two", defaults: defaults)
        let read = { LocalCardPreferences.favoriteIDs(defaults.string(forKey: LocalCardPreferences.favoritesKey) ?? "[]") }
        XCTAssertEqual(read(), ["one", "two"])
        LocalCardPreferences.toggle("one", defaults: defaults)
        XCTAssertEqual(read(), ["two"])
        LocalCardPreferences.retain( ["one", "two", "three"], defaults: defaults)
        XCTAssertEqual(read(), ["two"])
        LocalCardPreferences.retain( ["one"], defaults: defaults)
        XCTAssertTrue(read().isEmpty)
    }
    func testMalformedFavoritePreferenceDoesNotCrash() {
        XCTAssertTrue(LocalCardPreferences.favoriteIDs("{}").isEmpty)
        XCTAssertTrue(LocalCardPreferences.favoriteIDs("broken").isEmpty)
    }
    func testMutationClockNeverMovesBackwards() {
        let now = Date(timeIntervalSince1970: 1789700000)
        let first = CardSyncRecord.nextTimestamp(after: CardSyncRecord.deleted(cardId: "test", changedAt: SyncTimestamp.string(from: 1789700000000)), now: now)
        let second = CardSyncRecord.nextTimestamp(after: CardSyncRecord.deleted(cardId: "test", changedAt: first), now: now)
        XCTAssertEqual(SyncTimestamp.milliseconds(from: first), 1789700000001)
        XCTAssertEqual(SyncTimestamp.milliseconds(from: second), 1789700000002)
    }
    func testDamagedLedgerIsNotReplacedWithSeedCards() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("sync-ledger-v4.json")
        let original = Data("invalid-ciphertext-do-not-replace".utf8)
        try original.write(to: file)
        let store = SyncLedgerStore(directory: directory)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
}

final class CardFutureFieldsTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "unknown-fields", withExtension: "json", subdirectory: "fixtures"))
        return try Data(contentsOf: url)
    }
    func testCardAndImageFieldsSurviveEditingAndCodableRoundTrip() throws {
        let data = try fixtureData()
        let input = try JSONDecoder().decode([String: CardJSONValue].self, from: data)
        var card = try JSONDecoder().decode(SharedCard.self, from: data)
        card.alias = "edited"
        let encoded = try JSONEncoder().encode(card)
        let output = try JSONDecoder().decode([String: CardJSONValue].self, from: encoded)
        XCTAssertEqual(output["futureProgram"], input["futureProgram"])
        XCTAssertEqual(output["futureNull"], .null)
        XCTAssertEqual(card.cardImages.first?.extraFields["futureImage"], .object(["rotation": .number(90), "labels": .array([.string("one"), .string("two")])]))
        for key in ["showCVV", "_localOnly", "legacyId", "extraFields"] { XCTAssertNil(output[key]) }
        XCTAssertNil(card.cardImages.first?.extraFields["showCVV"])
        XCTAssertEqual(try JSONDecoder().decode(SharedCard.self, from: encoded), card)
    }
    func testOpaqueFieldsNeverOverrideKnownFieldsOrIntroducePrototypeKeys() throws {
        var card = SharedCard(id: "real", country: "", bank: "", cardNumber: "")
        card.extraFields = ["id": .string("shadow"), "limit": .number(999), "constructor": .string("bad"), "future": .null]
        let output = try JSONDecoder().decode([String: CardJSONValue].self, from: JSONEncoder().encode(card))
        XCTAssertEqual(output["id"], .string("real"))
        XCTAssertEqual(output["limit"], .number(0))
        XCTAssertNil(output["constructor"])
        XCTAssertEqual(output["future"], .null)
    }
    func testSyncRecordRoundTripPreservesOpaqueFields() throws {
        let card = try JSONDecoder().decode(SharedCard.self, from: fixtureData())
        let record = CardSyncRecord.activeUsingCardTimestamp(card)
        let decoded = try JSONDecoder().decode(CardSyncRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded.card?.extraFields, card.extraFields)
        XCTAssertEqual(decoded.card?.cardImages, card.cardImages)
    }
    func testLegacyDictionaryBackupImportPreservesOpaqueFields() throws {
        let cards = try XCTUnwrap(DataMigrationManager.cardsFromBackupJSON("[" + String(decoding: fixtureData(), as: UTF8.self) + "]"))
        let original = try JSONDecoder().decode(SharedCard.self, from: fixtureData())
        XCTAssertEqual(cards.first?.extraFields, original.extraFields)
        XCTAssertEqual(cards.first?.cardImages.first?.extraFields, original.cardImages.first?.extraFields)
    }
}
