import Foundation

public struct LocalBackupRecord: Identifiable, Codable, Hashable {
    public var id: String { filename }
    public var filename: String
    public var cardCount: Int
    public var backupTime: String
    public var size: Int64
}

public class LocalStorageManager {
    
    private static let appFolderName = "CreditCardMac"
    private static let cardFileName = "cards.json"
    private static let backupFolderName = "Backups"
    
    private static var autoBackupTimer: Timer?
    private static var pendingBackupData: [SharedCard]?
    
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
    
    /// 获取本地备份文件夹路径
    private static func getBackupDirectory() -> URL {
        let backupDirectory = getAppSupportDirectory().appendingPathComponent(backupFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: backupDirectory.path) {
            try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        return backupDirectory
    }
    
    /// 100% 稳健的加密数据写入 cards.json
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
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                return false
            }
            
            // 采用与 Web 端 100% 互通的 AES 默认/自定义密码加密
            let cipherText = try CryptoManager.encrypt(plainText: jsonString, password: password)
            
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
            let jsonString = try CryptoManager.decrypt(cipherText: cipherText, password: password)
            
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
    
    // ==========================================
    // 💡 本地多版本自动备份核心算法 (Auto-Backup)
    // ==========================================
    
    private static func scheduleAutoBackup(cards: [SharedCard]) {
        pendingBackupData = cards
        
        // 如果已有定时器在等待，不予打扰，坚持 1 分钟合并原则
        if autoBackupTimer != nil {
            return
        }
        
        // 开启 1 分钟 (60秒) 自动备份定时器
        autoBackupTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { _ in
            if let dataToBackup = pendingBackupData {
                createLocalBackup(cards: dataToBackup)
            }
            autoBackupTimer = nil
            pendingBackupData = nil
        }
    }
    
    /// 创建本地物理备份 (支持手动与自动触发，带 50 版本上限强限制)
    @discardableResult
    public static func createLocalBackup(cards: [SharedCard], isManual: Bool = false) -> Bool {
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(cards)
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                return false
            }
            
            // 始终用默认密码加密备份数据
            let cipherText = try CryptoManager.encrypt(plainText: jsonString)
            
            // 文件名格式: YYYY-MM-DD-HH-mm-ss---(cardCount)[手动/自动].json
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let timestamp = df.string(from: Date())
            let tag = isManual ? "[手]" : "[自]"
            let filename = "\(timestamp)---\(cards.count)\(tag).json"
            
            let backupURL = getBackupDirectory().appendingPathComponent(filename)
            try cipherText.write(to: backupURL, atomically: true, encoding: .utf8)
            
            print("本地备份 \(filename) 创建成功！")
            
            // 🛡️ 强制执行 50 条上限约束，多出部分按时间删掉最早备份
            enforceBackupLimit()
            
            // 💡 广播通知：本地自动备份成功，驱动设置大界面零延迟实时刷新历史列表
            NotificationCenter.default.post(name: Notification.Name("LocalBackupsDidChange"), object: nil)
            
            return true
        } catch {
            print("创建本地备份失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 列出本地所有的物理备份记录
    public static func listLocalBackups() -> [LocalBackupRecord] {
        let backupDir = getBackupDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: .skipsHiddenFiles) else {
            return []
        }
        
        var records: [LocalBackupRecord] = []
        let outDf = DateFormatter()
        outDf.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for fileURL in files where fileURL.pathExtension == "json" {
            let filename = fileURL.lastPathComponent
            
            // 提取卡片数量 (从文件名提取 ---X)
            var cardCount = 0
            let components = filename.components(separatedBy: "---")
            if components.count >= 2 {
                let remaining = components[1]
                let numberString = remaining.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                cardCount = Int(numberString) ?? 0
            }
            
            let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            let modDate = (attrs?[.modificationDate] as? Date) ?? Date()
            
            let record = LocalBackupRecord(
                filename: filename,
                cardCount: cardCount,
                backupTime: outDf.string(from: modDate),
                size: size
            )
            records.append(record)
        }
        
        // 按时间倒序排序（新备份在前）
        return records.sorted { $0.filename > $1.filename }
    }
    
    /// 读取指定的本地备份文件，供差异预览使用
    public static func loadLocalBackupForPreview(filename: String, password: String? = nil) -> Result<[SharedCard], Error> {
        let backupURL = getBackupDirectory().appendingPathComponent(filename)
        do {
            let cipherText = try String(contentsOf: backupURL, encoding: .utf8)
            let jsonString = try CryptoManager.decrypt(cipherText: cipherText, password: password)
            
            guard let jsonData = jsonString.data(using: .utf8),
                  let rawObjects = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] else {
                return .failure(CryptoError.utf8DecodingFailed)
            }
            
            let migrated = DataMigrationManager.migrateCardsBatch(rawObjects)
            return .success(migrated)
        } catch {
            return .failure(error)
        }
    }
    
    /// 删除指定的本地备份
    public static func deleteLocalBackup(filename: String) -> Bool {
        let backupURL = getBackupDirectory().appendingPathComponent(filename)
        do {
            try FileManager.default.removeItem(at: backupURL)
            return true
        } catch {
            return false
        }
    }
    
    /// 50 条上限清理算法
    private static func enforceBackupLimit() {
        let backups = listLocalBackups()
        if backups.count <= 50 {
            return
        }
        
        // 多出 50 条，删掉最早的几条
        let extraCount = backups.count - 50
        let toDelete = backups.suffix(extraCount)
        
        for record in toDelete {
            _ = deleteLocalBackup(filename: record.filename)
            print("超出50条备份上限，已自动擦除历史备份: \(record.filename)")
        }
    }
}
