import Foundation
import SwiftUI

public final class WebDAVBridgeService: ObservableObject {
    public static let shared = WebDAVBridgeService()

    @Published public private(set) var statusDescription = "云同步待配置"
    @Published public private(set) var lastConvergenceAt: Date?
    @Published public private(set) var isSyncing = false

    private var timer: Timer?
    private var recordsProvider: (() -> [CardSyncRecord])?
    private var onMergedRecords: (([CardSyncRecord]) -> Void)?
    private var queuedForceUpload = false

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
            statusDescription = "云端自动同步已关闭"
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
                statusDescription = "本地修改已加入同步队列，当前同步完成后会继续上传"
            }
            return
        }
        guard WebDAVClient.shared.loadConfig() != nil else {
            statusDescription = "云同步待配置"
            return
        }
        isSyncing = true
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

    private func downloadAndMerge(files: [WebDAVBackupFile], forceUpload: Bool) {
        let automaticFiles = files.filter { $0.filename.contains("[SyncV3]") && $0.filename.contains("[自]") }
        let hasPendingUpload = SyncLedgerStore.shared.load().pendingWebDAVUpload
        guard !automaticFiles.isEmpty else {
            if forceUpload || hasPendingUpload {
                uploadConsolidatedSnapshot(records: recordsProvider?() ?? [], downloadedSnapshots: [], listedFiles: files)
            } else {
                isSyncing = false
                statusDescription = "尚未找到自动同步数据"
                runQueuedForceUploadIfNeeded()
            }
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var snapshots: [WebDAVSyncSnapshotV3] = []
        for file in automaticFiles {
            group.enter()
            WebDAVClient.shared.downloadBackup(filename: file.filename) { result in
                defer { group.leave() }
                guard case .success(let cipherText) = result,
                      let json = try? CryptoManager.decrypt(cipherText: cipherText),
                      let data = json.data(using: .utf8),
                      let snapshot = try? JSONDecoder().decode(WebDAVSyncSnapshotV3.self, from: data),
                      snapshot.schemaVersion == WebDAVSyncSnapshotV3.schemaVersion else {
                    return
                }
                lock.lock()
                snapshots.append(snapshot)
                lock.unlock()
            }
        }
        group.notify(queue: .main) {
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
                self.isSyncing = false
                self.statusDescription = "云端与本地已同步"
                self.lastConvergenceAt = Date()
                self.runQueuedForceUploadIfNeeded()
            }
        }
    }

    private func uploadConsolidatedSnapshot(
        records: [CardSyncRecord],
        downloadedSnapshots: [WebDAVSyncSnapshotV3],
        listedFiles: [WebDAVBackupFile]
    ) {
        let snapshot = WebDAVSyncSnapshotV3(source: "macos", records: records)
        guard let data = try? JSONEncoder().encode(snapshot),
              let json = String(data: data, encoding: .utf8),
              let cipherText = try? CryptoManager.encrypt(plainText: json) else {
            completeWithError("同步数据准备失败")
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
        let filename = "\(formatter.string(from: Date()))---(\(CardSyncMergeEngine.activeCards(from: records).count))[SyncV3][Mac][自].json"
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
                    self.statusDescription = ledger.pendingWebDAVUpload ? "本地有新修改，正在继续同步" : "云端与本地已同步"
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
            .filter { $0.filename.contains("[SyncV3]") && $0.filename.contains("[自]") }
            .sorted { $0.filename > $1.filename }
        guard automaticFiles.count > 5 else { return }
        automaticFiles.dropFirst(5).forEach { file in
            WebDAVClient.shared.deleteBackup(filename: file.filename) { _ in }
        }
    }

    private func completeWithError(_ message: String) {
        isSyncing = false
        queuedForceUpload = false
        statusDescription = message
    }

    private func runQueuedForceUploadIfNeeded() {
        guard queuedForceUpload else { return }
        queuedForceUpload = false
        DispatchQueue.main.async { [weak self] in
            self?.synchronize(forceUpload: true)
        }
    }
}
