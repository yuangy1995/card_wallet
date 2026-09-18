import Foundation
import Combine

private final class ProgressBox: @unchecked Sendable {
    var value: Int64 = 0
    init(value: Int64 = 0) {
        self.value = value
    }
}

private struct PreparedWebDAVUpload: Sendable {
    var snapshot: WebDAVSyncSnapshotV4
    var cipherText: String
    var filename: String
}

private struct PreparedSyncMerge: Sendable {
    var mergedRecords: [CardSyncRecord]
    var changedByRemote: Bool
}

public struct SyncProgress: Codable, Hashable, Sendable {
    public var phase: String
    public var step: Int
    public var total: Int
    public var detail: String
    public var updatedAt: Date
    public var totalBytes: Int64?
    public var downloadedBytes: Int64?

    public init(
        phase: String = "空闲",
        step: Int = 0,
        total: Int = 0,
        detail: String = "",
        updatedAt: Date = Date(),
        totalBytes: Int64? = nil,
        downloadedBytes: Int64? = nil
    ) {
        self.phase = phase
        self.step = step
        self.total = total
        self.detail = detail
        self.updatedAt = updatedAt
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
    }

    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(step) / Double(total)))
    }
}

public struct FieldChangeDetail: Codable, Hashable, Sendable {
    public var label: String
    public var oldValue: String
    public var newValue: String

    public init(label: String, oldValue: String, newValue: String) {
        self.label = label
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

public struct CardChangeDetail: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var kind: String
    public var cardId: String
    public var cardName: String
    public var fields: [FieldChangeDetail]

    public init(kind: String, cardId: String, cardName: String, fields: [FieldChangeDetail]) {
        self.id = "\(kind)-\(cardId)-\(fields.map(\.label).joined(separator: ","))"
        self.kind = kind
        self.cardId = cardId
        self.cardName = cardName
        self.fields = fields
    }
}

public struct SyncHistoryEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var startedAt: Date
    public var finishedAt: Date
    public var status: String
    public var message: String
    public var durationSeconds: TimeInterval
    public var uploadedFile: String?
    public var downloadedFiles: [String]
    public var localChanges: [CardChangeDetail]
    public var remoteChanges: [CardChangeDetail]

    public init(
        id: String = UUID().uuidString,
        startedAt: Date,
        finishedAt: Date = Date(),
        status: String,
        message: String,
        durationSeconds: TimeInterval,
        uploadedFile: String?,
        downloadedFiles: [String],
        localChanges: [CardChangeDetail],
        remoteChanges: [CardChangeDetail]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.message = message
        self.durationSeconds = durationSeconds
        self.uploadedFile = uploadedFile
        self.downloadedFiles = downloadedFiles
        self.localChanges = localChanges
        self.remoteChanges = remoteChanges
    }
}

@MainActor
public final class SyncCoordinator: ObservableObject {
    public static let shared = SyncCoordinator()

    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncAt: Date?
    @Published public private(set) var cards: [SharedCard] = []
    @Published public private(set) var syncElapsedSeconds: TimeInterval = 0
    @Published public private(set) var lastSyncDurationSeconds: TimeInterval?
    @Published public private(set) var isSynchronizing = false
    @Published public private(set) var syncProgress = SyncProgress()
    @Published public private(set) var syncHistory: [SyncHistoryEntry] = []
    @Published public private(set) var webDAVConfigReady = false
    @Published public private(set) var needsCellularSyncConfirmation = false

    private var ledger = SyncLedger()
    private var hasBootstrapped = false
    private var queuedForceUpload = false
    private var queuedCellularOverride = false
    private var activeCellularOverride = false
    private var cancelRequested = false
    private var syncTimer: Timer?
    private var elapsedTimer: Timer?
    private var syncStartedAt: Date?
    private var localRevision = 0
    private var isSuspended = true
    private var localDataReady = false
    private var publishTask: Task<Void, Never>?

    public func setSuspended(isLocked: Bool) {
        guard isSuspended != isLocked else { return }
        isSuspended = isLocked
        if isLocked {
            publishTask?.cancel(); publishTask = nil
            stopAutoSync(); cancelCurrentSync(); needsCellularSyncConfirmation = false
            WebDAVClient.shared.cancelAll()
            cards = []; syncHistory = []
        } else if !hasBootstrapped { bootstrap() }
        else if localDataReady {
            cards = CardSyncMergeEngine.activeCards(from: ledger.records)
            syncHistory = loadSyncHistory()
            startAutoSync()
        }
    }
    private static let lastSyncAtKey = "webdav_last_sync_at_ms"
    private static let lastSyncDurationKey = "webdav_last_sync_duration_seconds"
    private static let syncHistoryKey = "webdav_sync_history_v1"
    private static let maxSnapshotsToMerge = 5

    private enum SyncTrigger {
        case automatic
        case manual(cellularConfirmed: Bool)

        var cellularConfirmed: Bool {
            if case .manual(let confirmed) = self {
                return confirmed
            }
            return false
        }
    }

    public enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case warning(String)
        case failure(String)

        public var displayText: String {
            switch self {
            case .idle: return "等待同步"
            case .syncing: return "正在同步…"
            case .success: return "同步成功"
            case .warning(let msg): return msg
            case .failure(let msg): return "同步失败: \(msg)"
            }
        }

        public var iconName: String {
            switch self {
            case .idle: return "icloud"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .success: return "checkmark.icloud.fill"
            case .warning: return "exclamationmark.icloud.fill"
            case .failure: return "exclamationmark.icloud.fill"
            }
        }
    }

    private init() {}

    public func bootstrap() {
        guard !hasBootstrapped, !isSuspended else { return }
        hasBootstrapped = true
        refreshWebDAVConfigurationState(disableAutoSyncWhenInvalid: true)
        restoreLastSyncMetadata()
        syncHistory = loadSyncHistory()
        let localResult = LocalStorageManager.read()
        switch localResult {
        case .success(let localCards):
            do { ledger = try SyncLedgerStore.shared.load(seeding: localCards) }
            catch {
                syncStatus = .failure("本地账本无法读取，未修改原数据")
                hasBootstrapped = false; localDataReady = false; return
            }
            if ledger.records.isEmpty && !localCards.isEmpty {
                ledger.records = localCards.map(CardSyncRecord.activeUsingCardTimestamp)
                SyncLedgerStore.shared.saveInBackground(ledger)
            }
            localDataReady = true
            cards = isSuspended ? [] : CardSyncMergeEngine.activeCards(from: ledger.records)
            LocalCardPreferences.removeDeleted(Set(ledger.records.filter { $0.state == .deleted }.map(\.cardId)))
        case .failure:
            localDataReady = false
            syncStatus = .failure("本地数据无法读取，未修改原数据，请解锁设备后重试")
            hasBootstrapped = false
            return
        }
        repairPendingUploadStateIfNeeded()

        if UserDefaults.standard.bool(forKey: "enable_webdav_sync"), webDAVConfigReady {
            startAutoSync()
        }
    }

    @discardableResult
    public func commit(cards updatedCards: [SharedCard], deletedCardIDs: Set<String> = []) -> [SharedCard] {
        let normalized = updatedCards.map(normalizedCard)
        let existingByID = latestRecordsByID(ledger.records)
        var events: [CardSyncRecord] = []
        let inputIDs = Set(normalized.map(\.id))
        for card in normalized {
            if let existing = existingByID[card.id], existing.state == .active, existing.card == card { continue }
            events.append(.active(card))
        }
        for cardID in deletedCardIDs where !inputIDs.contains(cardID) {
            events.append(.deleted(cardId: cardID))
        }
        return writeLocal(events: events)
    }

    @discardableResult
    public func restore(cards: [SharedCard]) -> [SharedCard] {
        let normalized = cards.map(normalizedCard)
        let restoredIDs = Set(normalized.map(\.id))
        let existingActiveIDs = Set(ledger.records.filter { $0.state == .active }.map(\.cardId))
        var events = normalized.map { CardSyncRecord.active($0) }
        events.append(contentsOf: existingActiveIDs.subtracting(restoredIDs).map { CardSyncRecord.deleted(cardId: $0) })
        return writeLocal(events: events)
    }

    public func setWebDAVEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "enable_webdav_sync")
        if enabled {
            guard refreshWebDAVConfigurationState(disableAutoSyncWhenInvalid: true) else { return }
            startAutoSync()
        } else {
            stopAutoSync()
            syncStatus = .idle
        }
    }

    public func startAutoSync() {
        stopAutoSync()
        guard !isSuspended, localDataReady, UserDefaults.standard.bool(forKey: "enable_webdav_sync") else { return }
        guard refreshWebDAVConfigurationState(disableAutoSyncWhenInvalid: true) else { return }
        let configuredInterval = UserDefaults.standard.double(forKey: "auto_sync_interval")
        let interval = configuredInterval > 0 ? configuredInterval : 300
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.synchronize(forceUpload: false)
            }
        }
        Task { await synchronize(forceUpload: false) }
    }

    @discardableResult
    public func refreshWebDAVConfigurationState(disableAutoSyncWhenInvalid: Bool = false) -> Bool {
        let ready = WebDAVClient.shared.hasCompleteSyncConfig()
        webDAVConfigReady = ready
        if !ready, disableAutoSyncWhenInvalid {
            UserDefaults.standard.set(false, forKey: "enable_webdav_sync")
            stopAutoSync()
            if !isSynchronizing {
                syncStatus = .idle
            }
        }
        return ready
    }

    public func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    public func cancelCurrentSync() {
        publishTask?.cancel(); publishTask = nil
        cancelRequested = true
        WebDAVClient.shared.cancelAll()
        guard isSynchronizing else { return }
        queuedForceUpload = false
        ledger.pendingWebDAVUpload = true
        SyncLedgerStore.shared.saveInBackground(ledger)
        syncStatus = .warning("正在终止同步，本机未同步修改已保留")
        updateProgress(
            "正在终止",
            step: syncProgress.step,
            total: syncProgress.total,
            detail: "已请求终止，等待当前网络请求返回后停止"
        )
    }

    public func synchronize(forceUpload: Bool = false) async {
        await synchronize(forceUpload: forceUpload, trigger: .automatic)
    }

    public func requestManualSync() {
        Task {
            guard refreshWebDAVConfigurationState() else {
                await synchronize(forceUpload: true, trigger: .manual(cellularConfirmed: false))
                return
            }
            if await SyncNetworkMonitor.shared.connection() == .cellular {
                needsCellularSyncConfirmation = true
                return
            }
            await synchronize(forceUpload: true, trigger: .manual(cellularConfirmed: false))
        }
    }

    public func confirmCellularSync() {
        needsCellularSyncConfirmation = false
        Task { await synchronize(forceUpload: true, trigger: .manual(cellularConfirmed: true)) }
    }

    public func cancelCellularSyncConfirmation() {
        needsCellularSyncConfirmation = false
    }

    private func synchronize(forceUpload: Bool, trigger: SyncTrigger) async {
        guard !isSuspended, localDataReady else { return }
        guard UserDefaults.standard.bool(forKey: "enable_webdav_sync") || forceUpload else { return }
        guard refreshWebDAVConfigurationState(disableAutoSyncWhenInvalid: true) else { return }
        if await SyncNetworkMonitor.shared.connection() == .cellular {
            switch trigger {
            case .automatic where SyncNetworkPreference.saved == .wifiOnly:
                syncStatus = .warning("已暂停自动同步：当前使用移动数据")
                updateProgress("等待 Wi‑Fi", step: 0, total: 0, detail: "自动同步仅使用 Wi‑Fi，连接 Wi‑Fi 后将自动重试")
                return
            case .manual(let confirmed) where !confirmed:
                needsCellularSyncConfirmation = true
                return
            default:
                break
            }
        }
        guard !isSuspended, localDataReady else { return }
        if isSynchronizing {
            if forceUpload {
                queuedForceUpload = true
                queuedCellularOverride = queuedCellularOverride || trigger.cellularConfirmed
                ledger.pendingWebDAVUpload = true
                SyncLedgerStore.shared.save(ledger)
            }
            return
        }
        guard WebDAVClient.shared.loadConfig() != nil else {
            syncStatus = .failure("请先配置 WebDAV")
            return
        }
        let syncPassword = KeychainManager.load(key: "webdav_sync_password_v4")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !syncPassword.isEmpty else {
            syncStatus = .failure("请先填写同步密钥")
            return
        }

        isSynchronizing = true
        activeCellularOverride = trigger.cellularConfirmed
        let allowsCellularAccess =
            SyncNetworkPreference.saved == .wifiAndCellular || trigger.cellularConfirmed
        cancelRequested = false
        syncStatus = .syncing
        startSyncTiming()
        updateProgress("准备同步", step: 1, total: 6, detail: "正在读取同步配置")
        let snapshotRevision = localRevision
        let historyStartedAt = syncStartedAt ?? Date()
        let activeCardsBeforeSync = cards
        var downloadedFiles: [String] = []
        var uploadedFile: String?
        var localChanges: [CardChangeDetail] = []
        var remoteChanges: [CardChangeDetail] = []

        do {
            try ensureSyncNotCancelled()
            updateProgress("读取云端列表", step: 2, total: 6, detail: "正在连接 WebDAV")
            let files = try await getBackupList(allowsCellularAccess: allowsCellularAccess)
            try ensureSyncNotCancelled()
            let automaticFiles = files
                .filter { $0.filename.contains("[SyncV4]") && $0.filename.contains("[自]") }
                .sorted {
                    let leftDate = $0.lastModifiedDate ?? .distantPast
                    let rightDate = $1.lastModifiedDate ?? .distantPast
                    if leftDate != rightDate { return leftDate > rightDate }
                    return $0.filename > $1.filename
                }
            // 每份 SyncV4 文件都是完整快照。空本地首次恢复只读取最新一份，
            // 已有本地数据时仍合并最近 5 份以保留跨设备冲突收敛能力。
            let snapshotReadLimit = ledger.records.isEmpty ? 1 : Self.maxSnapshotsToMerge
            let filesToRead = Array(automaticFiles.prefix(snapshotReadLimit))
            let isFreshSingleSnapshotRestore = ledger.records.isEmpty &&
                !ledger.pendingWebDAVUpload &&
                !forceUpload &&
                filesToRead.count == 1
            downloadedFiles = filesToRead.map(\.filename)

            if filesToRead.isEmpty, !forceUpload, !ledger.pendingWebDAVUpload {
                let message = "云端还没有新版同步文件，可点击立即同步初始化"
                appendSyncHistory(
                    status: "warning",
                    message: message,
                    startedAt: historyStartedAt,
                    uploadedFile: nil,
                    downloadedFiles: [],
                    localChanges: [],
                    remoteChanges: []
                )
                updateProgress("等待初始化", step: 0, total: 0, detail: message)
                finishSync(status: .warning(message), markSuccess: false)
                return
            }
            if canSkipSnapshotDownload(automaticFiles: automaticFiles, forceUpload: forceUpload) {
                let message = "云端与本机已同步"
                appendSyncHistory(
                    status: "success",
                    message: message,
                    startedAt: historyStartedAt,
                    uploadedFile: nil,
                    downloadedFiles: [],
                    localChanges: [],
                    remoteChanges: []
                )
                updateProgress("同步完成", step: 6, total: 6, detail: message)
                finishSync(status: .success, markSuccess: true)
                return
            }

            let totalBytes = filesToRead.reduce(0) { $0 + $1.size }
            let progressBox = ProgressBox()
            let downloadDetail = filesToRead.count == 1
                ? "正在下载最新云端快照"
                : "正在并发下载最近 \(filesToRead.count) 个快照"
            updateProgress(
                "读取同步文件",
                step: 3,
                total: 6,
                detail: downloadDetail,
                totalBytes: totalBytes,
                downloadedBytes: progressBox.value
            )
            let snapshots = await Self.downloadSnapshots(
                files: filesToRead,
                syncPassword: syncPassword,
                allowsCellularAccess: allowsCellularAccess
            ) { [weak self] delta in
                guard let self else { return }
                DispatchQueue.main.async {
                    progressBox.value += delta
                    self.updateProgress(
                        "读取同步文件",
                        step: 3,
                        total: 6,
                        detail: downloadDetail,
                        totalBytes: totalBytes,
                        downloadedBytes: progressBox.value
                    )
                }
            }
            try ensureSyncNotCancelled()
            if snapshots.count != filesToRead.count {
                throw WebDAVError.httpError(statusCode: 0, message: "无法解密云端同步文件，请检查同步密钥")
            }

            updateProgress("合并数据", step: 4, total: 6, detail: "正在比对本机与云端变更")
            let remoteRecords = snapshots.flatMap(\.records)
            let localRecordsBeforeMerge = ledger.records
            localChanges = Self.recentLocalChanges(
                records: localRecordsBeforeMerge,
                since: Self.snapshotDate(fromFilename: ledger.lastWebDAVSnapshotFilename ?? "")
            )
            let preparedMerge = await Self.prepareMerge(localRecords: localRecordsBeforeMerge, remoteRecords: remoteRecords)
            try ensureSyncNotCancelled()
            // MainActor may have accepted an edit while the background merge was running.
            let merged = CardSyncMergeEngine.merge([ledger.records, preparedMerge.mergedRecords])
            let mergeResult = PreparedSyncMerge(mergedRecords: merged, changedByRemote: merged != CardSyncMergeEngine.merge([ledger.records]))
            if mergeResult.changedByRemote {
                var updated = ledger; updated.records = merged
                guard SyncLedgerStore.shared.save(updated) else { throw CocoaError(.fileWriteUnknown) }
                ledger = updated
                persistActiveCards()
                remoteChanges = Self.cardChanges(before: activeCardsBeforeSync, after: CardSyncMergeEngine.activeCards(from: merged), kind: "云端更新")
            }

            let shouldUpload = forceUpload ||
                ledger.pendingWebDAVUpload ||
                (automaticFiles.isEmpty && !mergeResult.mergedRecords.isEmpty) ||
                (mergeResult.changedByRemote && !isFreshSingleSnapshotRestore)

            if shouldUpload {
                try ensureSyncNotCancelled()
                updateProgress("上传合并快照", step: 5, total: 6, detail: "正在写入 WebDAV 加密快照")
                uploadedFile = try await uploadConsolidatedSnapshot(
                    records: mergeResult.mergedRecords,
                    downloadedSnapshots: snapshots,
                    listedFiles: filesToRead,
                    syncPassword: syncPassword,
                    snapshotRevision: localRevision,
                    allowsCellularAccess: allowsCellularAccess
                )
                try ensureSyncNotCancelled()
                let message = ledger.pendingWebDAVUpload ? "本机有新修改，正在继续同步" : "云端与本机已同步"
                appendSyncHistory(
                    status: "success",
                    message: message,
                    startedAt: historyStartedAt,
                    uploadedFile: uploadedFile,
                    downloadedFiles: downloadedFiles,
                    localChanges: localChanges,
                    remoteChanges: remoteChanges
                )
                updateProgress("同步完成", step: 6, total: 6, detail: message)
                finishSync(status: .success, markSuccess: true)
                if let uploadedFile {
                    pruneAutomaticSnapshots(from: filesToRead + [
                        WebDAVBackupFile(filename: uploadedFile, size: 0, lastModified: SyncTimestamp.now())
                    ])
                }
            } else {
                recordProcessedSnapshots(
                    snapshots,
                    newestFilename: automaticFiles.first?.filename,
                    snapshotRevision: snapshotRevision,
                    allowUpdatingLastFilename: isFreshSingleSnapshotRestore
                )
                let message = mergeResult.changedByRemote ? "云端数据已恢复到本机" : "云端与本机已同步"
                appendSyncHistory(
                    status: "success",
                    message: message,
                    startedAt: historyStartedAt,
                    uploadedFile: nil,
                    downloadedFiles: downloadedFiles,
                    localChanges: localChanges,
                    remoteChanges: remoteChanges
                )
                updateProgress("同步完成", step: 6, total: 6, detail: message)
                finishSync(status: .success, markSuccess: true)
            }
        } catch is CancellationError {
            let message = "同步已终止：本机未同步修改已保留"
            ledger.pendingWebDAVUpload = true
            queuedForceUpload = false
            SyncLedgerStore.shared.saveInBackground(ledger)
            appendSyncHistory(
                status: "warning",
                message: message,
                startedAt: historyStartedAt,
                uploadedFile: uploadedFile,
                downloadedFiles: downloadedFiles,
                localChanges: localChanges,
                remoteChanges: remoteChanges
            )
            updateProgress("已终止", step: 0, total: 0, detail: "本机修改已保留，可重新执行同步")
            finishSync(status: .warning("同步已终止，本机未同步修改已保留"), markSuccess: false, continueQueued: false)
        } catch {
            ledger.pendingWebDAVUpload = true
            SyncLedgerStore.shared.saveInBackground(ledger)
            print("[SyncCoordinator] 同步失败，已保留本机待上传状态: \(error.localizedDescription)")
            appendSyncHistory(
                status: "failure",
                message: error.localizedDescription,
                startedAt: historyStartedAt,
                uploadedFile: uploadedFile,
                downloadedFiles: downloadedFiles,
                localChanges: localChanges,
                remoteChanges: remoteChanges
            )
            updateProgress("同步失败", step: syncProgress.step, total: syncProgress.total, detail: error.localizedDescription)
            finishSync(status: .failure(error.localizedDescription), markSuccess: false)
        }
    }

    private func writeLocal(events: [CardSyncRecord]) -> [SharedCard] {
        guard !isSuspended, localDataReady, !events.isEmpty else { return cards }
        var updated = ledger
        updated.records = CardSyncMergeEngine.merge([ledger.records, CardSyncMergeEngine.localEvents(events, after: ledger.records)])
        updated.pendingWebDAVUpload = true
        guard SyncLedgerStore.shared.save(updated) else { syncStatus = .failure("本地数据未能保存，请重试"); return cards }
        ledger = updated
        localRevision += 1
        persistActiveCards()
        if UserDefaults.standard.bool(forKey: "enable_webdav_sync") {
            publishTask?.cancel()
            publishTask = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 800_000_000) } catch { return }
                guard let self, !self.isSuspended else { return }
                await self.synchronize(forceUpload: true)
            }
        }
        return cards
    }

    private func persistActiveCards() {
        let activeCards = CardSyncMergeEngine.activeCards(from: ledger.records)
        LocalCardPreferences.removeDeleted(Set(ledger.records.filter { $0.state == .deleted }.map(\.cardId)))
        cards = isSuspended ? [] : activeCards
        LocalStorageManager.writeInBackground(cards: activeCards)
    }

    private func persistActiveCardsAsync() async {
        // Queue the snapshot in actor order; never assign a stale detached result back into UI.
        persistActiveCards()
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

    private func repairPendingUploadStateIfNeeded() {
        guard !ledger.pendingWebDAVUpload,
              let lastFilename = ledger.lastWebDAVSnapshotFilename,
              let lastSnapshotDate = Self.snapshotDate(fromFilename: lastFilename),
              let newestLocalDate = ledger.records.compactMap({ SyncTimestamp.date(from: $0.changedAt) }).max(),
              newestLocalDate > lastSnapshotDate else {
            return
        }
        ledger.pendingWebDAVUpload = true
        queuedForceUpload = true
        SyncLedgerStore.shared.saveInBackground(ledger)
        print("[SyncCoordinator] 检测到本机记录晚于上次云端快照，已恢复待上传状态")
    }

    private func ensureSyncNotCancelled() throws {
        if cancelRequested || isSuspended {
            throw CancellationError()
        }
    }

    private func updateProgress(
        _ phase: String,
        step: Int,
        total: Int,
        detail: String,
        totalBytes: Int64? = nil,
        downloadedBytes: Int64? = nil
    ) {
        syncProgress = SyncProgress(
            phase: phase,
            step: step,
            total: total,
            detail: detail,
            totalBytes: totalBytes,
            downloadedBytes: downloadedBytes
        )
    }

    private func appendSyncHistory(
        status: String,
        message: String,
        startedAt: Date,
        uploadedFile: String?,
        downloadedFiles: [String],
        localChanges: [CardChangeDetail],
        remoteChanges: [CardChangeDetail]
    ) {
        let entry = SyncHistoryEntry(
            startedAt: startedAt,
            status: status,
            message: message,
            durationSeconds: currentSyncDuration(),
            uploadedFile: uploadedFile,
            downloadedFiles: downloadedFiles,
            localChanges: Array(localChanges.prefix(20)),
            remoteChanges: Array(remoteChanges.prefix(20))
        )
        syncHistory.insert(entry, at: 0)
        if syncHistory.count > 40 {
            syncHistory.removeLast(syncHistory.count - 40)
        }
        saveSyncHistory()
    }

    private func loadSyncHistory() -> [SyncHistoryEntry] {
        guard let stored = UserDefaults.standard.data(forKey: Self.syncHistoryKey) else { return [] }
        let isEncrypted = String(decoding: stored, as: UTF8.self).hasPrefix("local-v1:")
        let data = isEncrypted ? (try? CryptoManager.decryptLocalData(stored)) : stored
        guard let data, let entries = try? JSONDecoder().decode([SyncHistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveSyncHistory() {
        guard let data = try? JSONEncoder().encode(syncHistory) else { return }
        guard let sealed = try? CryptoManager.encryptLocalData(data) else { return }
        UserDefaults.standard.set(sealed, forKey: Self.syncHistoryKey)
    }

    private nonisolated static func snapshotDate(fromFilename filename: String) -> Date? {
        let prefix = filename.components(separatedBy: "---").first ?? filename
        let utcFormatter = DateFormatter()
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        utcFormatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss-SSS'Z'"
        if let date = utcFormatter.date(from: prefix) {
            return date
        }

        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
        return localFormatter.date(from: prefix)
    }

    private nonisolated static func recentLocalChanges(records: [CardSyncRecord], since: Date?) -> [CardChangeDetail] {
        let cutoff = since ?? .distantPast
        let latestRecords = records.reduce(into: [String: CardSyncRecord]()) { result, record in
            guard !record.cardId.isEmpty else { return }
            if let existing = result[record.cardId] {
                result[record.cardId] = CardSyncMergeEngine.winner(existing, record)
            } else {
                result[record.cardId] = record
            }
        }

        return latestRecords.values.compactMap { record in
            let changedAt = SyncTimestamp.date(from: record.changedAt) ?? .distantPast
            guard changedAt > cutoff else { return nil }
            switch record.state {
            case .active:
                guard let card = record.card else { return nil }
                let fields = [
                    FieldChangeDetail(label: "发卡行", oldValue: "云端旧值", newValue: displayValue(card.bank)),
                    FieldChangeDetail(label: "别名", oldValue: "云端旧值", newValue: displayValue(card.alias)),
                    FieldChangeDetail(label: "卡号", oldValue: "云端旧值", newValue: maskedCardNumber(card.cardNumber))
                ]
                return CardChangeDetail(kind: "本机修改", cardId: record.cardId, cardName: cardDisplayName(card), fields: fields)
            case .deleted:
                return CardChangeDetail(
                    kind: "本机删除",
                    cardId: record.cardId,
                    cardName: record.cardId,
                    fields: [FieldChangeDetail(label: "状态", oldValue: "已存在", newValue: "已删除")]
                )
            }
        }
        .sorted { $0.cardName < $1.cardName }
    }

    private nonisolated static func cardChanges(before: [SharedCard], after: [SharedCard], kind: String) -> [CardChangeDetail] {
        let beforeByID = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0) })
        let afterByID = Dictionary(uniqueKeysWithValues: after.map { ($0.id, $0) })
        let ids = Set(beforeByID.keys).union(afterByID.keys)

        return ids.compactMap { id in
            let oldCard = beforeByID[id]
            let newCard = afterByID[id]
            if oldCard == nil, let newCard {
                return CardChangeDetail(
                    kind: kind,
                    cardId: id,
                    cardName: cardDisplayName(newCard),
                    fields: [FieldChangeDetail(label: "状态", oldValue: "无", newValue: "新增")]
                )
            }
            if newCard == nil, let oldCard {
                return CardChangeDetail(
                    kind: kind,
                    cardId: id,
                    cardName: cardDisplayName(oldCard),
                    fields: [FieldChangeDetail(label: "状态", oldValue: "已存在", newValue: "已删除")]
                )
            }
            guard let oldCard, let newCard else { return nil }
            let fields = fieldChanges(from: oldCard, to: newCard)
            guard !fields.isEmpty else { return nil }
            return CardChangeDetail(kind: kind, cardId: id, cardName: cardDisplayName(newCard), fields: fields)
        }
        .sorted { $0.cardName < $1.cardName }
    }

    private nonisolated static func fieldChanges(from oldCard: SharedCard, to newCard: SharedCard) -> [FieldChangeDetail] {
        var fields: [FieldChangeDetail] = []
        appendField(&fields, label: "发卡行", oldValue: oldCard.bank, newValue: newCard.bank)
        appendField(&fields, label: "别名", oldValue: oldCard.alias, newValue: newCard.alias)
        appendField(&fields, label: "卡类别", oldValue: categoryText(oldCard.cardCategory), newValue: categoryText(newCard.cardCategory))
        appendField(&fields, label: "发卡国家", oldValue: oldCard.country, newValue: newCard.country)
        appendField(&fields, label: "卡号", oldValue: maskedCardNumber(oldCard.cardNumber), newValue: maskedCardNumber(newCard.cardNumber))
        appendField(&fields, label: "卡级别", oldValue: oldCard.level, newValue: newCard.level)
        appendField(&fields, label: "币种", oldValue: oldCard.type, newValue: newCard.type)
        appendField(&fields, label: "额度", oldValue: amountText(oldCard.limit), newValue: amountText(newCard.limit))
        appendField(&fields, label: "有效期", oldValue: oldCard.valid, newValue: newCard.valid)
        appendField(&fields, label: "年费", oldValue: amountText(oldCard.annualFee), newValue: amountText(newCard.annualFee))
        appendField(&fields, label: "共享额度", oldValue: oldCard.isSharedLimit ? "是" : "否", newValue: newCard.isSharedLimit ? "是" : "否")
        return Array(fields.prefix(8))
    }

    private nonisolated static func appendField(
        _ fields: inout [FieldChangeDetail],
        label: String,
        oldValue: String?,
        newValue: String?
    ) {
        let old = displayValue(oldValue)
        let new = displayValue(newValue)
        guard old != new else { return }
        fields.append(FieldChangeDetail(label: label, oldValue: old, newValue: new))
    }

    private nonisolated static func displayValue(_ value: String?) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "空" : trimmed
    }

    private nonisolated static func amountText(_ value: Double?) -> String {
        guard let value else { return "空" }
        if value.rounded() == value {
            return String(Int64(value))
        }
        return String(format: "%.2f", value)
    }

    private nonisolated static func categoryText(_ value: String) -> String {
        value == "debit" ? "储蓄卡" : "信用卡"
    }

    private nonisolated static func maskedCardNumber(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return "空" }
        return "•••• \(digits.suffix(4))"
    }

    private nonisolated static func cardDisplayName(_ card: SharedCard) -> String {
        let bank = displayValue(card.bank)
        let alias = displayValue(card.alias)
        if alias == "空" {
            return "\(bank) / \(maskedCardNumber(card.cardNumber))"
        }
        return "\(bank) / \(alias)"
    }

    private func getBackupList(allowsCellularAccess: Bool) async throws -> [WebDAVBackupFile] {
        try await withCheckedThrowingContinuation { continuation in
            WebDAVClient.shared.getBackupList(allowsCellularAccess: allowsCellularAccess) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func canSkipSnapshotDownload(automaticFiles: [WebDAVBackupFile], forceUpload: Bool) -> Bool {
        guard !forceUpload,
              !ledger.pendingWebDAVUpload,
              let lastFilename = ledger.lastWebDAVSnapshotFilename,
              let newestFilename = automaticFiles.first?.filename else {
            return false
        }
        return newestFilename == lastFilename
    }

    private nonisolated static func downloadSnapshots(
        files: [WebDAVBackupFile],
        syncPassword: String,
        allowsCellularAccess: Bool,
        onProgress: @escaping @Sendable (Int64) -> Void
    ) async -> [WebDAVSyncSnapshotV4] {
        await withTaskGroup(of: WebDAVSyncSnapshotV4?.self, returning: [WebDAVSyncSnapshotV4].self) { group in
            for file in files {
                group.addTask(priority: .utility) {
                    let downloadedForThisFile = ProgressBox(value: 0)
                    let fileProgress: @Sendable (Int64) -> Void = { delta in
                        downloadedForThisFile.value += delta
                        onProgress(delta)
                    }
                    let snapshot = await downloadSnapshot(
                        file: file,
                        syncPassword: syncPassword,
                        allowsCellularAccess: allowsCellularAccess,
                        onProgress: fileProgress
                    )
                    if snapshot != nil {
                        let remaining = file.size - downloadedForThisFile.value
                        if remaining > 0 {
                            onProgress(remaining)
                        }
                    }
                    return snapshot
                }
            }

            var snapshots: [WebDAVSyncSnapshotV4] = []
            for await snapshot in group {
                if let snapshot {
                    snapshots.append(snapshot)
                }
            }
            return snapshots
        }
    }

    private nonisolated static func downloadSnapshot(
        file: WebDAVBackupFile,
        syncPassword: String,
        allowsCellularAccess: Bool,
        onProgress: (@Sendable (Int64) -> Void)? = nil
    ) async -> WebDAVSyncSnapshotV4? {
        do {
            let cipherText = try await withCheckedThrowingContinuation { continuation in
                WebDAVClient.shared.downloadBackup(
                    filename: file.filename,
                    allowsCellularAccess: allowsCellularAccess,
                    onProgress: onProgress
                ) { result in
                    continuation.resume(with: result)
                }
            }
            return try await Self.decodeSnapshot(cipherText: cipherText, syncPassword: syncPassword)
        } catch {
            return nil
        }
    }

    private func uploadConsolidatedSnapshot(
        records: [CardSyncRecord],
        downloadedSnapshots: [WebDAVSyncSnapshotV4],
        listedFiles: [WebDAVBackupFile],
        syncPassword: String,
        snapshotRevision: Int,
        allowsCellularAccess: Bool
    ) async throws -> String {
        let prepared = try await Self.prepareUploadSnapshot(records: records, syncPassword: syncPassword)
        try ensureSyncNotCancelled()
        let uploadSize = Int64(prepared.cipherText.data(using: .utf8)?.count ?? 0)

        let progressBox = ProgressBox()
        updateProgress(
            "上传合并快照",
            step: 5,
            total: 6,
            detail: "正在写入 WebDAV 加密快照",
            totalBytes: uploadSize,
            downloadedBytes: progressBox.value
        )

        try await withCheckedThrowingContinuation { continuation in
            WebDAVClient.shared.uploadBackup(
                filename: prepared.filename,
                cipherText: prepared.cipherText,
                allowsCellularAccess: allowsCellularAccess,
                onProgress: { [weak self] bytesSent in
                    guard let self else { return }
                    DispatchQueue.main.async {
                        progressBox.value = bytesSent
                        self.updateProgress(
                            "上传合并快照",
                            step: 5,
                            total: 6,
                            detail: "正在写入 WebDAV 加密快照",
                            totalBytes: uploadSize,
                            downloadedBytes: progressBox.value
                        )
                    }
                }
            ) { result in
                continuation.resume(with: result)
            }
        }

        updateProgress(
            "上传合并快照",
            step: 5,
            total: 6,
            detail: "正在写入 WebDAV 加密快照",
            totalBytes: uploadSize,
            downloadedBytes: uploadSize
        )

        try ensureSyncNotCancelled()
        ledger.records = CardSyncMergeEngine.merge([ledger.records, records])
        ledger.processedWebDAVSnapshotIDs.formUnion(downloadedSnapshots.map(\.snapshotId))
        ledger.processedWebDAVSnapshotIDs.insert(prepared.snapshot.snapshotId)
        ledger.lastWebDAVSnapshotFilename = prepared.filename
        ledger.pendingWebDAVUpload = localRevision != snapshotRevision
        SyncLedgerStore.shared.saveInBackground(ledger)
        persistActiveCards()
        print("[SyncCoordinator] 已上传 WebDAV 快照: \(prepared.filename), pending=\(ledger.pendingWebDAVUpload)")
        return prepared.filename
    }

    private func recordProcessedSnapshots(
        _ snapshots: [WebDAVSyncSnapshotV4],
        newestFilename: String?,
        snapshotRevision: Int,
        allowUpdatingLastFilename: Bool = false
    ) {
        ledger.processedWebDAVSnapshotIDs.formUnion(snapshots.map(\.snapshotId))
        // 通常不在此处更新 lastWebDAVSnapshotFilename：
        // 该字段优先记录本机上传成功后的文件名。只有空本地首次恢复单个最新
        // 快照时可以记录远端文件名，避免下一次同步重复下载同一份快照。
        if allowUpdatingLastFilename {
            ledger.lastWebDAVSnapshotFilename = newestFilename
        }
        if localRevision == snapshotRevision {
            ledger.pendingWebDAVUpload = false
        } else {
            ledger.pendingWebDAVUpload = true
            queuedForceUpload = true
            print("[SyncCoordinator] 同步期间检测到本机新修改，保留待上传状态")
        }
        SyncLedgerStore.shared.saveInBackground(ledger)
    }

    private nonisolated static func decodeSnapshot(cipherText: String, syncPassword: String) async throws -> WebDAVSyncSnapshotV4? {
        try await Task.detached(priority: .utility) {
            let json = try CryptoManager.decryptSyncEnvelopeV4(envelopeText: cipherText, password: syncPassword)
            guard let data = json.data(using: .utf8),
                  let snapshot = try? JSONDecoder().decode(WebDAVSyncSnapshotV4.self, from: data),
                  snapshot.schemaVersion == WebDAVSyncSnapshotV4.schemaVersion else {
                return nil
            }
            return snapshot
        }.value
    }

    private nonisolated static func prepareMerge(localRecords: [CardSyncRecord], remoteRecords: [CardSyncRecord]) async -> PreparedSyncMerge {
        await Task.detached(priority: .utility) {
            let mergedRecords = CardSyncMergeEngine.merge([localRecords, remoteRecords])
            let localMergedRecords = CardSyncMergeEngine.merge([localRecords])
            return PreparedSyncMerge(mergedRecords: mergedRecords, changedByRemote: mergedRecords != localMergedRecords)
        }.value
    }

    private nonisolated static func activeCards(from records: [CardSyncRecord]) async -> [SharedCard] {
        await Task.detached(priority: .utility) {
            CardSyncMergeEngine.activeCards(from: records)
        }.value
    }

    private nonisolated static func writeLocalCards(_ cards: [SharedCard]) async {
        await Task.detached(priority: .utility) {
            _ = LocalStorageManager.write(cards: cards)
        }.value
    }

    private nonisolated static func prepareUploadSnapshot(records: [CardSyncRecord], syncPassword: String) async throws -> PreparedWebDAVUpload {
        try await Task.detached(priority: .utility) {
            let snapshot = WebDAVSyncSnapshotV4(source: "ios", records: records)
            let data = try JSONEncoder().encode(snapshot)
            guard let json = String(data: data, encoding: .utf8) else { throw WebDAVError.xmlParsingFailed }
            let cipherText = try CryptoManager.encryptSyncEnvelopeV4(plainText: json, password: syncPassword)
            let filename = syncSnapshotFilename(recordCount: CardSyncMergeEngine.activeCards(from: records).count)
            return PreparedWebDAVUpload(snapshot: snapshot, cipherText: cipherText, filename: filename)
        }.value
    }

    private nonisolated static func syncSnapshotFilename(recordCount: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // 统一使用 UTC，与 Web/Android 端文件名格式一致，避免多端排序歧义
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss-SSS'Z'"
        return "\(formatter.string(from: Date()))---(\(recordCount))[SyncV4][iOS][自].json"
    }

    private func pruneAutomaticSnapshots(from files: [WebDAVBackupFile]) {
        guard !isSuspended, !cancelRequested else { return }
        let automaticFiles = files
            .filter { $0.filename.contains("[SyncV4]") && $0.filename.contains("[自]") }
            .sorted {
                let leftDate = $0.lastModifiedDate ?? .distantPast
                let rightDate = $1.lastModifiedDate ?? .distantPast
                if leftDate != rightDate { return leftDate > rightDate }
                return $0.filename > $1.filename
            }
        guard automaticFiles.count > 5 else { return }
        for file in automaticFiles.dropFirst(5) {
            WebDAVClient.shared.deleteBackup(filename: file.filename) { _ in }
        }
    }

    private func startSyncTiming() {
        syncStartedAt = Date()
        syncElapsedSeconds = 0
        lastSyncDurationSeconds = nil
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.syncStartedAt else { return }
                self.syncElapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
            }
        }
    }

    private func currentSyncDuration() -> TimeInterval {
        syncStartedAt.map { max(0, Date().timeIntervalSince($0)) } ?? syncElapsedSeconds
    }

    @discardableResult
    private func finishSyncTiming() -> TimeInterval {
        let duration = currentSyncDuration()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        syncStartedAt = nil
        syncElapsedSeconds = 0
        lastSyncDurationSeconds = duration
        return duration
    }

    private func finishSync(success: Bool, message: String) {
        finishSync(status: success ? .success : .failure(message), markSuccess: success)
    }

    private func finishSync(status: SyncStatus, markSuccess: Bool, continueQueued: Bool = true) {
        let duration = finishSyncTiming()
        isSynchronizing = false
        syncStatus = status
        if markSuccess {
            let now = Date()
            lastSyncAt = now
            persistLastSyncMetadata(date: now, duration: duration)
        }

        let shouldContinue = !isSuspended && markSuccess && continueQueued && (queuedForceUpload || ledger.pendingWebDAVUpload)
        let shouldContinueOnCellular = queuedCellularOverride || activeCellularOverride
        queuedForceUpload = false
        queuedCellularOverride = false
        activeCellularOverride = false
        cancelRequested = false
        if shouldContinue {
            let trigger: SyncTrigger = shouldContinueOnCellular
                ? .manual(cellularConfirmed: true)
                : .automatic
            Task { await synchronize(forceUpload: true, trigger: trigger) }
        }
    }

    private func restoreLastSyncMetadata() {
        let timestamp = UserDefaults.standard.double(forKey: Self.lastSyncAtKey)
        if timestamp > 0 {
            lastSyncAt = Date(timeIntervalSince1970: timestamp / 1000)
        }
        let duration = UserDefaults.standard.double(forKey: Self.lastSyncDurationKey)
        if duration > 0 {
            lastSyncDurationSeconds = duration
        }
    }

    private func persistLastSyncMetadata(date: Date, duration: TimeInterval) {
        UserDefaults.standard.set(date.timeIntervalSince1970 * 1000, forKey: Self.lastSyncAtKey)
        UserDefaults.standard.set(duration, forKey: Self.lastSyncDurationKey)
    }
}
