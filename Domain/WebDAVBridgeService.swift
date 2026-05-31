import Foundation
import SwiftUI

public final class WebDAVBridgeService: ObservableObject {
    public static let shared = WebDAVBridgeService()

    @Published public private(set) var statusDescription = "云同步还未设置"
    @Published public private(set) var lastConvergenceAt: Date?
    @Published public private(set) var isSyncing = false
    @Published public private(set) var syncElapsedSeconds: TimeInterval = 0
    @Published public private(set) var lastSyncDurationSeconds: TimeInterval?

    private var timer: Timer?
    private var elapsedTimer: Timer?
    private var syncStartedAt: Date?
    private var recordsProvider: (() -> [CardSyncRecord])?
    private var onMergedRecords: (([CardSyncRecord]) -> Void)?
    private var queuedForceUpload = false
    private let syncPasswordKey = "webdav_sync_password_v4"

    public var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "enable_webdav_bridge") as? Bool ?? true
    }

    private init() {}

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
            .sorted { $0.filename > $1.filename }
        let filesToRead = Array(automaticFiles.prefix(5))
        let hasPendingUpload = SyncLedgerStore.shared.load().pendingWebDAVUpload
        guard !automaticFiles.isEmpty else {
            if forceUpload || hasPendingUpload {
                uploadConsolidatedSnapshot(records: recordsProvider?() ?? [], downloadedSnapshots: [], listedFiles: files)
            } else {
                finishSyncTiming()
                isSyncing = false
                statusDescription = "云端还没有新版同步文件，可点击“立即同步”用当前本机数据初始化云同步"
                runQueuedForceUploadIfNeeded()
            }
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var snapshots: [WebDAVSyncSnapshotV4] = []
        for file in filesToRead {
            group.enter()
            WebDAVClient.shared.downloadBackup(filename: file.filename) { result in
                defer { group.leave() }
                guard case .success(let cipherText) = result,
                      let json = try? CryptoManager.decryptSyncEnvelopeV4(envelopeText: cipherText, password: syncPassword),
                      let data = json.data(using: .utf8),
                      let snapshot = try? JSONDecoder().decode(WebDAVSyncSnapshotV4.self, from: data),
                      snapshot.schemaVersion == WebDAVSyncSnapshotV4.schemaVersion else {
                    return
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
            let localRecords = self.recordsProvider?() ?? []
            let remoteRecords = snapshots.flatMap(\.records)
            let mergedRecords = CardSyncMergeEngine.merge([localRecords, remoteRecords])
            let hasChange = mergedRecords != CardSyncMergeEngine.merge([localRecords])
            if hasChange {
                self.onMergedRecords?(mergedRecords)
            }
            let hasPendingUpload = SyncLedgerStore.shared.load().pendingWebDAVUpload
            if forceUpload || hasChange || hasPendingUpload {
                self.uploadConsolidatedSnapshot(records: mergedRecords, downloadedSnapshots: snapshots, listedFiles: files)
            } else {
                self.finishSyncTiming()
                self.isSyncing = false
                self.statusDescription = "云端与本机已同步"
                self.lastConvergenceAt = Date()
                self.runQueuedForceUploadIfNeeded()
            }
        }
    }

    private func uploadConsolidatedSnapshot(
        records: [CardSyncRecord],
        downloadedSnapshots: [WebDAVSyncSnapshotV4],
        listedFiles: [WebDAVBackupFile]
    ) {
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
        WebDAVClient.shared.uploadBackup(filename: filename, cipherText: cipherText) { [weak self] result in
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
                    self.finishSyncTiming()
                    self.statusDescription = ledger.pendingWebDAVUpload ? "本机有新修改，正在继续同步" : "云端与本机已同步"
                    self.isSyncing = false
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
            .sorted { $0.filename > $1.filename }
        guard automaticFiles.count > 5 else { return }
        automaticFiles.dropFirst(5).forEach { file in
            WebDAVClient.shared.deleteBackup(filename: file.filename) { _ in }
        }
    }

    private func completeWithError(_ message: String) {
        finishSyncTiming()
        isSyncing = false
        queuedForceUpload = false
        statusDescription = message
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
