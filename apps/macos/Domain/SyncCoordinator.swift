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

    private init() {}

    public func bootstrap(localCards: [SharedCard]) -> [SharedCard] {
        guard !hasBootstrapped else { return currentCards }
        do { ledger = try SyncLedgerStore.shared.load(seeding: localCards) }
        catch { pendingStatus = "本地账本无法读取，未修改原数据"; return localCards }
        if ledger.records.isEmpty && !localCards.isEmpty {
            ledger.records = localCards.map(CardSyncRecord.legacyActive)
            SyncLedgerStore.shared.save(ledger)
        }
        hasBootstrapped = true
        persistActiveView()

        WebDAVBridgeService.shared.configure(
            recordsProvider: { [weak self] in self?.ledger.records ?? [] },
            onMergedRecords: { [weak self] records in
                self?.mergeRemote(records)
            }
        )
        pendingStatus = "同步准备完成"
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
            pendingWebDAVUploadWorkItem?.cancel()
            pendingWebDAVUploadWorkItem = nil
            WebDAVBridgeService.shared.stop()
        } else {
            guard hasBootstrapped else { return }
            WebDAVBridgeService.shared.start()
        }
    }

    public func setWebDAVBridgeEnabled(_ enabled: Bool) {
        WebDAVBridgeService.shared.setEnabled(enabled)
        if enabled {
            WebDAVBridgeService.shared.synchronize(forceUpload: true)
        }
    }

    private func mergeRemote(_ records: [CardSyncRecord]) {
        let merged = CardSyncMergeEngine.merge([ledger.records, records])
        guard merged != ledger.records else { return }
        var updated = ledger
        updated.records = merged
        guard SyncLedgerStore.shared.save(updated) else { pendingStatus = "本地数据未能保存，请重试"; return }
        ledger = updated
        persistActiveView()
        let cards = currentCards
        onCardsChanged?(cards)
        lastConvergenceAt = Date()
        pendingStatus = "已更新云端变化"

    }

    private func writeLocal(events: [CardSyncRecord]) -> [SharedCard] {
        guard hasBootstrapped, !AutoLockManager.shared.isLocked, !events.isEmpty else { return currentCards }
        var updated = ledger
        updated.records = CardSyncMergeEngine.merge([ledger.records, CardSyncMergeEngine.localEvents(events, after: ledger.records)])
        updated.pendingWebDAVUpload = true
        guard SyncLedgerStore.shared.save(updated) else { pendingStatus = "本地数据未能保存，请重试"; return currentCards }
        ledger = updated
        persistActiveView()
        pendingStatus = "正在同步最新修改"
        scheduleWebDAVUpload()
        return currentCards
    }

    private func persistActiveView() {
        LocalCardPreferences.removeDeleted(Set(ledger.records.filter { $0.state == .deleted }.map(\.cardId)))
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
        normalized.cardCategory = normalized.cardCategory == "debit" ? "debit" : "credit"
        return normalized
    }

    private func scheduleWebDAVUpload() {
        pendingWebDAVUploadWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            WebDAVBridgeService.shared.synchronize(forceUpload: true)
        }
        pendingWebDAVUploadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + webDAVUploadDebounceInterval, execute: workItem)
    }
}
