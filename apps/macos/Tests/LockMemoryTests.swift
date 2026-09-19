import XCTest
import AppKit
@testable import CreditCardMac

@MainActor
final class LockMemoryTests: XCTestCase {
    private final class Disk: @unchecked Sendable {
        private let guardLock = NSLock()
        var failRead = false
        var loadCount = 0
        var saveCount = 0
        var activeViewWrites = 0
        var value = SyncLedger(records: [
            .legacyActive(SharedCard(id: "local", country: "CN", bank: "Test Bank", cardNumber: "test-card")),
            .deleted(cardId: "deleted", changedAt: "2026-09-19T00:00:00.000Z")
        ], processedWebDAVSnapshotIDs: ["acknowledged"], lastWebDAVSnapshotFilename: "previous.json", pendingWebDAVUpload: true)
        func read() throws -> SyncLedger {
            try guardLock.withLock {
                loadCount += 1
                if failRead { throw CocoaError(.fileReadCorruptFile) }
                return value
            }
        }
        func write(_ new: SyncLedger) -> Bool { guardLock.withLock { saveCount += 1; value = new; return true } }
        func mirror() -> Bool { guardLock.withLock { activeViewWrites += 1; return true } }
        // Tests access fields only after awaiting the corresponding operation, never concurrently.
    }
    @MainActor
    private final class Harness {
        let store = Disk()
        var locked = false
        var failRead: Bool { get { store.failRead } set { store.failRead = newValue } }
        var loadCount: Int { store.loadCount }
        var saveCount: Int { store.saveCount }
        var activeViewWrites: Int { store.activeViewWrites }
        var disk: SyncLedger { store.value }
        var configured = 0
        var suspended: [Bool] = []
        var provider: (() -> [CardSyncRecord])?
        var merger: (([CardSyncRecord]) async -> Bool)?
        lazy var coordinator = SyncCoordinator(
            readLock: { [unowned self] in self.locked },
            loadLedger: { [store] _ in try store.read() },
            saveLedger: { [store] in store.write($0) },
            persistCards: { [store] _ in store.mirror() },
            configureBridge: { [unowned self] callbacks in
                self.configured += 1
                self.provider = callbacks.records
                self.merger = callbacks.merge
            },
            suspendBridge: { [unowned self] in self.suspended.append($0) }
        )
        func lock() { locked = true; coordinator.setSuspended(isLocked: true) }
        func unlock() { locked = false; coordinator.setSuspended(isLocked: false) }
        func retainedLedger() throws -> SyncLedger {
            try XCTUnwrap(Mirror(reflecting: coordinator).children.first { $0.label == "ledger" }?.value as? SyncLedger)
        }
    }

    func testLockActuallyDropsLedgerAndObserverWithoutWritingEmptyData() async throws {
        let h = Harness()
        let restored = try await h.coordinator.bootstrap(localCards: [])
        XCTAssertEqual(restored.map(\.id), ["local"])
        let diskBefore = try JSONEncoder().encode(h.disk)
        var published: [SharedCard]?
        h.coordinator.onCardsChanged = { published = $0 }
        h.lock()
        XCTAssertTrue(h.coordinator.currentCards.isEmpty)
        XCTAssertTrue(try h.retainedLedger().records.isEmpty)
        XCTAssertTrue(try h.retainedLedger().processedWebDAVSnapshotIDs.isEmpty)
        XCTAssertNil(h.coordinator.onCardsChanged)
        XCTAssertEqual(published?.count, 0)
        XCTAssertEqual(h.saveCount, 0)
        XCTAssertEqual(h.activeViewWrites, 0, "Opening a healthy wallet must not rewrite the entire encrypted mirror")
        // Compare decoded fields (JSON object order is deliberately unspecified).
        let diskAfter = try JSONDecoder().decode(SyncLedger.self, from: diskBefore)
        XCTAssertEqual(h.disk.records, diskAfter.records)
        XCTAssertEqual(h.disk.processedWebDAVSnapshotIDs, diskAfter.processedWebDAVSnapshotIDs)
        XCTAssertTrue(h.disk.pendingWebDAVUpload)
    }

    func testColdLockDoesNotReadOrSeedTheVault() async {
        let h = Harness()
        h.locked = true
        do { _ = try await h.coordinator.bootstrap(localCards: []); XCTFail("Expected read rejection") } catch { }
        let committed = try? await h.coordinator.commit(cards: [], deletedCardIDs: ["local"])
        let restored = try? await h.coordinator.restore(cards: [])
        XCTAssertNil(committed); XCTAssertNil(restored)
        XCTAssertEqual(h.loadCount, 0)
        XCTAssertEqual(h.saveCount, 0)
        XCTAssertEqual(h.configured, 0)
    }

    func testUnlockReloadsDiskIncludingTombstonesAndPendingUploadsBeforeSync() async throws {
        let h = Harness()
        _ = try await h.coordinator.bootstrap(localCards: [])
        h.lock()
        h.unlock()
        XCTAssertTrue(h.coordinator.currentCards.isEmpty)
        XCTAssertEqual(h.configured, 1, "Unlock alone must not start sync with an empty ledger")
        let restored = try await h.coordinator.bootstrap(localCards: [])
        XCTAssertEqual(restored.map(\.id), ["local"])
        XCTAssertEqual(h.loadCount, 2)
        XCTAssertEqual(h.configured, 2)
        let loaded = try h.retainedLedger()
        XCTAssertEqual(loaded.records, h.disk.records)
        XCTAssertEqual(loaded.lastWebDAVSnapshotFilename, "previous.json")
        XCTAssertEqual(loaded.processedWebDAVSnapshotIDs, ["acknowledged"])
        XCTAssertTrue(loaded.pendingWebDAVUpload)
    }

    func testOldBridgeCallbacksCannotRepopulateANewUnlockedSession() async throws {
        let h = Harness()
        _ = try await h.coordinator.bootstrap(localCards: [])
        let oldProvider = try XCTUnwrap(h.provider)
        let oldMerger = try XCTUnwrap(h.merger)
        let oldGeneration = h.coordinator.currentSessionGeneration
        h.lock()
        h.unlock()
        _ = try await h.coordinator.bootstrap(localCards: [])
        let remote = CardSyncRecord.legacyActive(SharedCard(id: "remote", country: "", bank: "Late", cardNumber: "late-result"))
        XCTAssertTrue(oldProvider().isEmpty)
        let oldApplied = await oldMerger([remote])
        XCTAssertFalse(oldApplied)
        XCTAssertFalse(h.coordinator.isCurrentSession(oldGeneration))
        XCTAssertEqual(h.saveCount, 0)
        XCTAssertEqual(h.coordinator.currentCards.map(\.id), ["local"])
        let currentMerger = try XCTUnwrap(h.merger)
        let currentApplied = await currentMerger([remote])
        XCTAssertTrue(currentApplied)
        XCTAssertEqual(Set(h.coordinator.currentCards.map(\.id)), ["local", "remote"])
    }

    func testReadFailureAfterUnlockCannotOverwriteTheDiskOrStartSync() async throws {
        let h = Harness()
        _ = try await h.coordinator.bootstrap(localCards: [])
        h.lock()
        h.failRead = true
        h.unlock()
        do { _ = try await h.coordinator.bootstrap(localCards: []); XCTFail("Expected read rejection") } catch { }
        XCTAssertTrue(h.coordinator.currentCards.isEmpty)
        XCTAssertTrue(try h.retainedLedger().records.isEmpty)
        XCTAssertEqual(h.saveCount, 0)
        XCTAssertEqual(h.activeViewWrites, 0, "Opening a healthy wallet must not rewrite the entire encrypted mirror")
        XCTAssertEqual(h.configured, 1)
        h.failRead = false
        let restored = try await h.coordinator.bootstrap(localCards: [])
        XCTAssertEqual(restored.map(\.id), ["local"])
    }

    func testRepeatedLockUnlockCyclesInvalidateEachPreviousGeneration() async throws {
        let h = Harness()
        for _ in 0..<5 {
            _ = try await h.coordinator.bootstrap(localCards: [])
            let generation = h.coordinator.currentSessionGeneration
            h.lock()
            h.lock() // Multiple windows/lifecycle notifications are harmless.
            XCTAssertTrue(try h.retainedLedger().records.isEmpty)
            h.unlock()
            XCTAssertFalse(h.coordinator.isCurrentSession(generation))
        }
        XCTAssertEqual(h.saveCount, 0)
        XCTAssertEqual(h.disk.records.count, 2)
    }

    func testBridgeHistoryIsLazyClearedInMemoryAndReloadedOnUnlock() async {
        var locked = true
        let reads = LockScopedValue(0)
        let history = SyncHistoryEntry(id: "history", startedAt: Date(), finishedAt: Date(),
            status: "success", message: "test", durationSeconds: 1, uploadedFile: nil,
            downloadedFiles: [], localChanges: [SyncCardChangeDetail(kind: "added", cardId: "local",
                cardName: "Private alias", fields: [])], remoteChanges: [])
        let bridge = WebDAVBridgeService(readLock: { locked }, readHistory: { reads.update { $0 += 1 }; return [history] }, bridgeEnabled: { false })
        XCTAssertEqual(reads.value, 0)
        bridge.configure(callbacks: WalletBridgeCallbacks(records: { [] }, merge: { _ in true }, ledger: { nil }, update: { _ in false }))
        await bridge.waitForHistory()
        XCTAssertEqual(reads.value, 0)
        locked = false
        bridge.configure(callbacks: WalletBridgeCallbacks(records: { [] }, merge: { _ in true }, ledger: { nil }, update: { _ in false }))
        await bridge.waitForHistory()
        XCTAssertEqual(bridge.syncHistory, [history])
        locked = true
        bridge.suspendForLock()
        XCTAssertTrue(bridge.syncHistory.isEmpty)
        XCTAssertEqual(bridge.syncProgress, SyncFileProgress())
        XCTAssertNil(bridge.lastConvergenceAt)
        locked = false
        bridge.configure(callbacks: WalletBridgeCallbacks(records: { [] }, merge: { _ in true }, ledger: { nil }, update: { _ in false }))
        await bridge.waitForHistory()
        XCTAssertEqual(reads.value, 2)
        XCTAssertEqual(bridge.syncHistory, [history])
    }

    func testRevocationReleasesThePayloadEvenWhenACallbackRetainsTheBox() {
        final class Payload { let sensitive = "synthetic secret" }
        var payload: Payload? = Payload()
        weak var released = payload
        let box = LockScopedValue(payload!)
        let callback = { box.value }
        payload = nil
        XCTAssertNotNil(released)
        box.invalidate()
        XCTAssertNil(released)
        XCTAssertNil(callback())
    }

    func testRevokedBufferRejectsLateDownloadAppends() {
        let box = LockScopedValue(["first"])
        box.invalidate()
        box.update { $0.append("late") }
        XCTAssertNil(box.value)
    }

    @MainActor
    func testImageCacheDropsDecodedImagesAndRefusesLockedReads() async throws {
        var locked = false
        let cache = CardImageCache(readLock: { locked })
        let url = try XCTUnwrap(Bundle.main.url(forResource: "AppIcon", withExtension: "png"))
        let asset = CardImageAsset(data: try Data(contentsOf: url).base64EncodedString(), name: "synthetic")
        var first = await cache.image(for: asset, pixels: 100)
        XCTAssertNotNil(first)
        weak var released = first
        first = nil
        XCTAssertNotNil(released, "The cache initially owns the image")
        locked = true
        cache.suspendForLock()
        XCTAssertNil(released, "Lock must remove the cache's strong reference")
        let lockedImage = await cache.image(for: asset, pixels: 100)
        XCTAssertNil(lockedImage)
        locked = false
        let reloaded = await cache.image(for: asset, pixels: 100)
        XCTAssertNotNil(reloaded)
    }

    @MainActor
    func testLockDuringImageDecodeCannotRefillTheCache() async throws {
        let started = expectation(description: "decoder started")
        let gate = DispatchSemaphore(value: 0)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "AppIcon", withExtension: "png"))
        let asset = CardImageAsset(data: try Data(contentsOf: url).base64EncodedString(), name: "synthetic")
        let decoded = try XCTUnwrap(CardImageCache.decodeThumbnail(asset.data, pixels: 200))
        let cache = CardImageCache(readLock: { false }, decode: { _, _ in
            started.fulfill()
            _ = gate.wait(timeout: .now() + 5)
            // Simulate a system decoder that returns a valid image even after cancellation.
            return decoded
        })
        let task = Task { @MainActor in await cache.image(for: asset, pixels: 200) != nil }
        await fulfillment(of: [started], timeout: 3)
        cache.suspendForLock()
        gate.signal()
        let returnedAnImage = await task.value
        XCTAssertFalse(returnedAnImage)
    }
}
