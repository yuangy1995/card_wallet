import Foundation

public class LocalStorageManager {
    private static let appFolderName = "CardWallet"
    private static let cardFileName = "cards.json"
    private static let writeQueue = DispatchQueue(label: "com.applist.credit-card-ios.local-storage", qos: .utility)

    private static func getDocumentDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let appDir = paths[0].appendingPathComponent(appFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        return appDir
    }

    @discardableResult
    public static func write(cards: [SharedCard]) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(cards)
            let encryptedData = try CryptoManager.encryptLocalData(jsonData)
            let fileURL = getDocumentDirectory().appendingPathComponent(cardFileName)
            try encryptedData.write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path)
            return true
        } catch {
            print("写入本地加密卡片数据失败: \(error.localizedDescription)")
            return false
        }
    }

    public static func writeInBackground(cards: [SharedCard]) {
        writeQueue.async {
            _ = write(cards: cards)
        }
    }

    public static func read() -> Result<[SharedCard], Error> {
        let fileURL = getDocumentDirectory().appendingPathComponent(cardFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .success([]) }
        do {
            let encryptedData = try Data(contentsOf: fileURL)
            let jsonData = try CryptoManager.decryptLocalData(encryptedData)
            return .success(try JSONDecoder().decode([SharedCard].self, from: jsonData))
        } catch {
            return .failure(error)
        }
    }
}
