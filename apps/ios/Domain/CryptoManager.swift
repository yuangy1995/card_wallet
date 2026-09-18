import Foundation
import CryptoKit
import CommonCrypto

public enum CryptoError: Error, LocalizedError, Sendable {
    case badMagicNumber
    case utf8DecodingFailed
    case encryptionFailed
    case decryptionFailed
    case emptyPassword
    case invalidSyncEnvelope
    case keyDerivationFailed

    public var errorDescription: String? {
        switch self {
        case .badMagicNumber: return "密文损坏：魔数验证失败"
        case .utf8DecodingFailed: return "UTF-8 字符解码失败，请确认解密密码是否正确"
        case .encryptionFailed: return "AES 加密失败"
        case .decryptionFailed: return "无法读取本地加密数据，原始文件已保留。请检查本机钥匙串或从备份恢复。"
        case .emptyPassword: return "请输入自定义解密密码"
        case .invalidSyncEnvelope: return "不是有效的云同步加密文件"
        case .keyDerivationFailed: return "同步密钥派生失败"
        }
    }
}

public class CryptoManager {
    private static let syncV4SchemaVersion = "4.0.0"
    private static let syncV4Iterations = 310000
    private static let syncV4SaltBytes = 16
    private static let syncV4IVBytes = 12
    private static let localEnvelopePrefix = "local-v1:"
    private static let localEncryptionKeychainKey = "local_data_encryption_key_v1"
    private static let localEncryptionKeyBytes = 32
    private static let localEncryptionNonceBytes = 12

    private static func randomBytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else { throw CryptoError.encryptionFailed }
        return bytes
    }

    private static let localKeyLock = NSLock()
    private static func localDataKey(allowCreation: Bool) throws -> SymmetricKey {
        localKeyLock.lock(); defer { localKeyLock.unlock() }
        if let data = try KeychainManager.loadDataResult(key: localEncryptionKeychainKey).get() {
            guard data.count == localEncryptionKeyBytes else { throw CryptoError.decryptionFailed }
            return SymmetricKey(data: data)
        }

        guard allowCreation else { throw CryptoError.decryptionFailed }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("CardWallet")
        for name in ["cards.json", "sync_ledger.json", "sync-history.enc"] {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) { throw CryptoError.decryptionFailed }
        }
        let keyBytes = try randomBytes(count: localEncryptionKeyBytes)
        let keyData = Data(keyBytes)
        switch KeychainManager.saveData(key: localEncryptionKeychainKey, data: keyData) {
        case .success:
            return SymmetricKey(data: keyData)
        case .failure:
            throw CryptoError.keyDerivationFailed
        }
    }

    public static func encryptLocalData(_ data: Data) throws -> Data {
        let key = try localDataKey(allowCreation: true)
        let nonceBytes = try randomBytes(count: localEncryptionNonceBytes)
        let nonce = try CryptoKit.AES.GCM.Nonce(data: Data(nonceBytes))
        let sealedBox = try CryptoKit.AES.GCM.seal(data, using: key, nonce: nonce)
        var payload = Data(nonceBytes)
        payload.append(sealedBox.ciphertext)
        payload.append(sealedBox.tag)
        guard let envelope = "\(localEnvelopePrefix)\(payload.base64EncodedString())".data(using: .utf8) else {
            throw CryptoError.encryptionFailed
        }
        return envelope
    }

    public static func decryptLocalData(_ data: Data) throws -> Data {
        guard let envelope = String(data: data, encoding: .utf8),
              envelope.hasPrefix(localEnvelopePrefix),
              let payload = Data(base64Encoded: String(envelope.dropFirst(localEnvelopePrefix.count))),
              payload.count > localEncryptionNonceBytes + 16 else {
            throw CryptoError.badMagicNumber
        }
        let nonceData = payload.prefix(localEncryptionNonceBytes)
        let tagStart = payload.index(payload.endIndex, offsetBy: -16)
        let ciphertext = payload[payload.index(payload.startIndex, offsetBy: localEncryptionNonceBytes)..<tagStart]
        let tag = payload[tagStart...]
        let sealedBox = try CryptoKit.AES.GCM.SealedBox(
            nonce: try CryptoKit.AES.GCM.Nonce(data: nonceData),
            ciphertext: Data(ciphertext),
            tag: Data(tag)
        )
        return try CryptoKit.AES.GCM.open(sealedBox, using: try localDataKey(allowCreation: false))
    }

    private static func deriveSyncV4Key(password: String, salt: [UInt8], iterations: Int) throws -> [UInt8] {
        let passwordData = Data(password.utf8)
        let keyLength = 32
        var key = [UInt8](repeating: 0, count: keyLength)
        let status = passwordData.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBufferPointer { saltBuffer in
                key.withUnsafeMutableBufferPointer { keyBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBuffer.baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        keyBuffer.baseAddress,
                        keyLength
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw CryptoError.keyDerivationFailed }
        return key
    }

    public static func encryptSyncEnvelopeV4(plainText: String, password: String) throws -> String {
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPassword.isEmpty else { throw CryptoError.emptyPassword }
        let salt = try randomBytes(count: syncV4SaltBytes)
        let iv = try randomBytes(count: syncV4IVBytes)
        let keyBytes = try deriveSyncV4Key(password: normalizedPassword, salt: salt, iterations: syncV4Iterations)
        let key = SymmetricKey(data: Data(keyBytes))
        let nonce = try CryptoKit.AES.GCM.Nonce(data: Data(iv))
        let sealedBox = try CryptoKit.AES.GCM.seal(Data(plainText.utf8), using: key, nonce: nonce)
        var ciphertextAndTag = Data(sealedBox.ciphertext)
        ciphertextAndTag.append(sealedBox.tag)
        let envelope = SyncEncryptedEnvelope(
            encryption: SyncEncryptionMetadata(iterations: syncV4Iterations, salt: Data(salt).base64EncodedString(), iv: Data(iv).base64EncodedString()),
            ciphertext: ciphertextAndTag.base64EncodedString()
        )
        let data = try JSONEncoder().encode(envelope)
        guard let json = String(data: data, encoding: .utf8) else { throw CryptoError.encryptionFailed }
        return json
    }

    public static func decryptSyncEnvelopeV4(envelopeText: String, password: String) throws -> String {
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPassword.isEmpty else { throw CryptoError.emptyPassword }
        guard let envelopeData = envelopeText.data(using: .utf8) else { throw CryptoError.invalidSyncEnvelope }
        let envelope = try JSONDecoder().decode(SyncEncryptedEnvelope.self, from: envelopeData)
        guard envelope.schemaVersion == syncV4SchemaVersion,
              envelope.encryption.algorithm == "AES-256-GCM",
              envelope.encryption.kdf == "PBKDF2-HMAC-SHA256",
              (100000...2000000).contains(envelope.encryption.iterations),
              let saltData = Data(base64Encoded: envelope.encryption.salt),
              saltData.count == syncV4SaltBytes,
              let ivData = Data(base64Encoded: envelope.encryption.iv),
              ivData.count == syncV4IVBytes,
              let ciphertextAndTag = Data(base64Encoded: envelope.ciphertext),
              ciphertextAndTag.count > 16 else { throw CryptoError.invalidSyncEnvelope }
        let keyBytes = try deriveSyncV4Key(password: normalizedPassword, salt: Array(saltData), iterations: envelope.encryption.iterations)
        let nonce = try CryptoKit.AES.GCM.Nonce(data: ivData)
        let tagStartIndex = ciphertextAndTag.index(ciphertextAndTag.endIndex, offsetBy: -16)
        let ciphertext = Data(ciphertextAndTag[..<tagStartIndex])
        let tag = Data(ciphertextAndTag[tagStartIndex...])
        let sealedBox = try CryptoKit.AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let plaintext = try CryptoKit.AES.GCM.open(sealedBox, using: SymmetricKey(data: Data(keyBytes)))
        guard let json = String(data: plaintext, encoding: .utf8) else { throw CryptoError.utf8DecodingFailed }
        return json
    }
}
