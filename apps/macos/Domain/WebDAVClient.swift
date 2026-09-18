import Foundation

private final class ProgressBox: @unchecked Sendable {
    var value: Int64 = 0
    init(value: Int64 = 0) {
        self.value = value
    }
}

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let onProgress: (Int64) -> Void

    init(onProgress: @escaping (Int64) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        onProgress(totalBytesSent)
    }
}

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: (Int64) -> Void
    private let onFinish: (URL?, URLResponse?, Error?, URLSession) -> Void
    private let lastBytesWritten = ProgressBox()

    init(
        onProgress: @escaping (Int64) -> Void,
        onFinish: @escaping (URL?, URLResponse?, Error?, URLSession) -> Void
    ) {
        self.onProgress = onProgress
        self.onFinish = onFinish
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let delta = totalBytesWritten - lastBytesWritten.value
        lastBytesWritten.value = totalBytesWritten
        if delta > 0 {
            onProgress(delta)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        onFinish(location, downloadTask.response, nil, session)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            onFinish(nil, task.response, error, session)
        }
    }
}

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
    private static let transferTimeout: TimeInterval = 300
    private static let transferResourceTimeout: TimeInterval = 3600
    
    private let requestRegistry = WebDAVRequestRegistry()
    public func cancelRequests() { requestRegistry.cancelAll() }
    public func setSuspended(_ value: Bool) { requestRegistry.setSuspended(value) }
    private init() {}

    private static func transferSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = transferTimeout
        configuration.timeoutIntervalForResource = transferResourceTimeout
        configuration.waitsForConnectivity = true
        return configuration
    }
    
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
        
        if case .failure(let error) = KeychainManager.save(key: "webdav_username", value: username) { return .failure(error) }
        if case .failure(let error) = KeychainManager.save(key: "webdav_password", value: password) { return .failure(error) }
        UserDefaults.standard.set(cleanURL, forKey: "webdav_url")
        
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
                self.requestRegistry.start(task)
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 上传加密备份文件
    public func uploadBackup(
        filename: String,
        cipherText: String,
        onProgress: ((Int64) -> Void)? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let data = cipherText.data(using: .utf8) else {
            completion(.failure(WebDAVError.xmlParsingFailed))
            return
        }
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        guard let url = backupFileURL(baseURLString: urlStr, filename: filename) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = Self.transferTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let authString = "\(username):\(password)"
        let base64Auth = authString.data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")

        let completionHandler: (Data?, URLResponse?, Error?) -> Void = { _, response, error in
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

        if let onProgress {
            let delegate = UploadProgressDelegate(onProgress: onProgress)
            let session = URLSession(configuration: Self.transferSessionConfiguration(), delegate: delegate, delegateQueue: nil)
            let task = session.uploadTask(with: request, from: data) { data, response, error in
                session.finishTasksAndInvalidate()
                completionHandler(data, response, error)
            }
            self.requestRegistry.start(task)
        } else {
            request.httpBody = data
            let session = URLSession(configuration: Self.transferSessionConfiguration())
            let task = session.dataTask(with: request) { data, response, error in
                session.finishTasksAndInvalidate()
                completionHandler(data, response, error)
            }
            self.requestRegistry.start(task)
        }
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
        self.requestRegistry.start(task)
    }
    
    /// 下载加密备份内容
    public func downloadBackup(
        filename: String,
        onProgress: ((Int64) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        guard let url = backupFileURL(baseURLString: urlStr, filename: filename) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Self.transferTimeout
        
        let authString = "\(username):\(password)"
        let base64Auth = authString.data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")

        let handleResponse: (Data?, URLResponse?, Error?) -> Void = { data, response, error in
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

        if let onProgress {
            let delegate = DownloadProgressDelegate(
                onProgress: onProgress,
                onFinish: { location, response, error, session in
                    session.finishTasksAndInvalidate()
                    if let error {
                        handleResponse(nil, response, error)
                        return
                    }
                    guard let location else {
                        handleResponse(nil, response, WebDAVError.xmlParsingFailed)
                        return
                    }
                    do {
                        let data = try Data(contentsOf: location)
                        handleResponse(data, response, nil)
                    } catch {
                        handleResponse(nil, response, error)
                    }
                }
            )
            let session = URLSession(configuration: Self.transferSessionConfiguration(), delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: request)
            self.requestRegistry.start(task)
        } else {
            let session = URLSession(configuration: Self.transferSessionConfiguration())
            let task = session.dataTask(with: request) { data, response, error in
                session.finishTasksAndInvalidate()
                handleResponse(data, response, error)
            }
            self.requestRegistry.start(task)
        }
    }
    
    /// 删除云端备份文件
    public func deleteBackup(filename: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        guard let url = backupFileURL(baseURLString: urlStr, filename: filename) else {
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
        self.requestRegistry.start(task)
    }
    
    /// 重命名云端备份 (HTTP MOVE)
    public func renameBackup(oldFilename: String, newFilename: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        
        guard let url = backupFileURL(baseURLString: urlStr, filename: oldFilename),
              let newURL = backupFileURL(baseURLString: urlStr, filename: newFilename) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "MOVE"
        
        let authString = "\(username):\(password)"
        let base64Auth = authString.data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        
        // 关键 WebDAV 头：Destination 目标绝对地址与 Overwrite 覆盖控制
        request.setValue(newURL.absoluteString, forHTTPHeaderField: "Destination")
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
        self.requestRegistry.start(task)
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
            self.requestRegistry.start(mkcolTask)
        }
        self.requestRegistry.start(task)
    }

    private func backupFileURL(baseURLString: String, filename: String) -> URL? {
        guard let baseURL = URL(string: baseURLString) else {
            return nil
        }
        return baseURL
            .appendingPathComponent("credit-card-backup", isDirectory: true)
            .appendingPathComponent(filename, isDirectory: false)
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
