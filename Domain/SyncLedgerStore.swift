import Foundation

public final class SyncLedgerStore: Sendable {
    public static let shared = SyncLedgerStore()
    private let fileName = "sync_ledger.json"
    private let writeQueue = DispatchQueue(label: "com.applist.credit-card-ios.sync-ledger", qos: .utility)
    private init() {}

    private func fileURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("CreditCardIOS", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir.appendingPathComponent(fileName)
    }

    public func load(seeding localCards: [SharedCard]) -> SyncLedger {
        let url = fileURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let ledger = try? JSONDecoder().decode(SyncLedger.self, from: data) else {
            return SyncLedger(records: localCards.map(CardSyncRecord.legacyActive))
        }
        return ledger
    }

    public func save(_ ledger: SyncLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        try? data.write(to: fileURL(), options: .atomic)
    }

    public func saveInBackground(_ ledger: SyncLedger) {
        writeQueue.async { [self] in
            save(ledger)
        }
    }
}
