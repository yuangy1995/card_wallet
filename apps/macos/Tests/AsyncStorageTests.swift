import XCTest
@testable import CreditCardMac

@MainActor
final class AsyncStorageTests: XCTestCase {
    private final class Disk: @unchecked Sendable {
        private let lock = NSLock()
        private var stored = SyncLedger(records: [.legacyActive(SharedCard(id: "one", country: "CN", bank: "Test", cardNumber: "4111111111111111"))])
        private var _locked = false
        private var _failSave = false
        private var _writes = 0
        private var readHook: (@Sendable () -> Void)?
        private var saveHook: (@Sendable () -> Void)?
        var beforeRead: (@Sendable () -> Void)? { get { lock.withLock { readHook } } set { lock.withLock { readHook = newValue } } }
        var beforeSave: (@Sendable () -> Void)? { get { lock.withLock { saveHook } } set { lock.withLock { saveHook = newValue } } }
        var locked: Bool { get { lock.withLock { _locked } } set { lock.withLock { _locked = newValue } } }
        var failSave: Bool { get { lock.withLock { _failSave } } set { lock.withLock { _failSave = newValue } } }
        var ledger: SyncLedger { lock.withLock { stored } }
        var writes: Int { lock.withLock { _writes } }
        func read() -> Result<[SharedCard], Error> {
            XCTAssertFalse(Thread.isMainThread)
            let hook = lock.withLock { let value = readHook; readHook = nil; return value }
            hook?()
            return lock.withLock { .success(CardSyncMergeEngine.activeCards(from: stored.records)) }
        }
        func save(_ value: SyncLedger) -> Bool {
            XCTAssertFalse(Thread.isMainThread)
            let hook = lock.withLock { let value = saveHook; saveHook = nil; return value }
            hook?()
            return lock.withLock {
                guard !_failSave else { return false }
                stored = value; _writes += 1; return true
            }
        }
    }
    private func make(_ disk: Disk, existing: @escaping @Sendable () throws -> SyncLedger? = { nil }, mirror: @escaping @Sendable ([SharedCard]) -> Bool = { _ in true }, configure: @escaping (WalletBridgeCallbacks) -> Void = { _ in }) -> SyncCoordinator {
        SyncCoordinator(readLock: { disk.locked }, readCards: { disk.read() }, loadExistingLedger: existing,
                        loadLedger: { _ in XCTAssertFalse(Thread.isMainThread); return disk.ledger },
                        saveLedger: { disk.save($0) },
                        persistCards: { cards in XCTAssertFalse(Thread.isMainThread); return mirror(cards) },
                        configureBridge: configure, suspendBridge: { _ in })
    }
    func testSlowReadDoesNotBlockMainAndDoesNotExposeAnEmptyReadyWallet() async throws {
        let disk = Disk(), entered = expectation(description: "disk read")
        let finish = DispatchSemaphore(value: 0)
        disk.beforeRead = { entered.fulfill(); _ = finish.wait(timeout: .now() + 5) }
        let sut = make(disk)
        let load = Task { try await sut.bootstrap() }
        await fulfillment(of: [entered], timeout: 3)
        XCTAssertFalse(sut.isCurrentSession(sut.currentSessionGeneration))
        XCTAssertTrue(sut.currentCards.isEmpty)
        finish.signal()
        let cards = try await load.value
        XCTAssertEqual(cards.map(\.id), ["one"])
        XCTAssertEqual(disk.writes, 0)
    }
    func testSaveFailureDoesNotPublishCandidateOrCallTheObserver() async throws {
        let disk = Disk()
        let wallet = make(disk); _ = try await wallet.bootstrap()
        var publications = 0
        wallet.onCardsChanged = { _ in publications += 1 }
        disk.failSave = true
        do {
            _ = try await wallet.mutateCards { current in var value = current; value[0].alias = "unsaved"; return value }
            XCTFail("Write must fail")
        } catch { }
        XCTAssertNil(wallet.currentCards.first?.alias)
        XCTAssertNil(disk.ledger.records.first?.card?.alias)
        XCTAssertEqual(publications, 0)
    }
    func testConcurrentEditsAreSerializedAgainstLatestCommittedCards() async throws {
        let disk = Disk(); let sut = make(disk); _ = try await sut.bootstrap()
        let first = Task { try await sut.mutateCards { current in var value = current; value[0].alias = "alias"; return value } }
        let second = Task { try await sut.mutateCards { current in var value = current; value[0].remark = "remark"; return value } }
        _ = try await first.value; _ = try await second.value
        XCTAssertEqual(sut.currentCards.first?.alias, "alias")
        XCTAssertEqual(sut.currentCards.first?.remark, "remark")
        XCTAssertEqual(disk.writes, 2)
    }
    func testBridgeAcknowledgementCannotOverwriteAConcurrentEdit() async throws {
        let disk = Disk(); var hooks: WalletBridgeCallbacks?
        let sut = make(disk) { hooks = $0 }; _ = try await sut.bootstrap()
        let callback = try XCTUnwrap(hooks)
        let entered = expectation(description: "save entered"), finish = DispatchSemaphore(value: 0)
        disk.beforeSave = { entered.fulfill(); _ = finish.wait(timeout: .now() + 5) }
        let edit = Task { try await sut.mutateCards { current in var value = current; value[0].alias = "new"; return value } }
        await fulfillment(of: [entered], timeout: 3)
        let ack = Task { await callback.update { $0.lastWebDAVSnapshotFilename = "ack.json" } }
        finish.signal(); _ = try await edit.value
        let acknowledged = await ack.value
        XCTAssertTrue(acknowledged)
        XCTAssertEqual(disk.ledger.records.first?.card?.alias, "new")
        XCTAssertEqual(disk.ledger.lastWebDAVSnapshotFilename, "ack.json")
        XCTAssertTrue(disk.ledger.pendingWebDAVUpload)
    }
    func testOldMetadataCallbackCannotWriteAfterAnotherUnlock() async throws {
        let disk = Disk(); var hooks: WalletBridgeCallbacks?
        let sut = make(disk) { hooks = $0 }; _ = try await sut.bootstrap()
        let old = try XCTUnwrap(hooks)
        sut.setSuspended(isLocked: true); sut.setSuspended(isLocked: false)
        _ = try await sut.bootstrap()
        let accepted = await old.update { $0.pendingWebDAVUpload = false; $0.lastWebDAVSnapshotFilename = "late.json" }
        XCTAssertFalse(accepted)
        XCTAssertNil(disk.ledger.lastWebDAVSnapshotFilename)
        XCTAssertEqual(disk.writes, 0)
    }
    func testLockDuringAcceptedWriteDoesNotPublishButNextUnlockSeesIt() async throws {
        let disk = Disk(); let sut = make(disk); _ = try await sut.bootstrap()
        let entered = expectation(description: "save entered"), finish = DispatchSemaphore(value: 0)
        disk.beforeSave = { entered.fulfill(); _ = finish.wait(timeout: .now() + 5) }
        let edit = Task { try await sut.mutateCards { current in var value = current; value[0].alias = "durable"; return value } }
        await fulfillment(of: [entered], timeout: 3)
        disk.locked = true; sut.setSuspended(isLocked: true)
        XCTAssertTrue(sut.currentCards.isEmpty)
        disk.locked = false; sut.setSuspended(isLocked: false)
        let reload = Task { try await sut.bootstrap() }
        finish.signal()
        do { _ = try await edit.value; XCTFail("Old session cannot receive completion") } catch is CancellationError { }
        let restored = try await reload.value
        XCTAssertEqual(restored.first?.alias, "durable")
        XCTAssertEqual(disk.writes, 1)
    }
    func testLockDuringReadDropsOldResultAndAllowsRetry() async throws {
        let disk = Disk(), entered = expectation(description: "read entered"), finish = DispatchSemaphore(value: 0)
        disk.beforeRead = { entered.fulfill(); _ = finish.wait(timeout: .now() + 5) }
        let sut = make(disk); let old = Task { try await sut.bootstrap() }
        await fulfillment(of: [entered], timeout: 3)
        sut.setSuspended(isLocked: true); sut.setSuspended(isLocked: false)
        finish.signal()
        do { _ = try await old.value; XCTFail("Old read must be rejected") } catch is CancellationError { }
        let cards = try await sut.bootstrap()
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(disk.writes, 0)
    }

    func testExistingLedgerSkipsRedundantMirrorAndStartupWrite() async throws {
        let disk = Disk()
        disk.beforeRead = { XCTFail("Do not decrypt a redundant card mirror") }
        let sut = make(disk, existing: { XCTAssertFalse(Thread.isMainThread); return disk.ledger })
        let cards = try await sut.bootstrap()
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(disk.writes, 0)
    }
    func testCorruptLedgerDoesNotReseedFromStaleMirror() async {
        let disk = Disk()
        disk.beforeRead = { XCTFail("A corrupt ledger must not fall back to the mirror") }
        let sut = make(disk, existing: { throw CocoaError(.fileReadCorruptFile) })
        do { _ = try await sut.bootstrap(); XCTFail("Expected ledger read failure") } catch { }
        XCTAssertTrue(sut.currentCards.isEmpty)
        XCTAssertEqual(disk.writes, 0)
    }
    func testMirrorFailurePreservesAuthoritativeWriteAndReload() async throws {
        let disk = Disk()
        let sut = make(disk, existing: { disk.ledger }, mirror: { _ in false })
        _ = try await sut.bootstrap()
        _ = try await sut.mutateCards { cards in var value = cards; value[0].alias = "committed"; return value }
        XCTAssertEqual(sut.currentCards.first?.alias, "committed")
        XCTAssertEqual(sut.pendingStatus, "卡片已保存，部分本地信息未能更新")
        sut.setSuspended(isLocked: true); sut.setSuspended(isLocked: false)
        let restored = try await sut.bootstrap()
        XCTAssertEqual(restored.first?.alias, "committed")
    }
}
