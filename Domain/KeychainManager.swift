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

public class KeychainManager {
    private static let serviceName = "com.applist.creditcardios.webdav"

    private static func getInternalStorageURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("CreditCardIOS", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir.appendingPathComponent("security_credentials.enc")
    }

    private static func loadInternalDictionary() -> [String: String] {
        let fileURL = getInternalStorageURL()
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let cipherText = try? String(contentsOf: fileURL, encoding: .utf8),
              let jsonString = try? CryptoManager.decrypt(cipherText: cipherText, password: "Credential.Default.AES.Key.@@1995"),
              let data = jsonString.data(using: .utf8) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String]) ?? [:]
    }

    private static func saveInternalDictionary(_ dict: [String: String]) -> Bool {
        let fileURL = getInternalStorageURL()
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let jsonString = String(data: data, encoding: .utf8),
              let cipherText = try? CryptoManager.encrypt(plainText: jsonString, password: "Credential.Default.AES.Key.@@1995") else { return false }
        do {
            try cipherText.write(to: fileURL, atomically: true, encoding: .utf8)
            return true
        } catch { return false }
    }

    @discardableResult
    public static func save(key: String, value: String) -> Result<Void, Error> {
        var dict = loadInternalDictionary()
        dict[key] = value
        return saveInternalDictionary(dict) ? .success(()) : .failure(KeychainError.conversionError)
    }

    public static func load(key: String) -> String? {
        loadInternalDictionary()[key]
    }

    @discardableResult
    public static func delete(key: String) -> Bool {
        var dict = loadInternalDictionary()
        dict.removeValue(forKey: key)
        return saveInternalDictionary(dict)
    }

    @discardableResult
    public static func clearAllCredentials() -> Bool {
        let fileURL = getInternalStorageURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        return true
    }
}
