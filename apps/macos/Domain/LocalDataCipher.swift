import Foundation
import CryptoKit

/// Matches the existing app-internal credential mode: no new Keychain prompts.
/// The key and data remain in the user's protected app folder; this is not a
/// password-derived vault and does not protect a copy containing BOTH files.
final class LocalDataCipher {
    static let shared = LocalDataCipher(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CardWallet"))
    let directory: URL
    private let lock = NSLock()
    private let prefix = "local-data-v1:"
    private var keyFile: URL { directory.appendingPathComponent("local_data.key") }
    init(directory: URL) { self.directory = directory }

    private func key(allowCreation: Bool) throws -> SymmetricKey {
        lock.lock(); defer { lock.unlock() }
        if FileManager.default.fileExists(atPath: keyFile.path) {
            let data = try Data(contentsOf: keyFile)
            guard data.count == 32 else { throw CryptoError.decryptionFailed }
            return SymmetricKey(data: data)
        }
        guard allowCreation else { throw CryptoError.decryptionFailed }
        // A missing key is not an invitation to replace an existing encrypted vault.
        for name in ["cards.json", "sync-ledger-v4.json", "sync-history.enc"] {
            let file = directory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: file.path) {
                let handle = try FileHandle(forReadingFrom: file)
                defer { try? handle.close() }
                if try handle.read(upToCount: prefix.utf8.count) == Data(prefix.utf8) {
                    throw CryptoError.decryptionFailed
                }
            }
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let data = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        try data.write(to: keyFile, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFile.path)
        return SymmetricKey(data: data)
    }

    func seal(_ data: Data) throws -> Data {
        let box = try AES.GCM.seal(data, using: key(allowCreation: true), authenticating: Data(prefix.utf8))
        guard let combined = box.combined else { throw CryptoError.encryptionFailed }
        return Data((prefix + combined.base64EncodedString()).utf8)
    }

    func open(_ data: Data, legacyPassword: String? = nil) throws -> Data {
        guard let text = String(data: data, encoding: .utf8) else { throw CryptoError.decryptionFailed }
        if text.hasPrefix(prefix) {
            guard let combined = Data(base64Encoded: String(text.dropFirst(prefix.count))) else { throw CryptoError.decryptionFailed }
            return try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: key(allowCreation: false), authenticating: Data(prefix.utf8))
        }
        // Read-only compatibility; a successful later save performs the migration.
        return Data(try CryptoManager.decrypt(cipherText: text, password: legacyPassword).utf8)
    }
}
