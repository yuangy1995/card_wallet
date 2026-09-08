import Foundation
import CryptoKit

/// 凭证只存本机；使用独立随机密钥和仅当前用户可读写的文件。
final class LocalCredentialStore {
    let directory: URL
    private var file: URL { directory.appendingPathComponent("security_credentials.enc") }
    private var keyFile: URL { directory.appendingPathComponent("security_credentials.key") }
    private let prefix = "local-v1:"

    init(directory: URL) { self.directory = directory }

    func load() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
        let ciphertext = try String(contentsOf: file, encoding: .utf8)
        let data: Data
        if ciphertext.hasPrefix(prefix) {
            let keyData = try Data(contentsOf: keyFile)
            guard keyData.count == 32,
                  let combined = Data(base64Encoded: String(ciphertext.dropFirst(prefix.count))) else {
                throw CryptoError.decryptionFailed
            }
            data = try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: SymmetricKey(data: keyData))
        } else {
            // 兼容旧版“应用内加密保存”；后续写入统一使用随机密钥。
            let plaintext = try CryptoManager.decrypt(cipherText: ciphertext, password: "Credential.Default.AES.Key.@@1995")
            data = Data(plaintext.utf8)
        }
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    func save(_ credentials: [String: String]) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let keyData: Data
        if manager.fileExists(atPath: keyFile.path) {
            keyData = try Data(contentsOf: keyFile)
            guard keyData.count == 32 else { throw CryptoError.encryptionFailed }
        } else {
            keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
            try keyData.write(to: keyFile, options: .atomic)
        }
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFile.path)
        let plaintext = try JSONEncoder().encode(credentials)
        let sealed = try AES.GCM.seal(plaintext, using: SymmetricKey(data: keyData))
        guard let combined = sealed.combined else { throw CryptoError.encryptionFailed }
        try (prefix + combined.base64EncodedString()).write(to: file, atomically: true, encoding: .utf8)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    /// 所有旧值读取成功后才写入；拒绝授权不会造成部分迁移或清空密码。
    func importLegacy(keys: [String], read: (String) throws -> String?) throws {
        var credentials = try load()
        for key in keys {
            if let value = try read(key) { credentials[key] = value }
        }
        try save(credentials)
    }
}
