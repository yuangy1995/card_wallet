import XCTest
#if os(iOS)
@testable import CreditCardIOS
#else
@testable import CreditCardMac
#endif

/// One fixture is consumed by all four clients. No real files, credentials or network.
@MainActor
final class SessionRoundTripTests: XCTestCase {
    private final class Disk: @unchecked Sendable {
        private let lock = NSLock()
        private var data: Data
        private var writes = 0
        init(_ records: [CardSyncRecord]) throws {
            data = try JSONEncoder().encode(SyncLedger(records: records, processedWebDAVSnapshotIDs: ["seen-fixture"], pendingWebDAVUpload: true))
        }
        func load() throws -> SyncLedger {
            try lock.withLock { try JSONDecoder().decode(SyncLedger.self, from: data) }
        }
        func save(_ value: SyncLedger) -> Bool {
            XCTAssertFalse(Thread.isMainThread)
            do {
                let encoded = try JSONEncoder().encode(value)
                lock.withLock { data = encoded; writes += 1 }
                return true
            } catch { return false }
        }
        var writeCount: Int { lock.withLock { writes } }
    }
    private func make(_ disk: Disk) -> SyncCoordinator {
        #if os(iOS)
        return SyncCoordinator(readLock: { false },
            readCards: { XCTFail("Existing ledger must not fall back to the old mirror"); return .success([]) },
            loadExistingLedger: { try disk.load() }, readLedger: { _ in try disk.load() },
            saveLedger: { disk.save($0) }, persistCards: { _ in true },
            readHistory: { [] }, writeHistory: { _ in }, configurationReady: { false },
            suspendClient: { _ in }, defaults: UserDefaults(suiteName: "session-roundtrip-" + UUID().uuidString)!)
        #else
        return SyncCoordinator(readLock: { false },
            readCards: { XCTFail("Existing ledger must not fall back to the old mirror"); return .success([]) },
            loadExistingLedger: { try disk.load() }, loadLedger: { _ in try disk.load() },
            saveLedger: { disk.save($0) }, persistCards: { _ in true },
            configureBridge: { _ in }, suspendBridge: { _ in })
        #endif
    }
    private func resume(_ sut: SyncCoordinator) async throws -> [SharedCard] {
        sut.setSuspended(isLocked: false)
        #if os(iOS)
        await sut.waitForLocalData()
        XCTAssertEqual(sut.localLoadState, .ready)
        return sut.cards
        #else
        return try await sut.bootstrap()
        #endif
    }
    func testOfflineEditLockAndReloadPreserveImagesFutureFieldsAndTombstones() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "session-roundtrip", withExtension: "json", subdirectory: "fixtures"))
        let records = try JSONDecoder().decode([CardSyncRecord].self, from: Data(contentsOf: url))
        let disk = try Disk(records), sut = make(disk)
        defer { sut.setSuspended(isLocked: true) }
        let loaded = try await resume(sut)
        let original = try XCTUnwrap(loaded.first)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertFalse(original.extraFields.isEmpty)
        XCTAssertFalse(try XCTUnwrap(original.cardImages.first).extraFields.isEmpty)
        let updated = try await sut.mutateCards { cards in
            cards.map { card in var value = card; value.alias = "offline edit"; return value }
        }
        let durable = try disk.load()
        sut.setSuspended(isLocked: true)
        #if os(iOS)
        XCTAssertTrue(sut.cards.isEmpty)
        XCTAssertEqual(sut.retainedRecordCount, 0)
        #else
        XCTAssertTrue(sut.currentCards.isEmpty)
        #endif
        XCTAssertEqual(try disk.load().records, durable.records, "Locking is not a deletion or a disk write")
        let restored = try await resume(sut)
        XCTAssertEqual(restored, updated)
        XCTAssertEqual(restored.first?.id, original.id)
        XCTAssertEqual(restored.first?.cardImages, original.cardImages)
        XCTAssertEqual(restored.first?.extraFields, original.extraFields)
        XCTAssertGreaterThan(try XCTUnwrap(restored.first).lastModifyTime, original.lastModifyTime)
        XCTAssertEqual(durable.records.first { $0.cardId == "session-deleted" }, records.first { $0.cardId == "session-deleted" })
        XCTAssertTrue(try disk.load().pendingWebDAVUpload)
        XCTAssertEqual(try disk.load().processedWebDAVSnapshotIDs, ["seen-fixture"])
        XCTAssertEqual(disk.writeCount, 1, "Unlocking must not rewrite the complete wallet")
        XCTAssertEqual(CardSyncMergeEngine.merge([durable.records, records]), durable.records, "A stale peer must not revert edits or revive a deleted card")
    }
}
