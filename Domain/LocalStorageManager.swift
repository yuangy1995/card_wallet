import Foundation

public class LocalStorageManager {
    private static let appFolderName = "CreditCardIOS"
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
    public static func write(cards: [SharedCard], password: String? = nil) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(cards)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return false }
            let cipherText = try CryptoManager.encrypt(plainText: jsonString, password: password)
            let fileURL = getDocumentDirectory().appendingPathComponent(cardFileName)
            try cipherText.write(to: fileURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("写入本地加密卡片数据失败: \(error.localizedDescription)")
            return false
        }
    }

    public static func writeInBackground(cards: [SharedCard], password: String? = nil) {
        writeQueue.async {
            _ = write(cards: cards, password: password)
        }
    }

    public static func read(password: String? = nil) -> Result<[SharedCard], Error> {
        let fileURL = getDocumentDirectory().appendingPathComponent(cardFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .success([]) }
        do {
            let cipherText = try String(contentsOf: fileURL, encoding: .utf8)
            let jsonString = try CryptoManager.decrypt(cipherText: cipherText, password: password)
            guard let jsonData = jsonString.data(using: .utf8) else { return .failure(CryptoError.utf8DecodingFailed) }
            guard let rawObjects = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] else {
                if let rawDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                   let cardsArray = rawDict["cards"] as? [[String: Any]] {
                    return .success(DataMigrationManager.migrateCardsBatch(cardsArray))
                }
                return .failure(CryptoError.utf8DecodingFailed)
            }
            return .success(DataMigrationManager.migrateCardsBatch(rawObjects))
        } catch {
            return .failure(error)
        }
    }
}
