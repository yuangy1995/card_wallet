import Foundation
import CryptoKit

/// Uses the existing per-user credential store, without reintroducing automatic Keychain prompts.
/// Protects at-rest content; this does not protect against compromise of the current OS account.
enum LocalWalletCipher {
    static let prefix = "wallet-data-v1:"
    private static let keyName = "wallet_local_data_key_v1"
    private static let lock = NSLock()
    private static func key(create: Bool) throws -> SymmetricKey {
        lock.lock(); defer { lock.unlock() }
        if let raw = try KeychainManager.loadResult(key: keyName).get() {
            guard let bytes = Data(base64Encoded: raw), bytes.count == 32 else { throw CryptoError.decryptionFailed }
            return SymmetricKey(data: bytes)
        }
        guard create else { throw CryptoError.decryptionFailed }
        let key = SymmetricKey(size: .bits256)
        try KeychainManager.save(key: keyName, value: key.withUnsafeBytes { Data($0) }.base64EncodedString()).get()
        return key
    }
    static func seal(_ data: Data, purpose: String) throws -> String {
        let sealed = try AES.GCM.seal(data, using: key(create: true), authenticating: Data(purpose.utf8))
        guard let combined = sealed.combined else { throw CryptoError.encryptionFailed }
        return prefix + combined.base64EncodedString()
    }
    static func open(_ text: String, purpose: String, legacyPassword: String? = nil) throws -> Data {
        guard text.hasPrefix(prefix) else {
            return Data(try CryptoManager.decrypt(cipherText: text, password: legacyPassword).utf8)
        }
        guard let bytes = Data(base64Encoded: String(text.dropFirst(prefix.count))) else { throw CryptoError.decryptionFailed }
        return try AES.GCM.open(AES.GCM.SealedBox(combined: bytes), using: key(create: false), authenticating: Data(purpose.utf8))
    }
}
