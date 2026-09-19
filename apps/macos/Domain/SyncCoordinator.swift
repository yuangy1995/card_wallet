import Foundation
import SwiftUI

@MainActor
public final class SyncCoordinator: ObservableObject {
    public static let shared = SyncCoordinator()
    @Published public private(set) var pendingStatus = "同步尚未准备好"
    @Published public private(set) var lastConvergenceAt: Date?

    private var ledger = SyncLedger()
    private var cachedCards: [SharedCard] = []
    private var hasBootstrapped = false
    public var onCardsChanged: (([SharedCard]) -> Void)?
    private var pendingWebDAVUploadWorkItem: DispatchWorkItem?
    private let webDAVUploadDebounceInterval: TimeInterval = 0.8
    private let storage = WalletStorageExecutor()
    private let mutations = WalletMutationGate()
    private var suspended = false
    private var sessionGeneration: UInt64 = 0
    private var sessionAccess = LockScopedValue(true)
    private let readLock: @MainActor () -> Bool
    private let loadExistingLedger: @Sendable () throws -> SyncLedger?
    private let readCards: @Sendable () -> Result<[SharedCard], Error>
    private let loadLedger: @Sendable ([SharedCard]) throws -> SyncLedger
    private let saveLedger: @Sendable (SyncLedger) -> Bool
    private let persistCards: @Sendable ([SharedCard]) -> Bool
    private let configureBridge: (WalletBridgeCallbacks) -> Void
    private let suspendBridge: (Bool) -> Void

    private convenience init() {
        self.init(
            readLock: { AutoLockManager.shared.isLocked },
            readCards: { LocalStorageManager.read() },
            loadExistingLedger: { try SyncLedgerStore.shared.loadExisting() },
            loadLedger: { try SyncLedgerStore.shared.load(seeding: $0) },
            saveLedger: { SyncLedgerStore.shared.save($0) },
            persistCards: { LocalStorageManager.write(cards: $0) },
            configureBridge: { WebDAVBridgeService.shared.configure(callbacks: $0) },
            suspendBridge: { locked in
                WebDAVClient.shared.setSuspended(locked)
                if locked {
                    WebDAVBridgeService.shared.suspendForLock()
                    KeychainManager.clearTransientReads()
                    CardImageCache.shared.suspendForLock()
                    CardSystemNotificationCenter.shared.suspendForLock()
                }
            }
        )
    }

    // Storage seams are synchronous only INSIDE the serial off-main executor.
    init(readLock: @escaping @MainActor () -> Bool,
         readCards: @escaping @Sendable () -> Result<[SharedCard], Error> = { .success([]) },
         loadExistingLedger: @escaping @Sendable () throws -> SyncLedger? = { nil },
         loadLedger: @escaping @Sendable ([SharedCard]) throws -> SyncLedger,
         saveLedger: @escaping @Sendable (SyncLedger) -> Bool,
         persistCards: @escaping @Sendable ([SharedCard]) -> Bool,
         configureBridge: @escaping (WalletBridgeCallbacks) -> Void,
         suspendBridge: @escaping (Bool) -> Void) {
        self.readLock = readLock
        self.loadExistingLedger = loadExistingLedger
        self.readCards = readCards
        self.loadLedger = loadLedger
        self.saveLedger = saveLedger
        self.persistCards = persistCards
        self.configureBridge = configureBridge
        self.suspendBridge = suspendBridge
    }

    private var canAccessCards: Bool { !suspended && !readLock() }
    private func accepts(_ generation: UInt64) -> Bool { canAccessCards && sessionGeneration == generation }
    func isCurrentSession(_ generation: UInt64) -> Bool { accepts(generation) && hasBootstrapped }
    var currentSessionGeneration: UInt64 { sessionGeneration }
    public var currentCards: [SharedCard] { isCurrentSession(sessionGeneration) ? cachedCards : [] }

    public func bootstrap(localCards: [SharedCard]? = nil) async throws -> [SharedCard] {
        let generation = sessionGeneration
        await mutations.acquire()
        defer { mutations.release() }
        guard accepts(generation), !Task.isCancelled else { throw CancellationError() }
        guard !hasBootstrapped else { return currentCards }
        let access = sessionAccess, reader = readCards, loader = loadLedger, saver = saveLedger, existingReader = loadExistingLedger
        let loaded = try await storage.perform {
            guard access.value != nil else { throw CancellationError() }
            var candidate: SyncLedger
            if localCards == nil, let existing = try existingReader() {
                candidate = existing
            } else {
                let seed: [SharedCard]
                if let localCards { seed = localCards } else { seed = try reader().get() }
                guard access.value != nil else { throw CancellationError() }
                candidate = try loader(seed)
                guard access.value != nil else { throw CancellationError() }
                if candidate.records.isEmpty && !seed.isEmpty {
                    candidate.records = seed.map(CardSyncRecord.legacyActive)
                    guard saver(candidate) else { throw CocoaError(.fileWriteUnknown) }
                }
            }
            let active = CardSyncMergeEngine.activeCards(from: candidate.records)
            return (candidate, active)
        }
        guard accepts(generation), !Task.isCancelled else { throw CancellationError() }
        ledger = loaded.0
        cachedCards = loaded.1
        hasBootstrapped = true
        LocalCardPreferences.retain(Set(cachedCards.map(\.id)))
        configureBridge(WalletBridgeCallbacks(
            records: { [weak self] in
                guard let self, self.isCurrentSession(generation) else { return [] }; return self.ledger.records
            },
            merge: { [weak self] records in await self?.mergeRemote(records, generation: generation) ?? false },
            ledger: { [weak self] in
                guard let self, self.isCurrentSession(generation) else { return nil }; return self.ledger
            },
            update: { [weak self] change in await self?.updateMetadata(change, generation: generation) ?? false }
        ))
        pendingStatus = "同步准备完成"
        return currentCards
    }

    @discardableResult
    public func mutateCards(deletedCardIDs: Set<String> = [],
                            _ transform: @escaping @MainActor ([SharedCard]) -> [SharedCard]) async throws -> [SharedCard] {
        let generation = sessionGeneration
        await mutations.acquire()
        defer { mutations.release() }
        guard isCurrentSession(generation), !Task.isCancelled else { throw CancellationError() }
        let updated = transform(currentCards), current = ledger, access = sessionAccess
        let candidate = try await storage.perform { () -> SyncLedger? in
            guard access.value != nil else { throw CancellationError() }
            let normalized = updated.map(Self.normalizedCard)
            let existingByID = Self.latestRecordsByID(current.records)
            var events: [CardSyncRecord] = []
            let inputIDs = Set(normalized.map(\.id))
            for card in normalized {
                if let existing = existingByID[card.id], existing.state == .active, existing.card == card { continue }
                events.append(.active(card, changedAt: CardSyncRecord.nextTimestamp(after: existingByID[card.id])))
            }
            for id in deletedCardIDs where !inputIDs.contains(id) {
                events.append(.deleted(cardId: id, changedAt: CardSyncRecord.nextTimestamp(after: existingByID[id])))
            }
            guard !events.isEmpty else { return nil }
            var candidate = current
            candidate.records = CardSyncMergeEngine.merge([current.records, events])
            candidate.pendingWebDAVUpload = true
            return candidate
        }
        guard isCurrentSession(generation) else { throw CancellationError() }
        guard let candidate else { return currentCards }
        let mirrored = try await persistCandidate(candidate, generation: generation)
        pendingStatus = mirrored ? "正在同步最新修改" : "卡片已保存，部分本地信息未能更新"
        scheduleWebDAVUpload()
        return currentCards
    }

    /// One-click actions report errors without optimistically removing cards from the visible wallet.
    public func enqueueEdit(deletedCardIDs: Set<String> = [],
                            _ transform: @escaping @MainActor ([SharedCard]) -> [SharedCard]) {
        let generation = sessionGeneration
        guard isCurrentSession(generation) else { return }
        Task { [weak self] in
            guard let self, self.isCurrentSession(generation) else { return }
            do { _ = try await self.mutateCards(deletedCardIDs: deletedCardIDs, transform) }
            catch is CancellationError { }
            catch {
                if self.isCurrentSession(generation) { self.pendingStatus = "未能保存卡片，请重试；已有数据没有被更改" }
            }
        }
    }

    @discardableResult
    public func commit(cards: [SharedCard], deletedCardIDs: Set<String> = []) async throws -> [SharedCard] {
        try await mutateCards(deletedCardIDs: deletedCardIDs) { _ in cards }
    }

    @discardableResult
    public func restore(cards: [SharedCard]) async throws -> [SharedCard] {
        let generation = sessionGeneration
        await mutations.acquire()
        defer { mutations.release() }
        guard isCurrentSession(generation), !Task.isCancelled else { throw CancellationError() }
        let current = ledger, access = sessionAccess
        let candidate = try await storage.perform {
            guard access.value != nil else { throw CancellationError() }
            let normalized = cards.map(Self.normalizedCard)
            let restoredIDs = Set(normalized.map(\.id))
            let existingByID = Self.latestRecordsByID(current.records)
            let removed = Set(current.records.filter { $0.state == .active }.map(\.cardId)).subtracting(restoredIDs)
            var events = normalized.map { CardSyncRecord.active($0, changedAt: CardSyncRecord.nextTimestamp(after: existingByID[$0.id])) }
            events += removed.map { CardSyncRecord.deleted(cardId: $0, changedAt: CardSyncRecord.nextTimestamp(after: existingByID[$0])) }
            var candidate = current
            candidate.records = CardSyncMergeEngine.merge([current.records, events])
            candidate.pendingWebDAVUpload = true
            return candidate
        }
        _ = try await persistCandidate(candidate, generation: generation)
        scheduleWebDAVUpload()
        return currentCards
    }

    public func setSuspended(isLocked: Bool) {
        suspended = isLocked
        if isLocked {
            sessionGeneration &+= 1
            sessionAccess.invalidate()
            pendingWebDAVUploadWorkItem?.cancel()
            pendingWebDAVUploadWorkItem = nil
            ledger = SyncLedger()
            cachedCards = []
            hasBootstrapped = false
            lastConvergenceAt = nil
            pendingStatus = "同步尚未准备好"
            let notify = onCardsChanged
            onCardsChanged = nil
            suspendBridge(true)
            notify?([]) // Presentation only: never save an empty lock state.
        } else {
            if sessionAccess.value == nil { sessionAccess = LockScopedValue(true) }
            suspendBridge(false)
        }
    }

    public func setWebDAVBridgeEnabled(_ enabled: Bool) {
        WebDAVBridgeService.shared.setEnabled(enabled)
        if enabled { WebDAVBridgeService.shared.synchronize(forceUpload: true) }
    }

    private func mergeRemote(_ records: [CardSyncRecord], generation: UInt64) async -> Bool {
        await mutations.acquire()
        defer { mutations.release() }
        guard isCurrentSession(generation), !Task.isCancelled else { return false }
        do {
            let current = ledger.records, access = sessionAccess
            let merged = try await storage.perform {
                guard access.value != nil else { throw CancellationError() }
                return CardSyncMergeEngine.merge([current, records])
            }
            guard isCurrentSession(generation) else { return false }
            guard merged != ledger.records else { return true }
            var candidate = ledger; candidate.records = merged
            let mirrored = try await persistCandidate(candidate, generation: generation)
            lastConvergenceAt = Date()
            pendingStatus = mirrored ? "已更新云端变化" : "卡片已保存，部分本地信息未能更新"
            return true
        } catch {
            if isCurrentSession(generation) { pendingStatus = "未能保存卡片，请重试；已有数据没有被更改" }
            return false
        }
    }

    /// Called only with the transaction slot. The ledger is authoritative; cards.json is its active mirror.
    private func persistCandidate(_ candidate: SyncLedger, generation: UInt64) async throws -> Bool {
        let access = sessionAccess, saver = saveLedger, mirror = persistCards
        let result = try await storage.perform {
            guard access.value != nil else { throw CancellationError() }
            guard saver(candidate) else { throw CocoaError(.fileWriteUnknown) }
            // Complete an accepted atomic write. A subsequent load waits for this transaction slot.
            let active = CardSyncMergeEngine.activeCards(from: candidate.records)
            return (active, mirror(active))
        }
        guard isCurrentSession(generation) else { throw CancellationError() }
        ledger = candidate
        cachedCards = result.0
        LocalCardPreferences.retain(Set(cachedCards.map(\.id)))
        onCardsChanged?(cachedCards)
        return result.1
    }

    private func updateMetadata(_ change: @escaping (inout SyncLedger) -> Void, generation: UInt64) async -> Bool {
        await mutations.acquire()
        defer { mutations.release() }
        guard isCurrentSession(generation) else { return false }
        var candidate = ledger; change(&candidate)
        let access = sessionAccess, saver = saveLedger, saving = candidate
        do {
            try await storage.perform {
                guard access.value != nil else { throw CancellationError() }
                guard saver(saving) else { throw CocoaError(.fileWriteUnknown) }
            }
            guard isCurrentSession(generation) else { return false }
            ledger = candidate
            return true
        } catch { return false }
    }

    private nonisolated static func latestRecordsByID(_ records: [CardSyncRecord]) -> [String: CardSyncRecord] {
        records.reduce(into: [:]) { result, record in
            guard !record.cardId.isEmpty else { return }
            result[record.cardId] = result[record.cardId].map { CardSyncMergeEngine.winner($0, record) } ?? record
        }
    }
    private nonisolated static func normalizedCard(_ card: SharedCard) -> SharedCard {
        var value = card
        if value.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { value.id = UUID().uuidString }
        value.cardCategory = value.cardCategory == "debit" ? "debit" : "credit"
        return value
    }
    private func scheduleWebDAVUpload() {
        pendingWebDAVUploadWorkItem?.cancel()
        let generation = sessionGeneration
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isCurrentSession(generation) else { return }
                WebDAVBridgeService.shared.synchronize(forceUpload: true)
            }
        }
        pendingWebDAVUploadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + webDAVUploadDebounceInterval, execute: work)
    }
}

/// Bridge reads and metadata writes use the SAME authoritative coordinator, never a second disk ledger.
@MainActor
struct WalletBridgeCallbacks {
    var records: () -> [CardSyncRecord]
    var merge: ([CardSyncRecord]) async -> Bool
    var ledger: () -> SyncLedger?
    var update: (@escaping (inout SyncLedger) -> Void) async -> Bool
}
