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
