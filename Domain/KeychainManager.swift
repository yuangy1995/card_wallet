import Foundation
import Security

public enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case conversionError
    
    public var errorDescription: String? {
        switch self {
        case .duplicateItem: return "钥匙串中已存在相同的记录"
        case .itemNotFound: return "未能在系统钥匙串中找到指定的记录"
        case .unexpectedStatus(let status): return "系统钥匙串返回未知错误，错误码: \(status)"
        case .conversionError: return "数据转换失败"
        }
    }
}

public class KeychainManager {
    private static let serviceName = "com.applist.creditcardmac.webdav"
    
    /// 💡 安全敏感信息的存储介质选项
    public enum SecurityStorageMode: String, Codable, CaseIterable, Identifiable {
        case appInternal = "appInternal"
        case systemKeychain = "systemKeychain"
        
        public var id: String { self.rawValue }
        
        public var displayName: String {
            switch self {
            case .appInternal: return "🔒 应用内部加密 (免弹窗)"
            case .systemKeychain: return "🔑 系统钥匙串"
            }
        }
    }
    
    /// 💡 存储路由：保存在本地 UserDefaults，默认设为 .appInternal 免除弹窗打扰
    public static var currentStorageMode: SecurityStorageMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: "security_storage_mode"),
               let mode = SecurityStorageMode(rawValue: raw) {
                return mode
            }
            return .systemKeychain
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "security_storage_mode")
        }
    }
    
    // ==========================================
    // 💡 1. 本地沙盒 AES-256 加密凭证库底层逻辑
    // ==========================================
    
    private static func getInternalStorageURL() -> URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDirectory = paths[0].appendingPathComponent("CardWallet", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appSupportDirectory.path) {
            try? FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        return appSupportDirectory.appendingPathComponent("security_credentials.enc")
    }
    
    private static func loadInternalDictionary() -> [String: String] {
        let fileURL = getInternalStorageURL()
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let cipherText = try? String(contentsOf: fileURL, encoding: .utf8),
              let jsonString = try? CryptoManager.decrypt(cipherText: cipherText, password: "Credential.Default.AES.Key.@@1995"),
              let data = jsonString.data(using: .utf8) else {
            return [:]
        }
        return (try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String]) ?? [:]
    }
    
    private static func saveInternalDictionary(_ dict: [String: String]) -> Bool {
        let fileURL = getInternalStorageURL()
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let jsonString = String(data: data, encoding: .utf8),
              let cipherText = try? CryptoManager.encrypt(plainText: jsonString, password: "Credential.Default.AES.Key.@@1995") else {
            return false
        }
        do {
            try cipherText.write(to: fileURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
    
    // ==========================================
    // 💡 2. 对外透明路由接口 (根据 currentStorageMode 自动分流)
    // ==========================================
    
    /// 保存敏感数据 (动态分流，透明代理)
    @discardableResult
    public static func save(key: String, value: String) -> Result<Void, Error> {
        if currentStorageMode == .appInternal {
            var dict = loadInternalDictionary()
            dict[key] = value
            if saveInternalDictionary(dict) {
                return .success(())
            } else {
                return .failure(KeychainError.conversionError)
            }
        } else {
            return saveToKeychainDirectly(key: key, value: value)
        }
    }
    
    /// 读取敏感数据 (动态分流，透明代理)
    public static func load(key: String) -> String? {
        if currentStorageMode == .appInternal {
            let dict = loadInternalDictionary()
            return dict[key]
        } else {
            return loadFromKeychainDirectly(key: key)
        }
    }
    
    /// 彻底擦除敏感数据 (动态分流，透明代理)
    @discardableResult
    public static func delete(key: String) -> Bool {
        if currentStorageMode == .appInternal {
            var dict = loadInternalDictionary()
            dict.removeValue(forKey: key)
            return saveInternalDictionary(dict)
        } else {
            return deleteFromKeychainDirectly(key: key)
        }
    }
    
    /// 清空所有托管敏感数据
    @discardableResult
    public static func clearAllCredentials() -> Bool {
        if currentStorageMode == .appInternal {
            let fileURL = getInternalStorageURL()
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            return true
        } else {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName
            ]
            let status = SecItemDelete(query as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }
    }
    
    // ==========================================
    // 💡 3. 双向无缝热迁移系统 (Hot Migration)
    // ==========================================
    
    /// 在“系统钥匙串”和“应用内高强度加密”之间进行一键、零打扰的平滑数据双向热迁移
    public static func migrate(to targetMode: SecurityStorageMode) -> Bool {
        let keysToMigrate = ["webdav_username", "webdav_password", "webdav_sync_password_v4", "app_lock_password", "webdav_config"]
        
        if targetMode == .appInternal {
            // 系统钥匙串 -> 应用内部加密
            var targetDict = loadInternalDictionary()
            
            for key in keysToMigrate {
                if let systemValue = loadFromKeychainDirectly(key: key) {
                    targetDict[key] = systemValue
                }
            }
            
            // 写入本地沙盒
            guard saveInternalDictionary(targetDict) else { return false }
            
            // 彻底销毁系统钥匙串内敏感残留
            for key in keysToMigrate {
                deleteFromKeychainDirectly(key: key)
            }
            
            currentStorageMode = .appInternal
            return true
        } else {
            // 应用内部加密 -> 系统钥匙串
            let sourceDict = loadInternalDictionary()
            
            var success = true
            for (key, value) in sourceDict {
                let result = saveToKeychainDirectly(key: key, value: value)
                switch result {
                case .success: break
                case .failure: success = false
                }
            }
            
            guard success else { return false }
            
            // 彻底销毁沙盒中的敏感残留加密文件
            let fileURL = getInternalStorageURL()
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            
            currentStorageMode = .systemKeychain
            return true
        }
    }
    
    // ==========================================
    // 💡 4. 底层钥匙串原生直操辅助方法 (Keychain Direct Access)
    // ==========================================
    
    @discardableResult
    private static func saveToKeychainDirectly(key: String, value: String) -> Result<Void, Error> {
        guard let data = value.data(using: .utf8) else {
            return .failure(KeychainError.conversionError)
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            return .success(())
        } else {
            return .failure(KeychainError.unexpectedStatus(status))
        }
    }
    
    private static func loadFromKeychainDirectly(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    @discardableResult
    private static func deleteFromKeychainDirectly(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
