import Foundation
import SwiftUI

public struct WebDAVBackupFile: Identifiable, Hashable {
    public var id: String { filename }
    public var filename: String
    public var size: Int64
    public var lastModified: String
}

public struct WebDAVConfig: Codable {
    public var url: String
    public var username: String
    
    public init(url: String, username: String) {
        self.url = url
        self.username = username
    }
}

public enum WebDAVError: Error, LocalizedError {
    case invalidURL
    case notConfigured
    case unauthorized
    case httpError(statusCode: Int, message: String)
    case xmlParsingFailed
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 WebDAV 服务器 URL"
        case .notConfigured: return "尚未配置 WebDAV 连接信息"
        case .unauthorized: return "WebDAV 认证失败，请检查用户名和密码"
        case .httpError(let code, let msg): return "云端响应错误 [HTTP \(code)]: \(msg)"
        case .xmlParsingFailed: return "备份列表解析失败，XML 数据格式损坏"
        case .networkError(let error): return "网络请求失败: \(error.localizedDescription)"
        }
    }
}

public class WebDAVClient {
    public static let shared = WebDAVClient()
    
    private init() {}
    
    /// 从钥匙串和 UserDefaults 加载当前的 WebDAV 配置
    public func loadConfig() -> WebDAVConfig? {
        guard let url = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username") else {
            return nil
        }
        return WebDAVConfig(url: url, username: username)
    }
    
    /// 保存 WebDAV 配置至 Keychain 及系统偏好设置
    public func saveConfig(url: String, username: String, password: String) -> Result<Void, Error> {
        // 规整 URL：确保以斜杠结尾，去掉多余空行
        var cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.hasSuffix("/") {
            cleanURL += "/"
        }
        
        guard let _ = URL(string: cleanURL) else {
            return .failure(WebDAVError.invalidURL)
        }
        
        UserDefaults.standard.set(cleanURL, forKey: "webdav_url")
        KeychainManager.save(key: "webdav_username", value: username)
        KeychainManager.save(key: "webdav_password", value: password)
        
        return .success(())
    }
    
    /// 测试 WebDAV 连接（发送 PROPFIND 请求）
    public func testConnection(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        let backupDirURL = urlStr + "credit-card-backup/"
        guard let url = URL(string: backupDirURL) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        
        // 尝试自动创建 credit-card-backup 文件夹
        createDirectoryIfNeeded(at: backupDirURL) { result in
            switch result {
            case .success:
                // 发送一个 Depth 为 0 的 PROPFIND 请求进行连通性测试
                var request = URLRequest(url: url)
                request.httpMethod = "PROPFIND"
                request.setValue("0", forHTTPHeaderField: "Depth")
                
                let authString = "\(username):\(password)"
                guard let authData = authString.data(using: .utf8) else {
                    completion(.failure(WebDAVError.xmlParsingFailed))
                    return
                }
                let base64Auth = authData.base64EncodedString()
                request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
                
                let task = URLSession.shared.dataTask(with: request) { _, response, error in
                    if let error = error {
                        completion(.failure(WebDAVError.networkError(error)))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        completion(.failure(WebDAVError.xmlParsingFailed))
                        return
                    }
                    
                    if httpResponse.statusCode == 401 {
                        completion(.failure(WebDAVError.unauthorized))
                    } else if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                        completion(.success(()))
                    } else {
                        completion(.failure(WebDAVError.httpError(statusCode: httpResponse.statusCode, message: "连接测试失败")))
                    }
                }
                task.resume()
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 上传加密备份文件
    public func uploadBackup(filename: String, cipherText: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        // 备份路径: url + credit-card-backup/filename
        let fileUrlStr = urlStr + "credit-card-backup/" + filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        guard let url = URL(string: fileUrlStr) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let authString = "\(username):\(password)"
        let base64Auth = authString.data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = cipherText.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(WebDAVError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WebDAVError.xmlParsingFailed))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(WebDAVError.unauthorized))
            } else if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                completion(.success(()))
            } else {
                completion(.failure(WebDAVError.httpError(statusCode: httpResponse.statusCode, message: "上传失败")))
            }
        }
        task.resume()
    }
    
    /// 列出远端备份目录下的所有 JSON 文件
    public func getBackupList(completion: @escaping (Result<[WebDAVBackupFile], Error>) -> Void) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        let backupDirURL = urlStr + "credit-card-backup/"
        guard let url = URL(string: backupDirURL) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        
        let authString = "\(username):\(password)"
        let base64Auth = authString.data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(WebDAVError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(WebDAVError.xmlParsingFailed))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(WebDAVError.unauthorized))
                return
            }
            
            guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                completion(.failure(WebDAVError.httpError(statusCode: httpResponse.statusCode, message: "拉取备份列表失败")))
                return
            }
            
            // 采用我们自主构建的高品质 WebDAV XML 解析器
            let parser = XMLParser(data: data)
            let webdavParser = WebDAVXMLParser(directoryPath: "/credit-card-backup/")
            parser.delegate = webdavParser
            
            if parser.parse() {
                // 按修改时间倒序排列（新备份在最前），符合人类查看逻辑
                let sortedList = webdavParser.files.sorted { f1, f2 in
                    return f1.lastModified > f2.lastModified
                }
                completion(.success(sortedList))
            } else {
                completion(.failure(WebDAVError.xmlParsingFailed))
            }
        }
        task.resume()
    }
    
    /// 下载加密备份内容
    public func downloadBackup(filename: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        let fileUrlStr = urlStr + "credit-card-backup/" + filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        guard let url = URL(string: fileUrlStr) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let authString = "\(username):\(password)"
        let base64Auth = authString.data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(WebDAVError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                completion(.failure(WebDAVError.xmlParsingFailed))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(WebDAVError.unauthorized))
            } else if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                if let cipherText = String(data: data, encoding: .utf8) {
                    completion(.success(cipherText))
                } else {
                    completion(.failure(WebDAVError.xmlParsingFailed))
                }
            } else {
                completion(.failure(WebDAVError.httpError(statusCode: httpResponse.statusCode, message: "下载失败")))
            }
        }
        task.resume()
    }
    
    /// 删除云端备份文件
    public func deleteBackup(filename: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        let fileUrlStr = urlStr + "credit-card-backup/" + filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        guard let url = URL(string: fileUrlStr) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let authString = "\(username):\(password)"
        let base64Auth = authString.data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(WebDAVError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WebDAVError.xmlParsingFailed))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(WebDAVError.unauthorized))
            } else if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                completion(.success(()))
            } else {
                completion(.failure(WebDAVError.httpError(statusCode: httpResponse.statusCode, message: "删除失败")))
            }
        }
        task.resume()
    }
    
    /// 重命名云端备份 (HTTP MOVE)
    public func renameBackup(oldFilename: String, newFilename: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        let oldFileUrlStr = urlStr + "credit-card-backup/" + oldFilename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let newFileUrlStr = urlStr + "credit-card-backup/" + newFilename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        
        guard let url = URL(string: oldFileUrlStr) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "MOVE"
        
        let authString = "\(username):\(password)"
        let base64Auth = authString.data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        
        // 关键 WebDAV 头：Destination 目标绝对地址与 Overwrite 覆盖控制
        request.setValue(newFileUrlStr, forHTTPHeaderField: "Destination")
        request.setValue("T", forHTTPHeaderField: "Overwrite")
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(WebDAVError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WebDAVError.xmlParsingFailed))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(WebDAVError.unauthorized))
            } else if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                completion(.success(()))
            } else {
                completion(.failure(WebDAVError.httpError(statusCode: httpResponse.statusCode, message: "重命名失败")))
            }
        }
        task.resume()
    }
    
    /// 如果云端 credit-card-backup 文件夹不存在，自动发送 MKCOL 创建之
    private func createDirectoryIfNeeded(at directoryURLString: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        guard let url = URL(string: directoryURLString) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        
        // 1. 先用 PROPFIND 嗅探目录是否存在
        var sniffRequest = URLRequest(url: url)
        sniffRequest.httpMethod = "PROPFIND"
        sniffRequest.setValue("0", forHTTPHeaderField: "Depth")
        
        let authString = "\(username):\(password)"
        let base64Auth = authString.data(using: .utf8)!.base64EncodedString()
        sniffRequest.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: sniffRequest) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                // 目录已存在，完美通过
                completion(.success(()))
                return
            }
            
            // 2. 状态码不属于 2xx，代表可能缺失，发送 MKCOL 一键建目录
            var mkcolRequest = URLRequest(url: url)
            mkcolRequest.httpMethod = "MKCOL"
            mkcolRequest.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
            
            let mkcolTask = URLSession.shared.dataTask(with: mkcolRequest) { _, mkcolResponse, mkcolError in
                if let mkcolError = mkcolError {
                    completion(.failure(WebDAVError.networkError(mkcolError)))
                    return
                }
                
                guard let mkcolRes = mkcolResponse as? HTTPURLResponse else {
                    completion(.failure(WebDAVError.xmlParsingFailed))
                    return
                }
                
                if mkcolRes.statusCode == 201 || mkcolRes.statusCode == 405 {
                    // 201 Created，或 405 Method Not Allowed (代表已存在) 均为合规结局
                    completion(.success(()))
                } else if mkcolRes.statusCode == 401 {
                    completion(.failure(WebDAVError.unauthorized))
                } else {
                    completion(.failure(WebDAVError.httpError(statusCode: mkcolRes.statusCode, message: "无法在云端创建备份目录")))
                }
            }
            mkcolTask.resume()
        }
        task.resume()
    }
}

// ==========================================
// 💡 WebDAV XML 解析器 (WebDAVXMLParser)
// ==========================================
internal class WebDAVXMLParser: NSObject, XMLParserDelegate {
    var files: [WebDAVBackupFile] = []
    
    private let directoryPath: String
    private var currentElement = ""
    private var currentHref = ""
    private var currentLastModified = ""
    private var currentSizeStr = ""
    
    init(directoryPath: String) {
        self.directoryPath = directoryPath
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        // 统一小写处理，解决不同 WebDAV 服务商大小写不一致的 XML 问题
        currentElement = elementName.lowercased()
        if currentElement.hasSuffix("response") {
            currentHref = ""
            currentLastModified = ""
            currentSizeStr = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if currentElement.hasSuffix("href") {
            currentHref += trimmed
        } else if currentElement.hasSuffix("getlastmodified") {
            currentLastModified += trimmed
        } else if currentElement.hasSuffix("getcontentlength") {
            currentSizeStr += trimmed
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let endElement = elementName.lowercased()
        
        if endElement.hasSuffix("response") {
            // 解析出相对路径下的文件名，并只收集 JSON 文件
            let decodedHref = currentHref.removingPercentEncoding ?? currentHref
            if decodedHref.hasSuffix(".json") {
                let nsString = decodedHref as NSString
                let filename = nsString.lastPathComponent
                
                let size = Int64(currentSizeStr) ?? 0
                
                // 将 WebDAV 的 RFC 1123 修改时间 (如: "Sat, 23 May 2026 12:00:00 GMT")
                // 转为人类直观易读的 ISO 日期字符串 YYYY-MM-DD HH:mm:ss
                var displayModifiedDate = currentLastModified
                let df = DateFormatter()
                df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                df.locale = Locale(identifier: "en_US")
                if let date = df.date(from: currentLastModified) {
                    let outDf = DateFormatter()
                    outDf.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    displayModifiedDate = outDf.string(from: date)
                }
                
                let file = WebDAVBackupFile(filename: filename, size: size, lastModified: displayModifiedDate)
                files.append(file)
            }
        }
        currentElement = ""
    }
}

// ==========================================
// 🛡️ macOS 客户端专享 WebDAV 后台智能云同步管理器
// ==========================================
public class CloudSyncManager: ObservableObject {
    public static let shared = CloudSyncManager()
    
    // 💡 基于系统首选项存储的同步配置 (通过 UserDefaults.standard 底层穿透实时同步，规避多线程后台 AppStorage 同步缺陷)
    public var enableSilentCloudBackup: Bool {
        return UserDefaults.standard.object(forKey: "enable_silent_cloud_backup") as? Bool ?? true
    }
    public var enableAutoCheckCloud: Bool {
        return UserDefaults.standard.bool(forKey: "enable_auto_check_cloud")
    }
    public var autoCheckInterval: Double {
        let val = UserDefaults.standard.double(forKey: "auto_check_interval")
        return val > 0 ? val : 300.0
    }
    public var lastAlertedCloudFile: String {
        get { UserDefaults.standard.string(forKey: "last_alerted_cloud_file") ?? "" }
        set {
            // 💡 仅在内容发生实际变更时写入，双重屏障防范任何 UserDefaults 改变通知触发的潜在重入
            if (UserDefaults.standard.string(forKey: "last_alerted_cloud_file") ?? "") != newValue {
                UserDefaults.standard.set(newValue, forKey: "last_alerted_cloud_file")
            }
        }
    }
    
    // 定时轮询相关状态
    private var checkTimer: Timer?
    private var isChecking = false
    
    // 前台检测变动提示回调闭包：(String, [SharedCard]) -> Void
    public var onCloudChangeDetected: ((String, [SharedCard]) -> Void)?
    
    private init() {
        // 💡 彻底废弃对整个 UserDefaults.didChangeNotification 的全局通知监听，
        // 因为在此类中直接或间接修改偏好设置（如写入 lastAlertedCloudFile）会引起极其严重的无限死循环死锁！
        // 所有的定时器启动与重置已交由 SwiftUI 界面及 ContentView 的 onAppear 数据流显式驱动。
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopAutoCheckTimer()
    }
    
    // ==========================================
    // 💡 模块 1：后台静默自动云同步与超量清理
    // ==========================================
    
    /// 当本地卡片账本修改且成功写入沙盒后，自动在非主线程触发静默备份至云端
    public func triggerSilentAutoUpload(cards: [SharedCard]) {
        guard enableSilentCloudBackup else { return }
        
        // 异步后台测试 WebDAV 是否就绪，非阻塞主线程 UI
        WebDAVClient.shared.testConnection { result in
            switch result {
            case .success:
                self.executeSilentUpload(cards: cards)
            case .failure(let error):
                print("⚠️ 后台自动云同步跳过：WebDAV 尚未绑定或连接失效 (详情: \(error.localizedDescription))")
            }
        }
    }
    
    private func executeSilentUpload(cards: [SharedCard]) {
        let payload = SharedBackupPayload(cards: cards)
        guard let jsonData = try? JSONEncoder().encode(payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        // 后台静默备份始终采用高强度默认安全加密 (免去用户输入解密密码负担，又保障隐私)
        guard let cipherText = try? CryptoManager.encrypt(plainText: jsonString) else {
            return
        }
        
        // 文件名格式完全对齐 Web 端，并带有 Mac 与 [自] 自动标识
        // 格式: yyyy-MM-dd-HH-mm-ss---(卡片数)[Mac][自].json
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let timeStr = df.string(from: Date())
        let filename = "\(timeStr)---(\(cards.count))[Mac][自].json"
        
        WebDAVClient.shared.uploadBackup(filename: filename, cipherText: cipherText) { result in
            switch result {
            case .success:
                print("✅ 后台静默自动云备份上传成功: \(filename)")
                
                // 自动检查并清理云端超量的自动备份文件
                self.enforceCloudSilentBackupLimit()
                
                // 💡 广播通知：云端备份已刷新，驱动云同步页面无感零延迟拉取最新云备份包
                NotificationCenter.default.post(name: Notification.Name("CloudBackupsDidChange"), object: nil)
            case .failure(let error):
                print("❌ 后台静默自动云备份上传失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 自动清理云端超量的静默自动备份文件，只保留最新的 5 条
    private func enforceCloudSilentBackupLimit() {
        WebDAVClient.shared.getBackupList { result in
            guard case .success(let files) = result else { return }
            
            // 筛选出属于 Mac 端自动静默备份的文件，例如包含 [Mac][自] 的文件
            let autoBackups = files.filter { $0.filename.contains("[Mac][自]") || $0.filename.contains("[自]") }
            
            if autoBackups.count <= 5 { return }
            
            // 超过 5 条，找出最老的进行删除
            let extraCount = autoBackups.count - 5
            let toDelete = autoBackups.suffix(extraCount)
            
            for file in toDelete {
                WebDAVClient.shared.deleteBackup(filename: file.filename) { delResult in
                    switch delResult {
                    case .success:
                        print("🛡️ 云端静默备份超量清理：成功擦除老旧自动备份: \(file.filename)")
                    case .failure(let error):
                        print("⚠️ 清理老旧云端自动备份失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // ==========================================
    // 💡 模块 2：实时云端变动感知定时器与智能比对
    // ==========================================
    
    @objc public func setupTimerFromConfig() {
        DispatchQueue.main.async {
            // 💡 每次配置通知变动时，先清空一下 lastAlertedCloudFile 缓存，确保变动探测能敏锐重活！
            self.lastAlertedCloudFile = ""
            
            if self.enableAutoCheckCloud {
                self.startAutoCheckTimer()
            } else {
                self.stopAutoCheckTimer()
            }
        }
    }
    
    public func startAutoCheckTimer() {
        stopAutoCheckTimer()
        
        // 💡 如果当前系统处于锁定状态，为了绝对降低功耗和网络占用，坚决不启动定时轮询检测定时器
        guard !AutoLockManager.shared.isLocked else { return }
        
        // 💡 启动或重置定时器时，强制清空上一次已提醒文件的缓存，确保每次开机或更新配置都能获得首发即时探测比对！
        lastAlertedCloudFile = ""
        
        let interval = autoCheckInterval
        // 绑定一个防抖的周期定时器
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performCloudChangeDetection()
        }
        
        // 启动时立即在 3.0 秒后进行一次静默嗅探
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.performCloudChangeDetection()
        }
        
        print("⏰ 云端变动实时感知引擎激活！频率：每 \(Int(interval)) 秒轮询检测一次。")
    }
    
    public func stopAutoCheckTimer() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    /// 执行后台云端变动嗅探与数据比对
    public func performCloudChangeDetection(currentCardsOverride: [SharedCard]? = nil) {
        // 💡 如果系统被锁定了，立刻停止检测定时器，降低没使用时候的软件占用与能耗，并安全退出
        guard !AutoLockManager.shared.isLocked else {
            stopAutoCheckTimer()
            return
        }
        
        guard enableAutoCheckCloud, !isChecking else { return }
        isChecking = true
        
        // 读取当前本地最新的卡片作为对比源
        let localCards: [SharedCard]
        if let override = currentCardsOverride {
            localCards = override
        } else {
            let readRes = LocalStorageManager.read()
            switch readRes {
            case .success(let cards):
                localCards = cards
            case .failure:
                isChecking = false
                return
            }
        }
        
        // 1. 获取云端列表
        WebDAVClient.shared.getBackupList { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let files):
                // 筛选出最新时间的备份文件
                guard let latestFile = files.first else {
                    self.isChecking = false
                    return
                }
                
                let filename = latestFile.filename
                
                // 如果文件名跟我们记录的上一次已提醒一致，说明没变过，直接返回，避免浪费网络流量
                if filename == self.lastAlertedCloudFile {
                    self.isChecking = false
                    return
                }
                
                // 2. 异步下载最新备份
                WebDAVClient.shared.downloadBackup(filename: filename) { downResult in
                    defer { self.isChecking = false }
                    
                    switch downResult {
                    case .success(let cipherText):
                        self.processCloudFileContent(cipherText: cipherText, filename: filename, localCards: localCards)
                    case .failure(let error):
                        print("❌ 云端变动感知下载失败: \(error.localizedDescription)")
                    }
                }
                
            case .failure(let error):
                print("⚠️ 云端变动感知获取列表失败: \(error.localizedDescription)")
                self.isChecking = false
            }
        }
    }
    
    private func processCloudFileContent(cipherText: String, filename: String, localCards: [SharedCard]) {
        do {
            // 尝试静默解密 (默认安全解密)
            let jsonString = try CryptoManager.decrypt(cipherText: cipherText)
            self.compareCloudWithLocal(jsonString: jsonString, filename: filename, localCards: localCards)
        } catch {
            // 解密失败：可能是自定义密码加密。
            // 💡 警告：如果是自定义密码文件，由于我们没有密码，我们无法在后台直接解密。
            // 我们可以在前台抛出提醒：检测到云端存在新账本，但使用了自定义密码，需要到云同步页面输入密码以比对！
            print("🔑 检测到云端备份 \(filename) 采用了自定义密码加密保护，跳过静默比对")
            
            // 为了避免重复弹窗打扰，我们依然要把 lastAlertedCloudFile 记录，
            // 且在前台弹出一次温和的需要密码比对提示
            DispatchQueue.main.async {
                // self.lastAlertedCloudFile = filename
                self.onCloudChangeDetected?(filename, [])
            }
        }
    }
    
    private func compareCloudWithLocal(jsonString: String, filename: String, localCards: [SharedCard]) {
        let cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let parsedObject = DataMigrationManager.recursivelyParseJSON(cleaned) else {
            print("❌ 后台云端变动感知：无法递归解析备份 JSON 数据")
            return
        }
        
        var rawCards: [[String: Any]] = []
        if let array = parsedObject as? [[String: Any]] {
            rawCards = array
        } else if let dict = parsedObject as? [String: Any] {
            if let cardsArray = dict["cards"] as? [[String: Any]] {
                rawCards = cardsArray
            } else if let cardsArray = dict["data"] as? [[String: Any]] {
                rawCards = cardsArray
            }
        }
        
        let cloudCards = DataMigrationManager.migrateCardsBatch(rawCards)
        
        // 3. 执行核心比对算法 (智能判断是否不一致)
        let isDifferent = checkDataDifference(local: localCards, cloud: cloudCards)
        
        if isDifferent {
            DispatchQueue.main.async {
                print("⚡️ 检测到云端新账本 \(filename) 与本地存在差异！")
                // 标记已感知，但因为数据仍不一致，不应锁定该文件，允许未恢复前周期轮询继续抛出警报
                // self.lastAlertedCloudFile = filename
                // 回调通知 UI
                self.onCloudChangeDetected?(filename, cloudCards)
            }
        } else {
            // 如果比对完全一致，则静默更新 lastAlertedCloudFile
            DispatchQueue.main.async {
                self.lastAlertedCloudFile = filename
            }
        }
    }
    
    /// 比对本地与云端卡片数据是否不一致
    private func checkDataDifference(local: [SharedCard], cloud: [SharedCard]) -> Bool {
        if local.count != cloud.count { return true }
        
        let localMap = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        
        for cloudCard in cloud {
            guard let localCard = localMap[cloudCard.id] else {
                return true // 存在本地没有的卡片
            }
            
            // 比较修改时间
            if cloudCard.lastModifyTime != localCard.lastModifyTime {
                return true
            }
            
            // 比较几个关键字段
            if cloudCard.bank != localCard.bank ||
               cloudCard.limit != localCard.limit ||
               cloudCard.type != localCard.type ||
               cloudCard.isSharedLimit != localCard.isSharedLimit ||
               cloudCard.isQualified != localCard.isQualified ||
               cloudCard.cardNumber != localCard.cardNumber ||
               cloudCard.alias != localCard.alias ||
               cloudCard.accountBillDate != localCard.accountBillDate ||
               cloudCard.dueDate != localCard.dueDate {
                return true
            }
        }
        
        return false
    }
}
