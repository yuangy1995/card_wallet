import XCTest
@testable import CreditCardIOS

@MainActor
final class LockSessionTests: XCTestCase {
    private final class Store {
        var locked = true
        var reads = 0
        var saves = 0
        var failRead = false
        var failLedger = false
        var failHistory = false
        var source: [SharedCard] = [SharedCard(id: "one", country: "CN", bank: "Test", cardNumber: "4111111111111111")]
        var disk = SyncLedger()
        var history: [SyncHistoryEntry] = []
    }
    private func make(_ store: Store) -> SyncCoordinator {
        let defaults = UserDefaults(suiteName: "lock-session-" + UUID().uuidString)!
        return SyncCoordinator(
            readLock: { store.locked },
            readCards: {
                store.reads += 1
                return store.failRead ? .failure(CocoaError(.fileReadCorruptFile)) : .success(store.source)
            },
            readLedger: { cards in
                if store.failLedger { throw CocoaError(.fileReadCorruptFile) }
                return store.disk.records.isEmpty ? SyncLedger(records: cards.map(CardSyncRecord.activeUsingCardTimestamp)) : store.disk
            },
            saveLedger: { store.saves += 1; store.disk = $0; return true },
            persistCards: { store.source = $0 },
            readHistory: {
                if store.failHistory { throw CocoaError(.fileReadCorruptFile) }
                return store.history
            },
            writeHistory: { store.history = $0 },
            configurationReady: { false }, suspendClient: { _ in }, defaults: defaults
        )
    }
    func testColdLockedStartDoesNotReadOrWrite() {
        let store = Store(); let sut = make(store)
        sut.bootstrap(); sut.setSuspended(isLocked: true)
        XCTAssertEqual(store.reads, 0)
        XCTAssertEqual(sut.localLoadState, .locked)
        XCTAssertTrue(sut.cards.isEmpty)
        XCTAssertEqual(sut.retainedRecordCount, 0)
    }
    func testLockReleasesLedgerHistoryAndCardsWithoutSavingAnEmptyWallet() {
        let store = Store(); let sut = make(store)
        store.locked = false; sut.setSuspended(isLocked: false)
        XCTAssertEqual(sut.cards.count, 1)
        _ = sut.commit(cards: sut.cards, deletedCardIDs: [])
        let saved = store.saves
        store.locked = true; sut.setSuspended(isLocked: true)
        XCTAssertEqual(sut.localLoadState, .locked)
        XCTAssertTrue(sut.cards.isEmpty && sut.syncHistory.isEmpty)
        XCTAssertEqual(sut.retainedRecordCount, 0)
        XCTAssertEqual(store.saves, saved)
        XCTAssertEqual(store.source.count, 1)
    }
    func testUnlockRestoresTombstonesAndPendingStateOffline() {
        let store = Store()
        store.disk = SyncLedger(records: [CardSyncRecord.activeUsingCardTimestamp(store.source[0]),
                                        .deleted(cardId: "deleted", changedAt: "2026-09-19T00:00:00Z")])
        store.disk.pendingWebDAVUpload = true
        let sut = make(store)
        store.locked = false; sut.setSuspended(isLocked: false)
        XCTAssertEqual(sut.localLoadState, .ready)
        XCTAssertEqual(sut.cards.count, 1)
        XCTAssertEqual(sut.retainedRecordCount, 2)
        XCTAssertTrue(sut.retainedPendingUpload)
        store.locked = true; sut.setSuspended(isLocked: true)
        store.locked = false; sut.setSuspended(isLocked: false)
        XCTAssertEqual(sut.retainedRecordCount, 2)
        XCTAssertTrue(sut.retainedPendingUpload)
    }
    func testPreviousSessionRemainsInvalidAfterUnlock() async {
        let store = Store(); let sut = make(store)
        store.locked = false; sut.setSuspended(isLocked: false)
        let token = sut.currentSession
        store.locked = true; sut.setSuspended(isLocked: true)
        store.locked = false; sut.setSuspended(isLocked: false)
        XCTAssertFalse(sut.accepts(token))
        XCTAssertThrowsError(try token.check())
        let writes = store.saves
        await WalletSession.$current.withValue(token) { await sut.synchronize(forceUpload: true) }
        XCTAssertEqual(store.saves, writes)
        XCTAssertEqual(sut.localLoadState, .ready)
    }
    func testReadFailureIsNotAnEmptyWalletAndCanRetry() {
        let store = Store(); let sut = make(store)
        store.failRead = true; store.locked = false; sut.setSuspended(isLocked: false)
        XCTAssertEqual(sut.localLoadState, .error)
        XCTAssertEqual(store.saves, 0)
        XCTAssertEqual(store.source.count, 1)
        store.failRead = false; sut.bootstrap()
        XCTAssertEqual(sut.localLoadState, .ready)
        XCTAssertEqual(sut.cards.count, 1)
    }
    func testBrokenLedgerDoesNotPublishSeedCardsOrOverwriteDisk() {
        let store = Store(); store.failLedger = true
        let sut = make(store)
        store.locked = false; sut.setSuspended(isLocked: false)
        XCTAssertEqual(sut.localLoadState, .error)
        XCTAssertTrue(sut.cards.isEmpty)
        XCTAssertEqual(store.saves, 0)
    }
    func testOptionalHistoryFailureDoesNotHideHealthyCards() {
        let store = Store(); store.failHistory = true
        let sut = make(store)
        store.locked = false; sut.setSuspended(isLocked: false)
        XCTAssertEqual(sut.localLoadState, .ready)
        XCTAssertEqual(sut.cards.count, 1)
    }
    func testActualEmptyWalletIsReadyAndRepeatedResumeDoesNotReload() {
        let store = Store(); store.source = []
        let sut = make(store)
        store.locked = false; sut.setSuspended(isLocked: false)
        sut.setSuspended(isLocked: false)
        XCTAssertEqual(sut.localLoadState, .ready)
        XCTAssertTrue(sut.cards.isEmpty)
        XCTAssertEqual(store.reads, 1)
    }
    func testEditsWhileLockedCannotCreateTombstones() {
        let store = Store(); let sut = make(store)
        _ = sut.commit(cards: [], deletedCardIDs: ["one"])
        _ = sut.restore(cards: [])
        XCTAssertEqual(store.saves, 0)
        XCTAssertEqual(store.source.count, 1)
    }
}
