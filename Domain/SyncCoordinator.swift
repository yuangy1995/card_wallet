import Foundation
import SwiftUI

public final class SyncCoordinator: ObservableObject {
    public static let shared = SyncCoordinator()

    @Published public private(set) var pendingStatus = "尚未初始化同步"
    @Published public private(set) var lastConvergenceAt: Date?

    private var ledger = SyncLedger()
    private var hasBootstrapped = false
    public var onCardsChanged: (([SharedCard]) -> Void)?

    private init() {}

    public func bootstrap(localCards: [SharedCard]) -> [SharedCard] {
        guard !hasBootstrapped else { return currentCards }
        ledger = SyncLedgerStore.shared.load(seeding: localCards)
        if ledger.records.isEmpty && !localCards.isEmpty {
            ledger.records = localCards.map(CardSyncRecord.legacyActive)
            SyncLedgerStore.shared.save(ledger)
        }
        hasBootstrapped = true
        persistActiveView()

        CloudKitSyncService.shared.configure(
            stateData: ledger.cloudKitStateData,
            onRecordsReceived: { [weak self] records in
                self?.mergeRemote(records, originatingFrom: .icloud)
            },
            onStateUpdated: { [weak self] data in
                guard let self else { return }
                self.ledger.cloudKitStateData = data
                SyncLedgerStore.shared.save(self.ledger)
            }
        )
        WebDAVBridgeService.shared.configure(
            recordsProvider: { [weak self] in self?.ledger.records ?? [] },
            onMergedRecords: { [weak self] records in
                self?.mergeRemote(records, originatingFrom: .webdav)
            }
        )
        pendingStatus = "同步账本已载入"
        if CloudKitSyncService.shared.isEnabled {
            CloudKitSyncService.shared.queue(records: ledger.records)
        }
        return currentCards
    }

    public var currentCards: [SharedCard] {
        CardSyncMergeEngine.activeCards(from: ledger.records)
    }

    @discardableResult
    public func commit(cards: [SharedCard], deletedCardIDs: Set<String> = []) -> [SharedCard] {
        let normalizedCards = cards.map(normalizedCard)
        let existingByID = latestRecordsByID(ledger.records)
        var events: [CardSyncRecord] = []
        let inputIDs = Set(normalizedCards.map(\.id))

        for card in normalizedCards {
            if let existing = existingByID[card.id], existing.state == .active, existing.card == card {
                continue
            }
            events.append(.active(card))
        }
        for cardID in deletedCardIDs where !inputIDs.contains(cardID) {
            events.append(.deleted(cardId: cardID))
        }
        return writeLocal(events: events)
    }

    @discardableResult
    public func restore(cards: [SharedCard]) -> [SharedCard] {
        let normalizedCards = cards.map(normalizedCard)
        let restoredIDs = Set(normalizedCards.map(\.id))
        let existingActiveIDs = Set(ledger.records.filter { $0.state == .active }.map(\.cardId))
        var events = normalizedCards.map { CardSyncRecord.active($0) }
        events.append(contentsOf: existingActiveIDs.subtracting(restoredIDs).map { CardSyncRecord.deleted(cardId: $0) })
        return writeLocal(events: events)
    }

    public func setSuspended(isLocked: Bool) {
        if isLocked {
            WebDAVBridgeService.shared.stop()
        } else {
            WebDAVBridgeService.shared.start()
            CloudKitSyncService.shared.refresh()
        }
    }

    public func setICloudEnabled(_ enabled: Bool) {
        CloudKitSyncService.shared.setEnabled(enabled)
        if enabled {
            CloudKitSyncService.shared.queue(records: ledger.records)
        }
    }

    public func setWebDAVBridgeEnabled(_ enabled: Bool) {
        WebDAVBridgeService.shared.setEnabled(enabled)
        if enabled {
            WebDAVBridgeService.shared.synchronize(forceUpload: true)
        }
    }

    private enum Origin {
        case icloud
        case webdav
    }

    private func mergeRemote(_ records: [CardSyncRecord], originatingFrom origin: Origin) {
        let merged = CardSyncMergeEngine.merge([ledger.records, records])
        guard merged != ledger.records else { return }
        ledger.records = merged
        ledger.pendingCloudKitUpload = origin == .webdav
        ledger.pendingWebDAVUpload = origin == .icloud
        SyncLedgerStore.shared.save(ledger)
        persistActiveView()
        let cards = currentCards
        onCardsChanged?(cards)
        lastConvergenceAt = Date()
        pendingStatus = "已合并远端变更"

        switch origin {
        case .webdav:
            CloudKitSyncService.shared.queue(records: merged)
        case .icloud:
            WebDAVBridgeService.shared.synchronize(forceUpload: true)
        }
    }

    private func writeLocal(events: [CardSyncRecord]) -> [SharedCard] {
        guard !events.isEmpty else { return currentCards }
        ledger.records = CardSyncMergeEngine.merge([ledger.records, events])
        ledger.pendingCloudKitUpload = true
        ledger.pendingWebDAVUpload = true
        SyncLedgerStore.shared.save(ledger)
        persistActiveView()
        pendingStatus = "本地有变更，正在同步"
        CloudKitSyncService.shared.queue(records: events)
        WebDAVBridgeService.shared.synchronize(forceUpload: true)
        return currentCards
    }

    private func persistActiveView() {
        LocalStorageManager.write(cards: currentCards)
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
        return normalized
    }
}
