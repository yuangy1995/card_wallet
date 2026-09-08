import Foundation
import Security

/// 保留现有调用接口；正常读写只使用本地加密文件。
/// 系统钥匙串仅用于首次升级时读取旧凭证，不再写入或删除旧记录。
public class KeychainManager {
    private static let serviceName = "com.applist.creditcardmac.webdav"
    private static let lock = NSRecursiveLock()
    private static let legacyReads = CredentialReadCache()
    private static var preparation: Result<Void, Error>?
    private static let store = LocalCredentialStore(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CardWallet", isDirectory: true))

    private static func prepareLocalStorage() throws {
        if let preparation { return try preparation.get() }
        let result = Result<Void, Error> {
            if UserDefaults.standard.string(forKey: "security_storage_mode") != "appInternal" {
                try store.importLegacy(keys: ["webdav_username", "webdav_password", "webdav_sync_password_v4", "app_lock_password", "webdav_config"]) {
                    try readLegacyKeychain(key: $0).get()
                }
                UserDefaults.standard.set("appInternal", forKey: "security_storage_mode")
                legacyReads.removeAll()
            }
        }
        preparation = result
        try result.get()
    }

    public static func load(key: String) -> String? { try? loadResult(key: key).get() }

    static func loadResult(key: String) -> Result<String?, Error> {
        lock.lock()
        defer { lock.unlock() }
        return Result {
            try prepareLocalStorage()
            return try store.load()[key]
        }
    }

    @discardableResult
    public static func save(key: String, value: String) -> Result<Void, Error> {
        lock.lock()
        defer { lock.unlock() }
        return Result {
            try prepareLocalStorage()
            var credentials = try store.load()
            credentials[key] = value
            try store.save(credentials)
        }
    }

    @discardableResult
    public static func delete(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        do {
            try prepareLocalStorage()
            var credentials = try store.load()
            credentials.removeValue(forKey: key)
            try store.save(credentials)
            return true
        } catch { return false }
    }

    /// 迁移未完成时，只有用户主动重试才再次申请授权。
    static func retryFailedReads() {
        lock.lock()
        defer { lock.unlock() }
        if case .failure = preparation {
            preparation = nil
            legacyReads.retryFailures()
        }
    }

    private static func readLegacyKeychain(key: String) -> Result<String?, Error> {
        legacyReads.read(key: key) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { return .success(nil) }
            guard status == errSecSuccess else { return .failure(NSError(domain: NSOSStatusErrorDomain, code: Int(status))) }
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                return .failure(CryptoError.utf8DecodingFailed)
            }
            return .success(value)
        }
    }
}
