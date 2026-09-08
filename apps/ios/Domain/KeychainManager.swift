import Foundation
import Security

public enum KeychainError: Error, LocalizedError, Sendable {
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

public final class KeychainManager {
    private static let serviceName = "com.applist.creditcardios.secure-storage"

    private static func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
    }

    @discardableResult
    public static func save(key: String, value: String) -> Result<Void, Error> {
        guard let data = value.data(using: .utf8) else {
            return .failure(KeychainError.conversionError)
        }
        return saveData(key: key, data: data)
    }

    @discardableResult
    public static func saveData(key: String, data: Data) -> Result<Void, Error> {
        var query = baseQuery(key: key)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return .success(())
        }
        if updateStatus != errSecItemNotFound {
            return .failure(KeychainError.unexpectedStatus(updateStatus))
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            return .failure(addStatus == errSecDuplicateItem ? KeychainError.duplicateItem : KeychainError.unexpectedStatus(addStatus))
        }
        return .success(())
    }

    public static func load(key: String) -> String? {
        guard let data = loadData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func loadData(key: String) -> Data? {
        var query = baseQuery(key: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = kCFBooleanTrue

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    public static func delete(key: String) -> Bool {
        let status = SecItemDelete(baseQuery(key: key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    @discardableResult
    public static func clearAllCredentials() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
