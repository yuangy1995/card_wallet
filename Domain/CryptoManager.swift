import Foundation
import CryptoSwift

public enum CryptoError: Error, LocalizedError {
    case invalidBase64
    case badMagicNumber
    case utf8DecodingFailed
    case encryptionFailed
    case decryptionFailed
    case emptyPassword
    
    public var errorDescription: String? {
        switch self {
        case .invalidBase64: return "无效的 Base64 编码数据"
        case .badMagicNumber: return "密文损坏：魔数验证失败，可能不是 CryptoJS 加密的数据"
        case .utf8DecodingFailed: return "UTF-8 字符解码失败，请确认解密密码是否正确"
        case .encryptionFailed: return "AES 加密失败"
        case .decryptionFailed: return "AES 解密失败，可能密码错误或数据损坏"
        case .emptyPassword: return "请输入自定义解密密码"
        }
    }
}

public class CryptoManager {
    private static let defaultPassword = "defAult.@.Password."
    
    /// 还原 OpenSSL EVP_BytesToKey / CryptoJS 密钥派生算法
    /// 派生出 48 字节数据 (32 字节 Key + 16 字节 IV)
    private static func deriveKeyAndIV(password: String, salt: [UInt8]) -> (key: [UInt8], iv: [UInt8]) {
        var keyAndIV = [UInt8]()
        var lastDigest = [UInt8]()
        let passwordBytes = Array(password.utf8)
        
        while keyAndIV.count < 48 {
            let dataToHash = lastDigest + passwordBytes + salt
            lastDigest = dataToHash.md5()
            keyAndIV += lastDigest
        }
        
        let key = Array(keyAndIV[0..<32])
        let iv = Array(keyAndIV[32..<48])
        return (key, iv)
    }
    
    /// 100% 互通解密 Web 端 CryptoJS 生成的 AES 密文
    /// - Parameters:
    ///   - cipherText: 加密密文（带 default: 或 encrypted: 前缀）
    ///   - password: 自定义密码（如果前缀是 encrypted:，该值必填）
    /// - Returns: 解密后的 JSON 原始字符串
    public static func decrypt(cipherText: String, password: String? = nil) throws -> String {
        // 🚨 极端容错清洗：过滤由于 WebDAV 传输或 JSON 包装产生的两侧双引号、空白和换行符，防呆！
        var cleanCipher = cipherText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanCipher.hasPrefix("\"") && cleanCipher.hasSuffix("\"") {
            cleanCipher = String(cleanCipher.dropFirst().dropLast())
        }
        
        let isDefault = cleanCipher.hasPrefix("default:")
        let isEncrypted = cleanCipher.hasPrefix("encrypted:")
        
        guard isDefault || isEncrypted else {
            throw CryptoError.badMagicNumber
        }
        
        // 剥离前缀
        let prefixLength = isDefault ? 8 : 10
        let cleanText = String(cleanCipher.dropFirst(prefixLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isEncrypted && (password == nil || password?.isEmpty == true) {
            throw CryptoError.emptyPassword
        }
        
        guard let data = Data(base64Encoded: cleanText) else {
            throw CryptoError.invalidBase64
        }
        
        let bytes = Array(data)
        // 校验 OpenSSL "Salt__" 头 (8 字节魔数: 0x53616c7465645f5f)
        let magicNumber = Array("Salted__".utf8)
        guard bytes.count > 16 && Array(bytes[0..<8]) == magicNumber else {
            throw CryptoError.badMagicNumber
        }
        
        // 提取盐值 (8 字节) 和 真正密文
        let salt = Array(bytes[8..<16])
        let encryptedBytes = Array(bytes[16...])
        
        let activePassword = isDefault ? defaultPassword : (password ?? "")
        let (key, iv) = deriveKeyAndIV(password: activePassword, salt: salt)
        
        do {
            let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
            let decryptedBytes = try aes.decrypt(encryptedBytes)
            
            guard let decryptedString = String(bytes: decryptedBytes, encoding: .utf8) else {
                throw CryptoError.utf8DecodingFailed
            }
            return decryptedString
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
    
    /// 生成符合 CryptoJS 格式的 AES 密文，供同步或导出使用
    /// - Parameters:
    ///   - plainText: 要加密的 JSON 字符串
    ///   - password: 自定义加密密码，留空则使用内置默认密码
    /// - Returns: 加密密文（自动加上前缀）
    public static func encrypt(plainText: String, password: String? = nil) throws -> String {
        let isDefault = password == nil || password?.isEmpty == true
        let activePassword = isDefault ? defaultPassword : password!
        
        // 1. 生成 8 字节随机盐值
        var salt = [UInt8](repeating: 0, count: 8)
        let status = SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt)
        guard status == errSecSuccess else {
            throw CryptoError.encryptionFailed
        }
        
        // 2. 派生 Key & IV
        let (key, iv) = deriveKeyAndIV(password: activePassword, salt: salt)
        
        do {
            // 3. 执行 AES CBC 加密
            let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
            let plainBytes = Array(plainText.utf8)
            let encryptedBytes = try aes.encrypt(plainBytes)
            
            // 4. 拼装 OpenSSL 密文结构： "Salt__" 魔数 (8字节) + 盐值 (8字节) + 密文数据
            let magicNumber = Array("Salted__".utf8)
            let outputBytes = magicNumber + salt + encryptedBytes
            
            let base64Cipher = Data(outputBytes).base64EncodedString()
            let prefix = isDefault ? "default:" : "encrypted:"
            return "\(prefix)\(base64Cipher)"
        } catch {
            throw CryptoError.encryptionFailed
        }
    }
}
