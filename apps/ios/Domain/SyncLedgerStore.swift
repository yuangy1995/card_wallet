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

    public func load(seeding localCards: [SharedCard]) -> SyncLedger {
        let url = fileURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let encryptedData = try? Data(contentsOf: url),
              let data = try? CryptoManager.decryptLocalData(encryptedData),
              let ledger = try? JSONDecoder().decode(SyncLedger.self, from: data) else {
            return SyncLedger(records: localCards.map(CardSyncRecord.activeUsingCardTimestamp))
        }
        return ledger
    }

    public func save(_ ledger: SyncLedger) {
        guard let data = try? JSONEncoder().encode(ledger),
              let encryptedData = try? CryptoManager.encryptLocalData(data) else { return }
        let url = fileURL()
        try? encryptedData.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    }

    public func saveInBackground(_ ledger: SyncLedger) {
        writeQueue.async { [self] in
            save(ledger)
        }
    }

    public func saveAsync(_ ledger: SyncLedger) async {
        await withCheckedContinuation { continuation in
            writeQueue.async { [self] in
                save(ledger)
                continuation.resume()
            }
        }
    }
}
