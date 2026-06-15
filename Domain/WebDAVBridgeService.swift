import Foundation
import SwiftUI

private final class ProgressBox: @unchecked Sendable {
    var value: Int64 = 0
}

private final class ProgressTimeBox: @unchecked Sendable {
    var value: TimeInterval = 0
}

public struct SyncFileProgress: Codable, Hashable {
    public var phase: String
    public var step: Int
    public var total: Int
    public var detail: String
    public var totalBytes: Int64?
    public var transferredBytes: Int64?

    public init(
        phase: String = "空闲",
        step: Int = 0,
        total: Int = 0,
        detail: String = "",
        totalBytes: Int64? = nil,
        transferredBytes: Int64? = nil
    ) {
        self.phase = phase
        self.step = step
        self.total = total
        self.detail = detail
        self.totalBytes = totalBytes
        self.transferredBytes = transferredBytes
    }
}

public struct SyncFieldChangeDetail: Codable, Hashable, Identifiable {
    public var id: String { "\(label)-\(oldValue)-\(newValue)" }
    public var label: String
    public var oldValue: String
    public var newValue: String
}

public struct SyncCardChangeDetail: Codable, Hashable, Identifiable {
    public var id: String { "\(kind)-\(cardId)" }
    public var kind: String
    public var cardId: String
    public var cardName: String
    public var fields: [SyncFieldChangeDetail]
}

public struct SyncHistoryEntry: Codable, Hashable, Identifiable {
    public var id: String
    public var startedAt: Date
    public var finishedAt: Date
    public var status: String
    public var message: String
    public var durationSeconds: TimeInterval
    public var uploadedFile: String?
    public var downloadedFiles: [String]
    public var localChanges: [SyncCardChangeDetail]
    public var remoteChanges: [SyncCardChangeDetail]
}

public final class WebDAVBridgeService: ObservableObject {
    public static let shared = WebDAVBridgeService()

    @Published public private(set) var statusDescription = "云同步还未设置"
    @Published public private(set) var lastConvergenceAt: Date?
    @Published public private(set) var isSyncing = false
    @Published public private(set) var syncElapsedSeconds: TimeInterval = 0
    @Published public private(set) var lastSyncDurationSeconds: TimeInterval?
    @Published public private(set) var syncProgress = SyncFileProgress()
    @Published public private(set) var syncHistory: [SyncHistoryEntry]

    private var timer: Timer?
    private var elapsedTimer: Timer?
    private var syncStartedAt: Date?
    private var recordsProvider: (() -> [CardSyncRecord])?
    private var onMergedRecords: (([CardSyncRecord]) -> Void)?
    private var queuedForceUpload = false
    private let syncPasswordKey = "webdav_sync_password_v4"
    private static let syncHistoryKey = "webdav_bridge_sync_history_v1"
    private static let progressUIUpdateInterval: TimeInterval = 0.25

    public var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "enable_webdav_bridge") as? Bool ?? true
    }

    private init() {
        syncHistory = WebDAVBridgeService.loadSyncHistory()
    }

    public func configure(
        recordsProvider: @escaping () -> [CardSyncRecord],
        onMergedRecords: @escaping ([CardSyncRecord]) -> Void
    ) {
        self.recordsProvider = recordsProvider
        self.onMergedRecords = onMergedRecords
        if isEnabled {
            start()
        }
    }

    public func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "enable_webdav_bridge")
        if enabled {
            start()
        } else {
            stop()
            statusDescription = "云端同步已关闭"
        }
    }

    public func start() {
        stop()
        guard isEnabled, !AutoLockManager.shared.isLocked else { return }
        let configuredInterval = UserDefaults.standard.double(forKey: "auto_check_interval")
        let interval = configuredInterval > 0 ? configuredInterval : 300
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.synchronize(forceUpload: false)
        }
        synchronize(forceUpload: false)
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func synchronize(forceUpload: Bool) {
        guard isEnabled, !AutoLockManager.shared.isLocked else { return }
        if isSyncing {
            if forceUpload {
                queuedForceUpload = true
                statusDescription = "当前修改会在本次同步结束后继续上传"
            }
            return
        }
        guard WebDAVClient.shared.loadConfig() != nil else {
            statusDescription = "云同步还未设置"
            return
        }
        guard loadSyncPassword() != nil else {
            statusDescription = "请先在 WebDAV 设置中填写同步密钥"
            return
        }
        isSyncing = true
        startSyncTiming()
        updateProgress("读取云端", step: 1, total: 5, detail: "正在获取 WebDAV 同步文件列表")
        statusDescription = "正在检查云端同步数据..."
        WebDAVClient.shared.getBackupList { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.completeWithError("云端读取失败：\(error.localizedDescription)")
                case .success(let files):
                    self.downloadAndMerge(files: files, forceUpload: forceUpload)
                }
            }
        }
    }

    private func loadSyncPassword() -> String? {
        let value = KeychainManager.load(key: syncPasswordKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private func downloadAndMerge(files: [WebDAVBackupFile], forceUpload: Bool) {
        guard let syncPassword = loadSyncPassword() else {
            completeWithError("请先在 WebDAV 设置中填写同步密钥")
            return
        }
        let automaticFiles = files
            .filter { $0.filename.contains("[SyncV4]") && $0.filename.contains("[自]") }
            .sorted {
                if $0.lastModified != $1.lastModified {
                    return $0.lastModified > $1.lastModified
                }
                return $0.filename > $1.filename
            }
        let filesToRead = Array(automaticFiles.prefix(5))
        var ledger = SyncLedgerStore.shared.load()
        let hasPendingUpload = ledger.pendingWebDAVUpload
        let newestFilename = automaticFiles.first?.filename ?? ""
        let startedAt = syncStartedAt ?? Date()
        guard !automaticFiles.isEmpty else {
            if forceUpload || hasPendingUpload {
                uploadConsolidatedSnapshot(records: recordsProvider?() ?? [], downloadedSnapshots: [], listedFiles: files)
            } else {
                let duration = finishSyncTiming()
                isSyncing = false
                statusDescription = "云端还没有新版同步文件，可点击“立即同步”用当前本机数据初始化云同步"
                updateProgress("等待初始化", step: 0, total: 0, detail: statusDescription)
                appendSyncHistory(
                    status: "warning",
                    message: "云端还没有同步文件",
                    startedAt: startedAt,
                    uploadedFile: nil,
                    downloadedFiles: [],
                    localChanges: [],
                    remoteChanges: [],
                    duration: duration
                )
                runQueuedForceUploadIfNeeded()
            }
            return
        }

        if !hasPendingUpload, !newestFilename.isEmpty, newestFilename == ledger.lastWebDAVSnapshotFilename {
            let duration = finishSyncTiming()
            isSyncing = false
            lastConvergenceAt = Date()
            statusDescription = "云端文件未变化，已跳过下载解析"
            updateProgress("同步完成", step: 5, total: 5, detail: statusDescription)
            appendSyncHistory(
                status: "success",
                message: statusDescription,
                startedAt: startedAt,
                uploadedFile: nil,
                downloadedFiles: [],
                localChanges: [],
                remoteChanges: [],
                duration: duration
            )
            runQueuedForceUploadIfNeeded()
            return
        }

        let totalBytes = filesToRead.reduce(Int64(0)) { $0 + max(0, $1.size) }
        let progressBox = ProgressBox()
        let progressTimeBox = ProgressTimeBox()
        let progressLock = NSLock()
        let reportDownloadProgress: (Int64, Bool) -> Void = { [weak self] delta, force in
            guard delta > 0 else { return }
            let now = Date().timeIntervalSinceReferenceDate
            progressLock.lock()
            progressBox.value = min(totalBytes, progressBox.value + delta)
            let currentBytes = progressBox.value
            let shouldReport = force ||
                currentBytes >= totalBytes ||
                now - progressTimeBox.value >= Self.progressUIUpdateInterval
            if shouldReport {
                progressTimeBox.value = now
            }
            progressLock.unlock()
            guard shouldReport else { return }
            DispatchQueue.main.async {
                self?.updateProgress(
                    "读取文件",
                    step: 2,
                    total: 5,
                    detail: "正在下载并解密最近 \(filesToRead.count) 个同步快照",
                    totalBytes: totalBytes,
                    transferredBytes: currentBytes
                )
            }
        }

        updateProgress(
            "读取文件",
            step: 2,
            total: 5,
            detail: "正在下载并解密最近 \(filesToRead.count) 个同步快照",
            totalBytes: totalBytes,
            transferredBytes: 0
        )
        let group = DispatchGroup()
        let lock = NSLock()
        var snapshots: [WebDAVSyncSnapshotV4] = []
        for file in filesToRead {
            group.enter()
            let fileProgressBox = ProgressBox()
            let fileProgressLock = NSLock()
            WebDAVClient.shared.downloadBackup(
                filename: file.filename,
                onProgress: { delta in
                    fileProgressLock.lock()
                    fileProgressBox.value += delta
                    fileProgressLock.unlock()
                    reportDownloadProgress(delta, false)
                }
            ) { result in
                defer { group.leave() }
                guard case .success(let cipherText) = result,
                      let json = try? CryptoManager.decryptSyncEnvelopeV4(envelopeText: cipherText, password: syncPassword),
                      let data = json.data(using: .utf8),
                      let snapshot = try? JSONDecoder().decode(WebDAVSyncSnapshotV4.self, from: data),
                      snapshot.schemaVersion == WebDAVSyncSnapshotV4.schemaVersion else {
                    return
                }
                fileProgressLock.lock()
                let remaining = file.size - fileProgressBox.value
                fileProgressLock.unlock()
                if remaining > 0 {
                    reportDownloadProgress(remaining, true)
                }
                lock.lock()
                snapshots.append(snapshot)
                lock.unlock()
            }
        }
        group.notify(queue: .main) {
            if !filesToRead.isEmpty && snapshots.isEmpty {
                self.completeWithError("无法解密云端同步文件，请检查同步密钥")
                return
            }
            self.updateProgress("合并数据", step: 3, total: 5, detail: "正在合并本机与云端修改")
            let localRecords = self.recordsProvider?() ?? []
            let activeBefore = CardSyncMergeEngine.activeCards(from: localRecords)
            let remoteRecords = snapshots.flatMap(\.records)
            let mergedRecords = CardSyncMergeEngine.merge([localRecords, remoteRecords])
            let hasChange = mergedRecords != CardSyncMergeEngine.merge([localRecords])
            if hasChange {
                self.onMergedRecords?(mergedRecords)
            }
            ledger = SyncLedgerStore.shared.load()
            let hasPendingUpload = ledger.pendingWebDAVUpload
            let activeAfter = CardSyncMergeEngine.activeCards(from: mergedRecords)
            let remoteChanges = hasChange ? Self.diffCards(before: activeBefore, after: activeAfter) : []
            let localChanges = Self.recentLocalChanges(records: localRecords, since: Self.snapshotDate(fromFilename: ledger.lastWebDAVSnapshotFilename ?? ""))
            if hasChange || hasPendingUpload {
                self.updateProgress("保存云端", step: 4, total: 5, detail: "正在上传合并后的加密快照")
                self.uploadConsolidatedSnapshot(
                    records: mergedRecords,
                    downloadedSnapshots: snapshots,
                    listedFiles: files,
                    startedAt: startedAt,
                    downloadedFiles: filesToRead.map(\.filename),
                    localChanges: localChanges,
                    remoteChanges: remoteChanges
                )
            } else {
                ledger.lastWebDAVSnapshotFilename = newestFilename
                SyncLedgerStore.shared.save(ledger)
                let duration = self.finishSyncTiming()
                self.isSyncing = false
                self.statusDescription = "云端与本机已同步"
                self.lastConvergenceAt = Date()
                self.updateProgress("同步完成", step: 5, total: 5, detail: self.statusDescription)
                self.appendSyncHistory(
                    status: "success",
                    message: self.statusDescription,
                    startedAt: startedAt,
                    uploadedFile: nil,
                    downloadedFiles: filesToRead.map(\.filename),
                    localChanges: localChanges,
                    remoteChanges: remoteChanges,
                    duration: duration
                )
                self.runQueuedForceUploadIfNeeded()
            }
        }
    }

    private func uploadConsolidatedSnapshot(
        records: [CardSyncRecord],
        downloadedSnapshots: [WebDAVSyncSnapshotV4],
        listedFiles: [WebDAVBackupFile],
        startedAt: Date? = nil,
        downloadedFiles: [String] = [],
        localChanges: [SyncCardChangeDetail] = [],
        remoteChanges: [SyncCardChangeDetail] = []
    ) {
        let syncStarted = startedAt ?? syncStartedAt ?? Date()
        guard let syncPassword = loadSyncPassword() else {
            completeWithError("请先在 WebDAV 设置中填写同步密钥")
            return
        }
        let snapshot = WebDAVSyncSnapshotV4(source: "macos", records: records)
        guard let data = try? JSONEncoder().encode(snapshot),
              let json = String(data: data, encoding: .utf8),
              let cipherText = try? CryptoManager.encryptSyncEnvelopeV4(plainText: json, password: syncPassword) else {
            completeWithError("同步数据准备失败")
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
        let filename = "\(formatter.string(from: Date()))---(\(CardSyncMergeEngine.activeCards(from: records).count))[SyncV4][Mac][自].json"
        let uploadSize = Int64(cipherText.data(using: .utf8)?.count ?? 0)
        updateProgress(
            "保存云端",
            step: 4,
            total: 5,
            detail: "正在上传合并后的加密快照",
            totalBytes: uploadSize,
            transferredBytes: 0
        )
        let uploadProgressTimeBox = ProgressTimeBox()
        WebDAVClient.shared.uploadBackup(
            filename: filename,
            cipherText: cipherText,
            onProgress: { [weak self] bytesSent in
                let currentBytes = min(uploadSize, max(0, bytesSent))
                let now = Date().timeIntervalSinceReferenceDate
                guard currentBytes >= uploadSize || now - uploadProgressTimeBox.value >= Self.progressUIUpdateInterval else {
                    return
                }
                uploadProgressTimeBox.value = now
                DispatchQueue.main.async {
                    self?.updateProgress(
                        "保存云端",
                        step: 4,
                        total: 5,
                        detail: "正在上传合并后的加密快照",
                        totalBytes: uploadSize,
                        transferredBytes: currentBytes
                    )
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.completeWithError("云端写入失败，将重试：\(error.localizedDescription)")
                case .success:
                    var ledger = SyncLedgerStore.shared.load()
                    let latestRecords = CardSyncMergeEngine.merge([ledger.records, records])
                    ledger.records = latestRecords
                    ledger.processedWebDAVSnapshotIDs.formUnion(downloadedSnapshots.map(\.snapshotId))
                    ledger.processedWebDAVSnapshotIDs.insert(snapshot.snapshotId)
                    ledger.lastWebDAVSnapshotFilename = filename
                    ledger.pendingWebDAVUpload = latestRecords != CardSyncMergeEngine.merge([records])
                    SyncLedgerStore.shared.save(ledger)
                    self.lastConvergenceAt = Date()
                    let duration = self.finishSyncTiming()
                    self.statusDescription = ledger.pendingWebDAVUpload ? "本机有新修改，正在继续同步" : "云端与本机已同步"
                    self.updateProgress(
                        "同步完成",
                        step: 5,
                        total: 5,
                        detail: self.statusDescription,
                        totalBytes: uploadSize,
                        transferredBytes: uploadSize
                    )
                    self.isSyncing = false
                    self.appendSyncHistory(
                        status: "success",
                        message: self.statusDescription,
                        startedAt: syncStarted,
                        uploadedFile: filename,
                        downloadedFiles: downloadedFiles,
                        localChanges: localChanges,
                        remoteChanges: remoteChanges,
                        duration: duration
                    )
                    NotificationCenter.default.post(name: Notification.Name("CloudBackupsDidChange"), object: nil)
                    self.pruneAutomaticSnapshots(from: listedFiles + [
                        WebDAVBackupFile(filename: filename, size: 0, lastModified: SyncTimestamp.now())
                    ])
                    self.runQueuedForceUploadIfNeeded()
                }
            }
        }
    }

    private func pruneAutomaticSnapshots(from files: [WebDAVBackupFile]) {
        let automaticFiles = files
            .filter { $0.filename.contains("[SyncV4]") && $0.filename.contains("[自]") }
            .sorted {
                if $0.lastModified != $1.lastModified {
                    return $0.lastModified > $1.lastModified
                }
                return $0.filename > $1.filename
            }
        guard automaticFiles.count > 5 else { return }
        automaticFiles.dropFirst(5).forEach { file in
            WebDAVClient.shared.deleteBackup(filename: file.filename) { _ in }
        }
    }

    private func completeWithError(_ message: String) {
        let startedAt = syncStartedAt ?? Date()
        let duration = finishSyncTiming()
        isSyncing = false
        queuedForceUpload = false
        statusDescription = message
        updateProgress("同步失败", step: 0, total: 0, detail: message)
        appendSyncHistory(
            status: "error",
            message: message,
            startedAt: startedAt,
            uploadedFile: nil,
            downloadedFiles: [],
            localChanges: [],
            remoteChanges: [],
            duration: duration
        )
    }

    private func updateProgress(
        _ phase: String,
        step: Int,
        total: Int,
        detail: String = "",
        totalBytes: Int64? = nil,
        transferredBytes: Int64? = nil
    ) {
        syncProgress = SyncFileProgress(
            phase: phase,
            step: step,
            total: total,
            detail: detail,
            totalBytes: totalBytes,
            transferredBytes: transferredBytes
        )
    }

    private static func loadSyncHistory() -> [SyncHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: syncHistoryKey),
              let entries = try? JSONDecoder().decode([SyncHistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveSyncHistory() {
        guard let data = try? JSONEncoder().encode(syncHistory) else { return }
        UserDefaults.standard.set(data, forKey: Self.syncHistoryKey)
    }

    private func appendSyncHistory(
        status: String,
        message: String,
        startedAt: Date,
        uploadedFile: String?,
        downloadedFiles: [String],
        localChanges: [SyncCardChangeDetail],
        remoteChanges: [SyncCardChangeDetail],
        duration: TimeInterval
    ) {
        let finishedAt = Date()
        let entry = SyncHistoryEntry(
            id: UUID().uuidString,
            startedAt: startedAt,
            finishedAt: finishedAt,
            status: status,
            message: message,
            durationSeconds: max(0, duration),
            uploadedFile: uploadedFile,
            downloadedFiles: downloadedFiles,
            localChanges: Array(localChanges.prefix(30)),
            remoteChanges: Array(remoteChanges.prefix(30))
        )
        syncHistory = Array(([entry] + syncHistory).prefix(40))
        saveSyncHistory()
    }

    private static func diffCards(before: [SharedCard], after: [SharedCard]) -> [SyncCardChangeDetail] {
        let beforeById = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0) })
        let afterById = Dictionary(uniqueKeysWithValues: after.map { ($0.id, $0) })
        let cardIds = Array(Set(beforeById.keys).union(afterById.keys)).sorted()

        return cardIds.compactMap { cardId in
            let oldCard = beforeById[cardId]
            let newCard = afterById[cardId]
            if oldCard == nil, let newCard {
                return buildCardChange(kind: "added", before: nil, after: newCard)
            }
            if let oldCard, newCard == nil {
                return buildCardChange(kind: "deleted", before: oldCard, after: nil)
            }
            if let oldCard, let newCard {
                return buildCardChange(kind: "modified", before: oldCard, after: newCard)
            }
            return nil
        }
    }

    private static func recentLocalChanges(records: [CardSyncRecord], since date: Date?) -> [SyncCardChangeDetail] {
        let cutoff = date ?? .distantPast
        return CardSyncMergeEngine.merge([records]).compactMap { record in
            guard let changedAt = SyncTimestamp.date(from: record.changedAt), changedAt > cutoff else {
                return nil
            }
            switch record.state {
            case .deleted:
                return SyncCardChangeDetail(
                    kind: "deleted",
                    cardId: record.cardId,
                    cardName: record.cardId,
                    fields: [
                        SyncFieldChangeDetail(label: "状态", oldValue: "已存在", newValue: "已删除")
                    ]
                )
            case .active:
                guard let card = record.card else { return nil }
                return SyncCardChangeDetail(
                    kind: "modified",
                    cardId: card.id,
                    cardName: cardDisplayName(card),
                    fields: snapshotFields(card, isNew: true)
                )
            }
        }
        .sorted { $0.cardName.localizedStandardCompare($1.cardName) == .orderedAscending }
    }

    private static func snapshotDate(fromFilename filename: String) -> Date? {
        guard let prefix = filename.split(separator: "---", maxSplits: 1).first else {
            return nil
        }
        let raw = String(prefix)
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
        if let date = localFormatter.date(from: raw) {
            return date
        }

        let utcFormatter = DateFormatter()
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        utcFormatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss-SSS'Z'"
        if let date = utcFormatter.date(from: raw) {
            return date
        }

        return SyncTimestamp.date(from: raw)
    }

    private static func buildCardChange(kind: String, before: SharedCard?, after: SharedCard?) -> SyncCardChangeDetail? {
        guard let card = after ?? before else { return nil }
        let fields: [SyncFieldChangeDetail]
        switch kind {
        case "added":
            fields = snapshotFields(card, isNew: true)
        case "deleted":
            fields = [
                SyncFieldChangeDetail(label: "状态", oldValue: "已存在", newValue: "已删除")
            ]
        default:
            guard let before, let after else { return nil }
            fields = fieldChanges(before: before, after: after)
        }
        guard kind != "modified" || !fields.isEmpty else { return nil }
        return SyncCardChangeDetail(
            kind: kind,
            cardId: card.id,
            cardName: cardDisplayName(card),
            fields: fields
        )
    }

    private static func snapshotFields(_ card: SharedCard, isNew: Bool) -> [SyncFieldChangeDetail] {
        let values: [(String, String)] = [
            ("卡类别", categoryText(card.cardCategory)),
            ("国家 / 地区", displayValue(card.country)),
            ("发卡银行", displayValue(card.bank)),
            ("卡片别名", displayValue(card.alias)),
            ("卡片等级", displayValue(card.level)),
            ("卡号", maskCardNumber(card.cardNumber)),
            ("有效期", displayValue(card.valid)),
            ("额度", amountText(card.limit, currency: card.type)),
            ("结算币种", displayValue(card.type)),
            ("共享额度", card.isSharedLimit ? "是" : "否"),
            ("账单日", displayValue(card.accountBillDate)),
            ("还款日", displayValue(card.dueDate)),
            ("账单日消费计入", card.billingDaySpendingToNextBill ? "下期账单" : "当期账单"),
            ("年费金额", amountText(card.annualFee, currency: card.type)),
            ("年费状态", qualificationText(card.isQualified)),
            ("下次年费收取日", dateText(card.nextAnnualFeeCollectionTime)),
            ("上次提额时间", dateText(card.lastTime)),
            ("权益", displayValue(card.equity)),
            ("备注", displayValue(card.remark)),
            ("卡片图片", card.cardImages.isEmpty ? "未设置" : "\(card.cardImages.count) 张")
        ]

        return values.compactMap { label, value in
            guard value != "未设置" else { return nil }
            return SyncFieldChangeDetail(
                label: label,
                oldValue: isNew ? "" : value,
                newValue: isNew ? value : ""
            )
        }
    }

    private static func fieldChanges(before: SharedCard, after: SharedCard) -> [SyncFieldChangeDetail] {
        var fields: [SyncFieldChangeDetail] = []
        appendFieldChange(&fields, label: "卡类别", oldValue: categoryText(before.cardCategory), newValue: categoryText(after.cardCategory))
        appendFieldChange(&fields, label: "国家 / 地区", oldValue: before.country, newValue: after.country)
        appendFieldChange(&fields, label: "发卡银行", oldValue: before.bank, newValue: after.bank)
        appendFieldChange(&fields, label: "卡片别名", oldValue: before.alias, newValue: after.alias)
        appendFieldChange(&fields, label: "卡片等级", oldValue: before.level, newValue: after.level)
        appendFieldChange(&fields, label: "卡号", oldValue: maskCardNumber(before.cardNumber), newValue: maskCardNumber(after.cardNumber))
        appendFieldChange(&fields, label: "有效期", oldValue: before.valid, newValue: after.valid)
        appendFieldChange(&fields, label: "额度", oldValue: amountText(before.limit, currency: before.type), newValue: amountText(after.limit, currency: after.type))
        appendFieldChange(&fields, label: "结算币种", oldValue: before.type, newValue: after.type)
        appendFieldChange(&fields, label: "共享额度", oldValue: before.isSharedLimit ? "是" : "否", newValue: after.isSharedLimit ? "是" : "否")
        appendFieldChange(&fields, label: "账单日", oldValue: before.accountBillDate, newValue: after.accountBillDate)
        appendFieldChange(&fields, label: "还款日", oldValue: before.dueDate, newValue: after.dueDate)
        appendFieldChange(&fields, label: "账单日消费计入", oldValue: before.billingDaySpendingToNextBill ? "下期账单" : "当期账单", newValue: after.billingDaySpendingToNextBill ? "下期账单" : "当期账单")
        appendFieldChange(&fields, label: "年费金额", oldValue: amountText(before.annualFee, currency: before.type), newValue: amountText(after.annualFee, currency: after.type))
        appendFieldChange(&fields, label: "年费状态", oldValue: qualificationText(before.isQualified), newValue: qualificationText(after.isQualified))
        appendFieldChange(&fields, label: "下次年费收取日", oldValue: dateText(before.nextAnnualFeeCollectionTime), newValue: dateText(after.nextAnnualFeeCollectionTime))
        appendFieldChange(&fields, label: "上次提额时间", oldValue: dateText(before.lastTime), newValue: dateText(after.lastTime))
        appendFieldChange(&fields, label: "权益", oldValue: before.equity, newValue: after.equity)
        appendFieldChange(&fields, label: "备注", oldValue: before.remark, newValue: after.remark)
        appendFieldChange(&fields, label: "卡片图片", oldValue: before.cardImages.isEmpty ? "未设置" : "\(before.cardImages.count) 张", newValue: after.cardImages.isEmpty ? "未设置" : "\(after.cardImages.count) 张")
        return Array(fields.prefix(20))
    }

    private static func appendFieldChange(_ fields: inout [SyncFieldChangeDetail], label: String, oldValue: String?, newValue: String?) {
        let oldText = displayValue(oldValue)
        let newText = displayValue(newValue)
        guard oldText != newText else { return }
        fields.append(SyncFieldChangeDetail(label: label, oldValue: oldText, newValue: newText))
    }

    private static func cardDisplayName(_ card: SharedCard) -> String {
        let bank = displayValue(card.bank)
        let alias = displayValue(card.alias)
        let number = maskCardNumber(card.cardNumber)
        return [bank, alias, number]
            .filter { !$0.isEmpty && $0 != "未设置" }
            .joined(separator: " / ")
    }

    private static func displayValue(_ value: String?) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未设置" : trimmed
    }

    private static func categoryText(_ value: String) -> String {
        value == "debit" ? "储蓄卡" : "信用卡"
    }

    private static func maskCardNumber(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return "未设置" }
        return "•••• \(digits.suffix(4))"
    }

    private static func amountText(_ value: Double?, currency: String?) -> String {
        guard let value else { return "未设置" }
        let amount: String
        if value.rounded() == value {
            amount = String(Int(value))
        } else {
            amount = String(format: "%.2f", value)
        }
        let currencyText = displayValue(currency)
        return currencyText == "未设置" ? amount : "\(currencyText) \(amount)"
    }

    private static func qualificationText(_ value: String?) -> String {
        switch value {
        case "1":
            return "已达标"
        case "3":
            return "终免年费"
        default:
            return "未达标"
        }
    }

    private static func dateText(_ timestamp: Double?) -> String {
        guard let timestamp, timestamp > 0,
              let date = DataMigrationManager.date(fromTimestamp: timestamp) else {
            return "未设置"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func startSyncTiming() {
        syncStartedAt = Date()
        syncElapsedSeconds = 0
        lastSyncDurationSeconds = nil
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.syncStartedAt else { return }
            self.syncElapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
        }
    }

    @discardableResult
    private func finishSyncTiming() -> TimeInterval {
        let duration = syncStartedAt.map { max(0, Date().timeIntervalSince($0)) } ?? syncElapsedSeconds
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        syncStartedAt = nil
        syncElapsedSeconds = 0
        lastSyncDurationSeconds = duration
        return duration
    }

    private func runQueuedForceUploadIfNeeded() {
        guard queuedForceUpload else { return }
        queuedForceUpload = false
        DispatchQueue.main.async { [weak self] in
            self?.synchronize(forceUpload: true)
        }
    }
}
