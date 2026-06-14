import Foundation
import CryptoSwift
import CryptoKit
import CommonCrypto

public enum CryptoError: Error, LocalizedError, Sendable {
    case invalidBase64
    case badMagicNumber
    case utf8DecodingFailed
    case encryptionFailed
    case decryptionFailed
    case emptyPassword
    case invalidSyncEnvelope
    case keyDerivationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidBase64: return "无效的 Base64 编码数据"
        case .badMagicNumber: return "密文损坏：魔数验证失败"
        case .utf8DecodingFailed: return "UTF-8 字符解码失败，请确认解密密码是否正确"
        case .encryptionFailed: return "AES 加密失败"
        case .decryptionFailed: return "AES 解密失败，可能密码错误或数据损坏"
        case .emptyPassword: return "请输入自定义解密密码"
        case .invalidSyncEnvelope: return "不是有效的云同步加密文件"
        case .keyDerivationFailed: return "同步密钥派生失败"
        }
    }
}

public class CryptoManager {
    private static let defaultPassword = "defAult.@.Password."
    private static let syncV4SchemaVersion = "4.0.0"
    private static let syncV4Iterations = 310000
    private static let syncV4SaltBytes = 16
    private static let syncV4IVBytes = 12

    private static func deriveKeyAndIV(password: String, salt: [UInt8]) -> (key: [UInt8], iv: [UInt8]) {
        var keyAndIV = [UInt8]()
        var lastDigest = [UInt8]()
        let passwordBytes = Array(password.utf8)
        while keyAndIV.count < 48 {
            let dataToHash = lastDigest + passwordBytes + salt
            lastDigest = dataToHash.md5()
            keyAndIV += lastDigest
        }
        return (Array(keyAndIV[0..<32]), Array(keyAndIV[32..<48]))
    }

    public static func decrypt(cipherText: String, password: String? = nil) throws -> String {
        var cleanCipher = cipherText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanCipher.hasPrefix("\"") && cleanCipher.hasSuffix("\"") {
            cleanCipher = String(cleanCipher.dropFirst().dropLast())
        }
        let isDefault = cleanCipher.hasPrefix("default:")
        let isEncrypted = cleanCipher.hasPrefix("encrypted:")
        guard isDefault || isEncrypted else { throw CryptoError.badMagicNumber }
        let prefixLength = isDefault ? 8 : 10
        let cleanText = String(cleanCipher.dropFirst(prefixLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        if isEncrypted && (password == nil || password?.isEmpty == true) { throw CryptoError.emptyPassword }
        guard let data = Data(base64Encoded: cleanText) else { throw CryptoError.invalidBase64 }
        let bytes = Array(data)
        let magicNumber = Array("Salted__".utf8)
        guard bytes.count > 16 && Array(bytes[0..<8]) == magicNumber else { throw CryptoError.badMagicNumber }
        let salt = Array(bytes[8..<16])
        let encryptedBytes = Array(bytes[16...])
        let activePassword = isDefault ? defaultPassword : (password ?? "")
        let (key, iv) = deriveKeyAndIV(password: activePassword, salt: salt)
        do {
            let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
            let decryptedBytes = try aes.decrypt(encryptedBytes)
            guard let decryptedString = String(bytes: decryptedBytes, encoding: .utf8) else { throw CryptoError.utf8DecodingFailed }
            return decryptedString
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    public static func encrypt(plainText: String, password: String? = nil) throws -> String {
        let isDefault = password == nil || password?.isEmpty == true
        let activePassword = isDefault ? defaultPassword : password!
        var salt = [UInt8](repeating: 0, count: 8)
        let status = SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt)
        guard status == errSecSuccess else { throw CryptoError.encryptionFailed }
        let (key, iv) = deriveKeyAndIV(password: activePassword, salt: salt)
        do {
            let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
            let plainBytes = Array(plainText.utf8)
            let encryptedBytes = try aes.encrypt(plainBytes)
            let magicNumber = Array("Salted__".utf8)
            let outputBytes = magicNumber + salt + encryptedBytes
            let base64Cipher = Data(outputBytes).base64EncodedString()
            return "\(isDefault ? "default:" : "encrypted:")\(base64Cipher)"
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    private static func randomBytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else { throw CryptoError.encryptionFailed }
        return bytes
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
              let saltData = Data(base64Encoded: envelope.encryption.salt),
              let ivData = Data(base64Encoded: envelope.encryption.iv),
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
