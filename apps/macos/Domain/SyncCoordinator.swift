import Foundation
import SwiftUI

public final class SyncCoordinator: ObservableObject {
    public static let shared = SyncCoordinator()

    @Published public private(set) var pendingStatus = "同步尚未准备好"
    @Published public private(set) var lastConvergenceAt: Date?

    private var ledger = SyncLedger()
    private var hasBootstrapped = false
    public var onCardsChanged: (([SharedCard]) -> Void)?
    private var pendingWebDAVUploadWorkItem: DispatchWorkItem?
    private let webDAVUploadDebounceInterval: TimeInterval = 0.8

    private var suspended = false
    private var sessionGeneration: UInt64 = 0
    private let readLock: () -> Bool
    private let loadLedger: ([SharedCard]) throws -> SyncLedger
    private let saveLedger: (SyncLedger) -> Bool
    private let persistCards: ([SharedCard]) -> Void
    private let configureBridge: (@escaping () -> [CardSyncRecord], @escaping ([CardSyncRecord]) -> Bool) -> Void
    private let suspendBridge: (Bool) -> Void

    private convenience init() {
        self.init(
            readLock: { AutoLockManager.shared.isLocked },
            loadLedger: { try SyncLedgerStore.shared.load(seeding: $0) },
            saveLedger: { SyncLedgerStore.shared.save($0) },
            persistCards: {
                LocalStorageManager.write(cards: $0)
                LocalCardPreferences.retain(Set($0.map(\.id)))
            },
            configureBridge: { WebDAVBridgeService.shared.configure(recordsProvider: $0, onMergedRecords: $1) },
            suspendBridge: { locked in
                WebDAVClient.shared.setSuspended(locked)
                if locked {
                    WebDAVBridgeService.shared.suspendForLock()
                    KeychainManager.clearTransientReads()
                    MainActor.assumeIsolated {
                        CardImageCache.shared.suspendForLock()
                        CardSystemNotificationCenter.shared.suspendForLock()
                    }
                }
            }
        )
    }

    // Storage and bridge seams keep lock regression tests away from the user's vault/network.
    init(readLock: @escaping () -> Bool,
         loadLedger: @escaping ([SharedCard]) throws -> SyncLedger,
         saveLedger: @escaping (SyncLedger) -> Bool,
         persistCards: @escaping ([SharedCard]) -> Void,
         configureBridge: @escaping (@escaping () -> [CardSyncRecord], @escaping ([CardSyncRecord]) -> Bool) -> Void,
         suspendBridge: @escaping (Bool) -> Void) {
        self.readLock = readLock
        self.loadLedger = loadLedger
        self.saveLedger = saveLedger
        self.persistCards = persistCards
        self.configureBridge = configureBridge
        self.suspendBridge = suspendBridge
    }

    private var canAccessCards: Bool { !suspended && !readLock() }
    func isCurrentSession(_ generation: UInt64) -> Bool {
        canAccessCards && hasBootstrapped && sessionGeneration == generation
    }
    var currentSessionGeneration: UInt64 { sessionGeneration }

    public func bootstrap(localCards: [SharedCard]) throws -> [SharedCard] {
        guard canAccessCards else { throw CancellationError() }
        guard !hasBootstrapped else { return currentCards }
        let generation = sessionGeneration
        var candidate = try loadLedger(localCards)
        guard canAccessCards, generation == sessionGeneration else { throw CancellationError() }
        // Publish only a successfully loaded ledger, never an empty replacement for a read failure.
        ledger = candidate
        if ledger.records.isEmpty && !localCards.isEmpty {
            candidate.records = localCards.map(CardSyncRecord.legacyActive)
            guard saveLedger(candidate) else { throw CocoaError(.fileWriteUnknown) }
            ledger = candidate
        }
        hasBootstrapped = true
        persistActiveView()

        configureBridge(
            { [weak self] in
                guard let self, self.isCurrentSession(generation) else { return [] }
                return self.ledger.records
            },
            { [weak self] records in
                guard let self, self.isCurrentSession(generation) else { return false }
                return self.mergeRemote(records)
            }
        )
        pendingStatus = "同步准备完成"
        return currentCards
    }

    public var currentCards: [SharedCard] {
        guard canAccessCards, hasBootstrapped else { return [] }
        return CardSyncMergeEngine.activeCards(from: ledger.records)
    }

    @discardableResult
    public func commit(cards: [SharedCard], deletedCardIDs: Set<String> = []) -> [SharedCard] {
        guard canAccessCards, hasBootstrapped else { return [] }
        let normalizedCards = cards.map(normalizedCard)
        let existingByID = latestRecordsByID(ledger.records)
        var events: [CardSyncRecord] = []
        let inputIDs = Set(normalizedCards.map(\.id))

        for card in normalizedCards {
            if let existing = existingByID[card.id], existing.state == .active, existing.card == card {
                continue
            }
            events.append(.active(card, changedAt: CardSyncRecord.nextTimestamp(after: existingByID[card.id])))
        }
        for cardID in deletedCardIDs where !inputIDs.contains(cardID) {
            events.append(.deleted(cardId: cardID, changedAt: CardSyncRecord.nextTimestamp(after: existingByID[cardID])))
        }
        return writeLocal(events: events)
    }

    @discardableResult
    public func restore(cards: [SharedCard]) -> [SharedCard] {
        guard canAccessCards, hasBootstrapped else { return [] }
        let normalizedCards = cards.map(normalizedCard)
        let restoredIDs = Set(normalizedCards.map(\.id))
        let existingActiveIDs = Set(ledger.records.filter { $0.state == .active }.map(\.cardId))
        let existingByID = latestRecordsByID(ledger.records)
        var events = normalizedCards.map { CardSyncRecord.active($0, changedAt: CardSyncRecord.nextTimestamp(after: existingByID[$0.id])) }
        events.append(contentsOf: existingActiveIDs.subtracting(restoredIDs).map { CardSyncRecord.deleted(cardId: $0, changedAt: CardSyncRecord.nextTimestamp(after: existingByID[$0])) })
        return writeLocal(events: events)
    }

    public func setSuspended(isLocked: Bool) {
        suspended = isLocked
        if isLocked {
            sessionGeneration &+= 1
            pendingWebDAVUploadWorkItem?.cancel()
            pendingWebDAVUploadWorkItem = nil
            ledger = SyncLedger()
            hasBootstrapped = false
            lastConvergenceAt = nil
            pendingStatus = "同步尚未准备好"
            let notify = onCardsChanged
            onCardsChanged = nil
            suspendBridge(true)
            // This notification clears presentation state only. Never persist the empty lock state.
            notify?([])
        } else {
            // The next successful local bootstrap reconnects the bridge; never sync an empty session.
            suspendBridge(false)
        }
    }

    public func setWebDAVBridgeEnabled(_ enabled: Bool) {
        WebDAVBridgeService.shared.setEnabled(enabled)
        if enabled {
            WebDAVBridgeService.shared.synchronize(forceUpload: true)
        }
    }

    @discardableResult
    private func mergeRemote(_ records: [CardSyncRecord]) -> Bool {
        guard hasBootstrapped, canAccessCards else { return false }
        let merged = CardSyncMergeEngine.merge([ledger.records, records])
        guard merged != ledger.records else { return true }
        var candidate = ledger
        candidate.records = merged
        guard saveLedger(candidate) else {
            pendingStatus = "未能保存卡片，请重试；已有数据没有被更改"
            return false
        }
        ledger = candidate
        persistActiveView()
        onCardsChanged?(currentCards)
        lastConvergenceAt = Date()
        pendingStatus = "已更新云端变化"
        return true
    }

    private func writeLocal(events: [CardSyncRecord]) -> [SharedCard] {
        guard hasBootstrapped, canAccessCards, !events.isEmpty else { return currentCards }
        var candidate = ledger
        candidate.records = CardSyncMergeEngine.merge([ledger.records, events])
        candidate.pendingWebDAVUpload = true
        guard saveLedger(candidate) else {
            pendingStatus = "未能保存卡片，请重试；已有数据没有被更改"
            return currentCards
        }
        ledger = candidate
        persistActiveView()
        pendingStatus = "正在同步最新修改"
        scheduleWebDAVUpload()
        return currentCards
    }

    private func persistActiveView() {
        persistCards(currentCards)
    }

    private func latestRecordsByID(_ records: [CardSyncRecord]) -> [String: CardSyncRecord] {
        records.reduce(into: [:]) { result, record in
            guard !record.cardId.isEmpty else { return }
            if let existing = result[record.cardId] {
                result[record.cardId] = CardSyncMergeEngine.winner(existing, record)
            } else {
                result[record.cardId] = record
            }
        }
    }

    private func normalizedCard(_ card: SharedCard) -> SharedCard {
        var normalized = card
        if normalized.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.id = UUID().uuidString
        }
        normalized.cardCategory = normalized.cardCategory == "debit" ? "debit" : "credit"
        return normalized
    }

    private func scheduleWebDAVUpload() {
        pendingWebDAVUploadWorkItem?.cancel()
        let generation = sessionGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isCurrentSession(generation) else { return }
            WebDAVBridgeService.shared.synchronize(forceUpload: true)
        }
        pendingWebDAVUploadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + webDAVUploadDebounceInterval, execute: workItem)
    }
}
