import CloudKit
import Foundation
import Security
import SwiftUI

public final class CloudKitSyncService: NSObject, ObservableObject, CKSyncEngineDelegate, @unchecked Sendable {
    public static let shared = CloudKitSyncService()
    public static let containerIdentifier = "iCloud.com.applist.CreditCardMac"

    @Published public private(set) var statusDescription = "iCloud 未启用"
    @Published public private(set) var isAvailable = false
    @Published public private(set) var lastSyncAt: Date?

    private lazy var container = CKContainer(identifier: CloudKitSyncService.containerIdentifier)
    private let zoneID = CKRecordZone.ID(zoneName: "CardSyncZone", ownerName: CKCurrentUserDefaultName)
    private let recordType = "CardSyncRecord"
    private let recordsLock = NSLock()
    private var availableRecords: [String: CardSyncRecord] = [:]
    private var engine: CKSyncEngine?
    private var serializedState: CKSyncEngine.State.Serialization?
    private var onRecordsReceived: (([CardSyncRecord]) -> Void)?
    private var onStateUpdated: ((Data) -> Void)?

    public var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "enable_icloud_sync") as? Bool ?? false
    }

    private override init() {
        super.init()
    }

    public func configure(
        stateData: Data?,
        onRecordsReceived: @escaping ([CardSyncRecord]) -> Void,
        onStateUpdated: @escaping (Data) -> Void
    ) {
        self.onRecordsReceived = onRecordsReceived
        self.onStateUpdated = onStateUpdated
        if let stateData {
            serializedState = try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: stateData)
        }
        if isEnabled {
            start()
        }
    }

    public func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "enable_icloud_sync")
        guard enabled else {
            engine = nil
            isAvailable = false
            statusDescription = "iCloud 已关闭，本地与 WebDAV 仍可用"
            return
        }
        start()
    }

    public func start() {
        guard isEnabled else { return }
        guard hasCloudKitEntitlement else {
            isAvailable = false
            statusDescription = "iCloud 不可用：当前构建未包含 CloudKit 签名权限"
            return
        }
        statusDescription = "正在检查 iCloud 账户..."
        container.accountStatus { [weak self] accountStatus, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.isAvailable = false
                    self.statusDescription = "iCloud 不可用：\(error.localizedDescription)"
                    return
                }
                guard accountStatus == .available else {
                    self.isAvailable = false
                    self.statusDescription = "iCloud 不可用：请登录 iCloud 或检查容器签名权限"
                    return
                }
                self.prepareEngine()
            }
        }
    }

    public func queue(records: [CardSyncRecord]) {
        guard isEnabled else { return }
        recordsLock.lock()
        records.forEach { availableRecords[$0.cardId] = $0 }
        recordsLock.unlock()

        if engine == nil {
            start()
            return
        }
        let changes = records.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(recordID(for: $0.cardId))
        }
        engine?.state.add(pendingRecordZoneChanges: changes)
        sendPendingChanges()
    }

    public func refresh() {
        guard let engine, isEnabled else { return }
        Task {
            do {
                try await engine.fetchChanges()
            } catch {
                await MainActor.run {
                    self.statusDescription = "iCloud 拉取失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func prepareEngine() {
        guard engine == nil else {
            refresh()
            return
        }
        let configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: serializedState,
            delegate: self
        )
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        isAvailable = true
        statusDescription = "iCloud 已就绪，等待同步"
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        recordsLock.lock()
        let initialRecordIDs = availableRecords.keys.map(recordID(for:))
        recordsLock.unlock()
        engine.state.add(pendingRecordZoneChanges: initialRecordIDs.map {
            .saveRecord($0)
        })
        sendPendingChanges()
        refresh()
    }

    private var hasCloudKitEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let services = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.developer.icloud-services" as CFString,
                nil
              ) as? [String] else {
            return false
        }
        return services.contains("CloudKit")
    }

    private func sendPendingChanges() {
        guard let engine, isAvailable else { return }
        Task {
            do {
                try await engine.sendChanges()
            } catch {
                await MainActor.run {
                    self.statusDescription = "iCloud 写入失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func recordID(for cardID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: cardID, zoneID: zoneID)
    }

    private func record(for recordID: CKRecord.ID) -> CKRecord? {
        recordsLock.lock()
        let syncRecord = availableRecords[recordID.recordName]
        recordsLock.unlock()
        guard let syncRecord,
              let payload = try? JSONEncoder().encode(syncRecord) else {
            return nil
        }
        let cloudRecord = CKRecord(recordType: recordType, recordID: recordID)
        cloudRecord.encryptedValues["payload"] = payload as CKRecordValue
        return cloudRecord
    }

    private static func syncRecord(from cloudRecord: CKRecord) -> CardSyncRecord? {
        guard let payload = cloudRecord.encryptedValues["payload"] as? Data else { return nil }
        return try? JSONDecoder().decode(CardSyncRecord.self, from: payload)
    }

    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            if let data = try? JSONEncoder().encode(update.stateSerialization) {
                await MainActor.run { self.onStateUpdated?(data) }
            }
        case .accountChange:
            await MainActor.run {
                self.statusDescription = "iCloud 账户已变化，正在重新同步"
            }
        case .fetchedRecordZoneChanges(let changes):
            let records = changes.modifications.compactMap { Self.syncRecord(from: $0.record) }
            guard !records.isEmpty else { return }
            await MainActor.run {
                self.lastSyncAt = Date()
                self.statusDescription = "iCloud 已同步 \(records.count) 条变更"
                self.onRecordsReceived?(records)
            }
        case .sentRecordZoneChanges(let changes):
            await MainActor.run {
                self.lastSyncAt = Date()
                if changes.failedRecordSaves.isEmpty {
                    self.statusDescription = "iCloud 写入完成"
                } else {
                    self.statusDescription = "iCloud 有 \(changes.failedRecordSaves.count) 条写入失败"
                }
            }
        default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter {
            context.options.scope.contains($0)
        }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { [weak self] recordID in
            self?.record(for: recordID)
        }
    }
}
