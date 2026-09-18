import Foundation

public final class SyncLedgerStore: Sendable {
    public static let shared = SyncLedgerStore()
    private let fileName = "sync_ledger.json"
    private let writeQueue = DispatchQueue(label: "com.applist.credit-card-ios.sync-ledger", qos: .utility)
    private init() {}

    private func fileURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("CardWallet", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir.appendingPathComponent(fileName)
    }

    public func load(seeding localCards: [SharedCard]) throws -> SyncLedger {
        try writeQueue.sync {
            let url = fileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return SyncLedger(records: localCards.map(CardSyncRecord.activeUsingCardTimestamp)) }
            let encryptedData = try Data(contentsOf: url)
            let data = try CryptoManager.decryptLocalData(encryptedData)
            return try JSONDecoder().decode(SyncLedger.self, from: data)
        }
    }
    private func persist(_ ledger: SyncLedger) -> Bool {
        do {
            let data = try JSONEncoder().encode(ledger)
            let encryptedData = try CryptoManager.encryptLocalData(data)
            let url = fileURL()
            try encryptedData.write(to: url, options: [.atomic, .completeFileProtection])
            return true
        } catch { return false }
    }
    @discardableResult public func save(_ ledger: SyncLedger) -> Bool { writeQueue.sync { persist(ledger) } }
    public func saveInBackground(_ ledger: SyncLedger) { writeQueue.async { [self] in _ = persist(ledger) } }
    public func saveAsync(_ ledger: SyncLedger) async {
        await withCheckedContinuation { continuation in
            writeQueue.async { [self] in _ = persist(ledger); continuation.resume() }
        }
    }
}
