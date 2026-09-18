import Foundation

public final class SyncLedgerStore {
    public static let shared = SyncLedgerStore()

    private let fileManager = FileManager.default
    private let appFolderName = "CardWallet"
    private let ledgerFileName = "sync-ledger-v4.json"

    private init() {}

    public func load(seeding cards: [SharedCard] = []) throws -> SyncLedger {
        let url = ledgerURL()
        guard fileManager.fileExists(atPath: url.path) else { return SyncLedger(records: cards.map(CardSyncRecord.legacyActive)) }
        let text = try String(contentsOf: url, encoding: .utf8)
        let data = try LocalWalletCipher.open(text, purpose: "ledger")
        return try JSONDecoder().decode(SyncLedger.self, from: data)
    }

    @discardableResult
    public func save(_ ledger: SyncLedger) -> Bool {
        do {
            let data = try JSONEncoder().encode(ledger)
            let text = try LocalWalletCipher.seal(data, purpose: "ledger")
            try text.write(to: ledgerURL(), atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: ledgerURL().path)
            return true
        } catch { return false }
    }

    private func ledgerURL() -> URL {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(appFolderName, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent(ledgerFileName)
    }
}
