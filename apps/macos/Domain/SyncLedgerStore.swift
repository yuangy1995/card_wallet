import Foundation

public final class SyncLedgerStore {
    public static let shared = SyncLedgerStore()

    private let fileManager = FileManager.default
    private let appFolderName = "CardWallet"
    private let ledgerFileName = "sync-ledger-v4.json"

    private init() {}

    public func load(seeding cards: [SharedCard] = []) -> SyncLedger {
        let url = ledgerURL()
        guard fileManager.fileExists(atPath: url.path),
              let cipherText = try? String(contentsOf: url, encoding: .utf8),
              let jsonString = try? CryptoManager.decrypt(cipherText: cipherText),
              let data = jsonString.data(using: .utf8),
              let ledger = try? JSONDecoder().decode(SyncLedger.self, from: data) else {
            let ledger = SyncLedger(records: cards.map(CardSyncRecord.legacyActive))
            save(ledger)
            return ledger
        }
        return ledger
    }

    public func save(_ ledger: SyncLedger) {
        do {
            let data = try JSONEncoder().encode(ledger)
            guard let json = String(data: data, encoding: .utf8) else { return }
            let cipherText = try CryptoManager.encrypt(plainText: json)
            try cipherText.write(to: ledgerURL(), atomically: true, encoding: .utf8)
        } catch {
            print("保存同步账本失败: \(error.localizedDescription)")
        }
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
