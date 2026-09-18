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
    
    /// 本地随机密钥加密写入 cards.json
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
            
            // Local storage is separate from portable encrypted export/SyncV4.
            let cipherText = try LocalWalletCipher.seal(jsonData, purpose: "cards")
            
            let fileURL = getAppSupportDirectory().appendingPathComponent(cardFileName)
            try cipherText.write(to: fileURL, atomically: true, encoding: .utf8)
            
            return true
        } catch {
            print("写入本地加密卡片数据失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 从 sandboxed cards.json 安全读取、解密并清洗卡片数据
    /// - Parameter password: 自定义密码（若数据非 default: 前缀则必填）
    /// - Returns: 100% 清洗、健壮的卡片数组，如果无文件返回空数组
    public static func read(password: String? = nil) -> Result<[SharedCard], Error> {
        let fileURL = getAppSupportDirectory().appendingPathComponent(cardFileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .success([]) // 无文件返回空数组
        }
        
        do {
            let cipherText = try String(contentsOf: fileURL, encoding: .utf8)
            
            // 1. 解密获得 JSON 原始串
            let decoded = try LocalWalletCipher.open(cipherText, purpose: "cards", legacyPassword: password)
            if cipherText.hasPrefix(LocalWalletCipher.prefix) {
                return .success(try JSONDecoder().decode([SharedCard].self, from: decoded))
            }
            let jsonString = String(decoding: decoded, as: UTF8.self)
            
            // 2. 将 JSON 解析为基础 Any 字典数组，进行数据降级强力迁移洗涤
            guard let jsonData = jsonString.data(using: .utf8) else {
                return .failure(CryptoError.utf8DecodingFailed)
            }
            
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
