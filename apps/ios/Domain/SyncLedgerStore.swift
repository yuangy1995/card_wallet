import Foundation

public final class SyncLedgerStore : Sendable {
    public static let shared = SyncLedgerStore()
    private let directory: URL
    private let queue = DispatchQueue(label: "wallet.ios.ledger-writes", qos: .utility)
    private var fileURL: URL { directory.appendingPathComponent("sync_ledger.json") }
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("CardWallet")
    }
    /// A valid ledger is authoritative. Do not decode a second full cards.json on each unlock.
    public func loadExisting() throws -> SyncLedger? { try queue.sync { try readExisting() } }
    private func readExisting() throws -> SyncLedger? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let encrypted = try Data(contentsOf: fileURL)
        let data = try CryptoManager.decryptLocalData(encrypted)
        return try JSONDecoder().decode(SyncLedger.self, from: data)
    }
    public func load(seeding cards: [SharedCard] = []) throws -> SyncLedger {
        try queue.sync { try readExisting() ?? SyncLedger(records: cards.map(CardSyncRecord.activeUsingCardTimestamp)) }
    }
    @discardableResult
    public func save(_ ledger: SyncLedger) -> Bool { queue.sync { write(ledger) } }
    private func write(_ ledger: SyncLedger) -> Bool {
        do {
            let data = try JSONEncoder().encode(ledger)
            let encrypted = try CryptoManager.encryptLocalData(data)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try encrypted.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path)
            return true
        } catch { return false }
    }
    public func saveInBackground(_ ledger: SyncLedger) { queue.async { [self] in _ = write(ledger) } }
    public func saveAsync(_ ledger: SyncLedger) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [self] in continuation.resume(returning: write(ledger)) }
        }
    }
}
