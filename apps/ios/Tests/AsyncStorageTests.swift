import XCTest
@testable import CreditCardIOS

@MainActor
final class AsyncStorageTests: XCTestCase {
    private final class Disk: @unchecked Sendable {
        private let lock = NSLock()
        private var _ledger = SyncLedger(records: [CardSyncRecord.activeUsingCardTimestamp(
            SharedCard(id: "one", country: "CN", bank: "Test", cardNumber: "4111111111111111"))])
        private var _locked = true
        private var _failSave = false
        private var _readCount = 0
        private var _writeCount = 0
        private var readHook: (@Sendable () -> Void)?
        private var saveHook: (@Sendable () -> Void)?
        private var historyHook: (@Sendable () -> Void)?
        var beforeRead: (@Sendable () -> Void)? { get { lock.withLock { readHook } } set { lock.withLock { readHook = newValue } } }
        var beforeSave: (@Sendable () -> Void)? { get { lock.withLock { saveHook } } set { lock.withLock { saveHook = newValue } } }
        var beforeHistory: (@Sendable () -> Void)? { get { lock.withLock { historyHook } } set { lock.withLock { historyHook = newValue } } }
        var locked: Bool { get { lock.withLock { _locked } } set { lock.withLock { _locked = newValue } } }
        var failSave: Bool { get { lock.withLock { _failSave } } set { lock.withLock { _failSave = newValue } } }
        var ledger: SyncLedger { lock.withLock { _ledger } }
        var readCount: Int { lock.withLock { _readCount } }
        var writeCount: Int { lock.withLock { _writeCount } }
        func read() -> Result<[SharedCard], Error> {
            XCTAssertFalse(Thread.isMainThread, "Reading/decryption must run off the UI thread")
            let hook = lock.withLock { let value = readHook; readHook = nil; return value }
            hook?()
            return lock.withLock { _readCount += 1; return .success(CardSyncMergeEngine.activeCards(from: _ledger.records)) }
        }
        func write(_ value: SyncLedger) -> Bool {
            XCTAssertFalse(Thread.isMainThread, "Encryption/durable save must run off the UI thread")
            let hook = lock.withLock { let value = saveHook; saveHook = nil; return value }
            hook?()
            return lock.withLock {
                guard !_failSave else { return false }
                _ledger = value; _writeCount += 1
                return true
            }
        }
    }
    private func make(_ disk: Disk, existing: @escaping @Sendable () throws -> SyncLedger? = { nil }, mirror: @escaping @Sendable ([SharedCard]) -> Bool = { _ in true }) -> SyncCoordinator {
        SyncCoordinator(readLock: { disk.locked }, readCards: { disk.read() }, loadExistingLedger: existing,
                        readLedger: { _ in disk.ledger }, saveLedger: { disk.write($0) },
                        persistCards: { cards in XCTAssertFalse(Thread.isMainThread); return mirror(cards) },
                        readHistory: { disk.beforeHistory?(); return [] }, writeHistory: { _ in },
                        configurationReady: { false }, suspendClient: { _ in },
                        defaults: UserDefaults(suiteName: "async-store-" + UUID().uuidString)!)
    }
    func testBlockedReadDoesNotBlockMainActorAndNeverShowsEmptyReady() async {
        let disk = Disk(); let entered = expectation(description: "read entered")
        let finish = DispatchSemaphore(value: 0)
        disk.beforeRead = { entered.fulfill(); _ = finish.wait(timeout: .now() + 5) }
        let sut = make(disk); disk.locked = false; sut.setSuspended(isLocked: false)
        await fulfillment(of: [entered], timeout: 3)
        XCTAssertEqual(sut.localLoadState, .loading)
        XCTAssertTrue(sut.cards.isEmpty)
        // Reaching here while the disk closure is blocked proves MainActor is responsive.
        finish.signal(); await sut.waitForLocalData()
        XCTAssertEqual(sut.localLoadState, .ready)
        XCTAssertEqual(sut.cards.count, 1)
    }
    func testHistoryCanBeSlowWithoutHoldingBackLocalCards() async {
        let disk = Disk(); let entered = expectation(description: "history entered")
        let finish = DispatchSemaphore(value: 0)
        disk.beforeHistory = { entered.fulfill(); _ = finish.wait(timeout: .now() + 5) }
        let sut = make(disk); disk.locked = false; sut.setSuspended(isLocked: false)
        await fulfillment(of: [entered], timeout: 3)
        XCTAssertEqual(sut.localLoadState, .ready)
        XCTAssertEqual(sut.cards.count, 1)
        finish.signal(); await sut.waitForLocalData()
    }
    func testCandidateNotPublishedUntilDurableSaveAndFailureKeepsOriginal() async throws {
        let disk = Disk(); let sut = make(disk)
        disk.locked = false; sut.setSuspended(isLocked: false); await sut.waitForLocalData()
        let entered = expectation(description: "save entered"), finish = DispatchSemaphore(value: 0)
        disk.beforeSave = { entered.fulfill(); _ = finish.wait(timeout: .now() + 5) }
        disk.failSave = true
        let task = Task { try await sut.mutateCards { cards in var result = cards; result[0].alias = "new"; return result } }
        await fulfillment(of: [entered], timeout: 3)
        XCTAssertNil(sut.cards[0].alias)
        finish.signal()
        do { _ = try await task.value; XCTFail("Expected a write failure") } catch { }
        XCTAssertNil(sut.cards[0].alias)
        XCTAssertNil(disk.ledger.records.first?.card?.alias)
        XCTAssertEqual(disk.writeCount, 0)
    }
    func testQueuedMutationsUseLatestCommittedCardsWithoutLostUpdates() async throws {
        let disk = Disk(); let sut = make(disk)
        disk.locked = false; sut.setSuspended(isLocked: false); await sut.waitForLocalData()
        let first = Task { try await sut.mutateCards { cards in var value = cards; value[0].alias = "first"; return value } }
        let second = Task { try await sut.mutateCards { cards in var value = cards; value[0].remark = "second"; return value } }
        _ = try await first.value; _ = try await second.value
        XCTAssertEqual(sut.cards[0].alias, "first")
        XCTAssertEqual(sut.cards[0].remark, "second")
        XCTAssertEqual(disk.writeCount, 2)
        sut.setSuspended(isLocked: true); sut.setSuspended(isLocked: false); await sut.waitForLocalData()
        XCTAssertEqual(sut.cards[0].alias, "first")
        XCTAssertEqual(sut.cards[0].remark, "second")
    }
    func testLockDuringReadRejectsResultAndNewUnlockDoesNotRaceOldRead() async {
        let disk = Disk(); let entered = expectation(description: "read entered")
        let finish = DispatchSemaphore(value: 0)
        disk.beforeRead = { entered.fulfill(); _ = finish.wait(timeout: .now() + 5) }
        let sut = make(disk); disk.locked = false; sut.setSuspended(isLocked: false)
        await fulfillment(of: [entered], timeout: 3)
        let old = sut.currentSession
        disk.locked = true; sut.setSuspended(isLocked: true)
        XCTAssertEqual(sut.localLoadState, .locked)
        finish.signal()
        disk.locked = false; sut.setSuspended(isLocked: false); await sut.waitForLocalData()
        XCTAssertFalse(old.isValid)
        XCTAssertEqual(sut.localLoadState, .ready)
        XCTAssertEqual(sut.cards.count, 1)
        XCTAssertEqual(disk.writeCount, 0)
    }
    func testAcceptedWriteCompletesBeforeNewSessionReadButDoesNotRepopulateLockedUI() async throws {
        let disk = Disk(); let sut = make(disk)
        disk.locked = false; sut.setSuspended(isLocked: false); await sut.waitForLocalData()
        let entered = expectation(description: "save entered"), finish = DispatchSemaphore(value: 0)
        disk.beforeSave = { entered.fulfill(); _ = finish.wait(timeout: .now() + 5) }
        let save = Task { try await sut.mutateCards { cards in var result = cards; result[0].alias = "durable"; return result } }
        await fulfillment(of: [entered], timeout: 3)
        disk.locked = true; sut.setSuspended(isLocked: true)
        disk.locked = false; sut.setSuspended(isLocked: false)
        XCTAssertEqual(sut.localLoadState, .loading)
        finish.signal()
        do { _ = try await save.value; XCTFail("Old UI session must not receive success") } catch is CancellationError { }
        await sut.waitForLocalData()
        XCTAssertEqual(sut.cards.first?.alias, "durable")
        XCTAssertEqual(disk.writeCount, 1)
    }

    func testAuthoritativeLedgerSkipsOldMirrorAndDoesNotRewriteOnOpen() async {
        let disk = Disk()
        let sut = make(disk, existing: { XCTAssertFalse(Thread.isMainThread); return disk.ledger })
        disk.beforeRead = { XCTFail("Healthy ledger must not require redundant card-file decryption") }
        disk.locked = false; sut.setSuspended(isLocked: false); await sut.waitForLocalData()
        XCTAssertEqual(sut.cards.count, 1)
        XCTAssertEqual(disk.readCount, 0)
        XCTAssertEqual(disk.writeCount, 0)
    }
    func testCorruptAuthoritativeLedgerNeverFallsBackToOldMirror() async {
        let disk = Disk()
        let sut = make(disk, existing: { throw CocoaError(.fileReadCorruptFile) })
        disk.beforeRead = { XCTFail("A corrupt ledger cannot be replaced by a stale mirror") }
        disk.locked = false; sut.setSuspended(isLocked: false); await sut.waitForLocalData()
        XCTAssertEqual(sut.localLoadState, .error)
        XCTAssertTrue(sut.cards.isEmpty)
        XCTAssertEqual(disk.writeCount, 0)
    }
    func testMirrorFailureKeepsDurableLedgerAndOfflineReload() async throws {
        let disk = Disk()
        let sut = make(disk, existing: { disk.ledger }, mirror: { _ in false })
        disk.locked = false; sut.setSuspended(isLocked: false); await sut.waitForLocalData()
        _ = try await sut.mutateCards { cards in var value = cards; value[0].alias = "committed"; return value }
        XCTAssertEqual(sut.cards.first?.alias, "committed")
        XCTAssertEqual(sut.syncStatus, .warning("卡片已保存，部分本地信息未能更新"))
        sut.setSuspended(isLocked: true); sut.setSuspended(isLocked: false); await sut.waitForLocalData()
        XCTAssertEqual(sut.cards.first?.alias, "committed")
    }
}
