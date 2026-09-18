import Foundation

public class LocalStorageManager {
    
    private static let appFolderName = "CardWallet"
    private static let cardFileName = "cards.json"
    
    /// 获取应用专属的沙盒 Application Support 目录路径
    private static func getAppSupportDirectory() -> URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDirectory = paths[0].appendingPathComponent(appFolderName, isDirectory: true)
        
        // 自动创建父目录
        if !FileManager.default.fileExists(atPath: appSupportDirectory.path) {
            try? FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        return appSupportDirectory
    }
    
    /// 使用本机随机密钥保存 cards.json；不改变导出或云同步格式。
    /// - Parameters:
    ///   - cards: 卡片数据数组
    ///   - password: 自定义密码（可选）
    /// - Returns: 是否写入成功
    @discardableResult
    public static func write(cards: [SharedCard], password: String? = nil) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(cards)
            
            let ciphertext = try LocalDataCipher.shared.seal(jsonData)
            let fileURL = getAppSupportDirectory().appendingPathComponent(cardFileName)
            try ciphertext.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)

            return true
        } catch {
            print("写入本地加密卡片数据失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 从 sandboxed cards.json 安全读取、解密并清洗卡片数据
    /// - Parameter password: 自定义密码（若数据非 default: 前缀则必填）
    /// - Returns: 无文件返回空数组；读取或解密失败保留原文件并返回错误。
    public static func read(password: String? = nil) -> Result<[SharedCard], Error> {
        let fileURL = getAppSupportDirectory().appendingPathComponent(cardFileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .success([]) // 无文件返回空数组
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let jsonData = try LocalDataCipher.shared.open(data, legacyPassword: password)

            guard let rawObjects = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] else {
                // 如果是对象外壳格式，尝试特殊兼容解析 {"cards": [...]}
                if let rawDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                   let cardsArray = rawDict["cards"] as? [[String: Any]] {
                    let migrated = DataMigrationManager.migrateCardsBatch(cardsArray)
                    return .success(migrated)
                }
                return .failure(CryptoError.utf8DecodingFailed)
            }
            
            // 3. 原生 Swift 级数据清洗洗涤
            let migratedCards = DataMigrationManager.migrateCardsBatch(rawObjects)
            return .success(migratedCards)
            
        } catch {
            return .failure(error)
        }
    }
}
