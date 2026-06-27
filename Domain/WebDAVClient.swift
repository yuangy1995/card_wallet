import Foundation

private final class ProgressBox: @unchecked Sendable {
    var value: Int64 = 0
    init(value: Int64 = 0) {
        self.value = value
    }
}

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Int64) -> Void

    init(onProgress: @escaping @Sendable (Int64) -> Void) {
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
    private let onProgress: @Sendable (Int64) -> Void
    private let onFinish: @Sendable (URL?, URLResponse?, Error?, URLSession) -> Void
    private let lastBytesWritten = ProgressBox(value: 0)

    init(
        onProgress: @escaping @Sendable (Int64) -> Void,
        onFinish: @escaping @Sendable (URL?, URLResponse?, Error?, URLSession) -> Void
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
        if let error = error {
            onFinish(nil, task.response, error, session)
        }
    }
}

public struct WebDAVConfig: Codable, Sendable {
    public var url: String
    public var username: String
    public init(url: String, username: String) {
        self.url = url
        self.username = username
    }
}

public struct WebDAVBackupFile: Codable, Hashable, Sendable {
    public var filename: String
    public var size: Int64
    public var lastModified: String

    public var lastModifiedDate: Date? {
        WebDAVClient.parseHTTPDate(lastModified)
    }
}

public enum WebDAVError: Error, LocalizedError, Sendable {
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

public final class WebDAVClient: Sendable {
    public static let shared = WebDAVClient()
    private static let backupDirectoryName = "credit-card-backup"
    private static let requestTimeout: TimeInterval = 45
    private static let transferTimeout: TimeInterval = 300
    private static let transferResourceTimeout: TimeInterval = 3600

    private init() {}

    private static func transferSessionConfiguration(allowsCellularAccess: Bool) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = transferTimeout
        configuration.timeoutIntervalForResource = transferResourceTimeout
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = allowsCellularAccess
        return configuration
    }

    public func loadConfig() -> WebDAVConfig? {
        guard let rawURL = UserDefaults.standard.string(forKey: "webdav_url"),
              let rawUsername = KeychainManager.load(key: "webdav_username") else { return nil }
        let url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !username.isEmpty else { return nil }
        return WebDAVConfig(url: url, username: username)
    }

    public func hasConnectionConfig() -> Bool {
        guard loadConfig() != nil else { return false }
        let password = KeychainManager.load(key: "webdav_password")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !password.isEmpty
    }

    public func hasCompleteSyncConfig() -> Bool {
        let syncPassword = KeychainManager.load(key: "webdav_sync_password_v4")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return hasConnectionConfig() && !syncPassword.isEmpty
    }

    public func saveConfig(url: String, username: String, password: String) -> Result<Void, Error> {
        var cleanURL = sanitizeBaseURL(url)
        cleanURL += "/"
        guard URL(string: cleanURL) != nil else { return .failure(WebDAVError.invalidURL) }

        switch KeychainManager.save(key: "webdav_username", value: username) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
        if !password.isEmpty {
            switch KeychainManager.save(key: "webdav_password", value: password) {
            case .success:
                break
            case .failure(let error):
                return .failure(error)
            }
        }

        UserDefaults.standard.set(cleanURL, forKey: "webdav_url")
        return .success(())
    }

    public func testConnection(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        ensureBackupDirectory(baseURLString: urlStr, username: username, password: password, completion: completion)
    }

    public func testConnection(
        url: String,
        username: String,
        password: String,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        var cleanURL = sanitizeBaseURL(url)
        cleanURL += "/"
        guard URL(string: cleanURL) != nil else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        ensureBackupDirectory(baseURLString: cleanURL, username: username, password: password, completion: completion)
    }

    public func getBackupList(
        allowsCellularAccess: Bool = true,
        completion: @escaping @Sendable (Result<[WebDAVBackupFile], Error>) -> Void
    ) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }

        ensureBackupDirectory(
            baseURLString: urlStr,
            username: username,
            password: password,
            allowsCellularAccess: allowsCellularAccess
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                guard let url = URL(string: Self.backupDirectoryURLString(from: urlStr)) else {
                    completion(.failure(WebDAVError.invalidURL))
                    return
                }
                var request = URLRequest(url: url)
                request.httpMethod = "PROPFIND"
                request.timeoutInterval = Self.requestTimeout
                request.allowsCellularAccess = allowsCellularAccess
                request.setValue("1", forHTTPHeaderField: "Depth")
                request.setValue(self.authHeader(username: username, password: password), forHTTPHeaderField: "Authorization")

                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error {
                        completion(.failure(WebDAVError.networkError(error)))
                        return
                    }
                    guard let httpResponse = response as? HTTPURLResponse else {
                        completion(.failure(WebDAVError.xmlParsingFailed))
                        return
                    }
                    if httpResponse.statusCode == 401 {
                        completion(.failure(WebDAVError.unauthorized))
                        return
                    }
                    guard (200..<300).contains(httpResponse.statusCode) || httpResponse.statusCode == 207,
                          let data else {
                        completion(.failure(WebDAVError.httpError(statusCode: httpResponse.statusCode, message: "备份列表读取失败")))
                        return
                    }
                    let parser = WebDAVDirectoryParser(data: data)
                    let files = parser.parse()
                        .filter { $0.filename.hasSuffix(".json") }
                        .sorted {
                            let leftDate = $0.lastModifiedDate ?? .distantPast
                            let rightDate = $1.lastModifiedDate ?? .distantPast
                            if leftDate != rightDate { return leftDate > rightDate }
                            return $0.filename > $1.filename
                        }
                    completion(.success(files))
                }.resume()
            }
        }
    }

    public func uploadBackup(
        filename: String,
        cipherText: String,
        allowsCellularAccess: Bool = true,
        onProgress: (@Sendable (Int64) -> Void)? = nil,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
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
        ensureBackupDirectory(
            baseURLString: urlStr,
            username: username,
            password: password,
            allowsCellularAccess: allowsCellularAccess
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.upload(
                    data: data,
                    to: Self.backupFileURLString(baseURLString: urlStr, filename: filename),
                    allowsCellularAccess: allowsCellularAccess,
                    onProgress: onProgress,
                    completion: completion
                )
            }
        }
    }

    public func downloadBackup(
        filename: String,
        allowsCellularAccess: Bool = true,
        onProgress: (@Sendable (Int64) -> Void)? = nil,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url") else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        download(
            from: Self.backupFileURLString(baseURLString: urlStr, filename: filename),
            allowsCellularAccess: allowsCellularAccess,
            onProgress: onProgress
        ) { result in
            switch result {
            case .success(let data):
                guard let text = String(data: data, encoding: .utf8) else {
                    completion(.failure(WebDAVError.xmlParsingFailed))
                    return
                }
                completion(.success(text))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func deleteBackup(filename: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard let urlStr = UserDefaults.standard.string(forKey: "webdav_url"),
              let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password"),
              let url = URL(string: Self.backupFileURLString(baseURLString: urlStr, filename: filename)) else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = Self.requestTimeout
        request.setValue(authHeader(username: username, password: password), forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                completion(.failure(WebDAVError.networkError(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) || httpResponse.statusCode == 404 else {
                completion(.failure(WebDAVError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "删除旧同步文件失败")))
                return
            }
            completion(.success(()))
        }.resume()
    }

    public func upload(
        data: Data,
        to urlStr: String,
        allowsCellularAccess: Bool = true,
        onProgress: (@Sendable (Int64) -> Void)? = nil,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password"),
              let url = URL(string: urlStr) else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = Self.transferTimeout
        request.allowsCellularAccess = allowsCellularAccess
        request.setValue(authHeader(username: username, password: password), forHTTPHeaderField: "Authorization")

        if let onProgress {
            let delegate = UploadProgressDelegate(onProgress: onProgress)
            let session = URLSession(
                configuration: Self.transferSessionConfiguration(allowsCellularAccess: allowsCellularAccess),
                delegate: delegate,
                delegateQueue: nil
            )
            let task = session.uploadTask(with: request, from: data) { _, response, error in
                session.finishTasksAndInvalidate()
                if let error {
                    completion(.failure(WebDAVError.networkError(error)))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    completion(.failure(WebDAVError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "上传失败")))
                    return
                }
                completion(.success(()))
            }
            task.resume()
        } else {
            request.httpBody = data
            let session = URLSession(
                configuration: Self.transferSessionConfiguration(allowsCellularAccess: allowsCellularAccess)
            )
            session.dataTask(with: request) { _, response, error in
                session.finishTasksAndInvalidate()
                if let error {
                    completion(.failure(WebDAVError.networkError(error)))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    completion(.failure(WebDAVError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "上传失败")))
                    return
                }
                completion(.success(()))
            }.resume()
        }
    }

    public func download(
        from urlStr: String,
        allowsCellularAccess: Bool = true,
        onProgress: (@Sendable (Int64) -> Void)? = nil,
        completion: @escaping @Sendable (Result<Data, Error>) -> Void
    ) {
        guard let username = KeychainManager.load(key: "webdav_username"),
              let password = KeychainManager.load(key: "webdav_password"),
              let url = URL(string: urlStr) else {
            completion(.failure(WebDAVError.notConfigured))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.transferTimeout
        request.allowsCellularAccess = allowsCellularAccess
        request.setValue(authHeader(username: username, password: password), forHTTPHeaderField: "Authorization")

        if let onProgress {
            let delegate = DownloadProgressDelegate(
                onProgress: onProgress,
                onFinish: { location, response, error, session in
                    session.finishTasksAndInvalidate()
                    if let error = error {
                        completion(.failure(WebDAVError.networkError(error)))
                        return
                    }
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        completion(.failure(WebDAVError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "下载失败")))
                        return
                    }
                    guard let location = location else {
                        completion(.failure(WebDAVError.xmlParsingFailed))
                        return
                    }
                    do {
                        let data = try Data(contentsOf: location)
                        completion(.success(data))
                    } catch {
                        completion(.failure(WebDAVError.networkError(error)))
                    }
                }
            )
            let session = URLSession(
                configuration: Self.transferSessionConfiguration(allowsCellularAccess: allowsCellularAccess),
                delegate: delegate,
                delegateQueue: nil
            )
            let task = session.downloadTask(with: request)
            task.resume()
        } else {
            let session = URLSession(
                configuration: Self.transferSessionConfiguration(allowsCellularAccess: allowsCellularAccess)
            )
            session.dataTask(with: request) { data, response, error in
                session.finishTasksAndInvalidate()
                if let error {
                    completion(.failure(WebDAVError.networkError(error)))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let data else {
                    completion(.failure(WebDAVError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "下载失败")))
                    return
                }
                completion(.success(data))
            }.resume()
        }
    }

    private func ensureBackupDirectory(
        baseURLString: String,
        username: String,
        password: String,
        allowsCellularAccess: Bool = true,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard let url = URL(string: Self.backupDirectoryURLString(from: baseURLString)) else {
            completion(.failure(WebDAVError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.timeoutInterval = Self.requestTimeout
        request.allowsCellularAccess = allowsCellularAccess
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.setValue(authHeader(username: username, password: password), forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                completion(.failure(WebDAVError.networkError(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(WebDAVError.xmlParsingFailed))
                return
            }
            if httpResponse.statusCode == 401 {
                completion(.failure(WebDAVError.unauthorized))
                return
            }
            if (200..<300).contains(httpResponse.statusCode) || httpResponse.statusCode == 207 {
                completion(.success(()))
                return
            }
            if httpResponse.statusCode != 404 {
                completion(.failure(WebDAVError.httpError(statusCode: httpResponse.statusCode, message: "备份目录检查失败")))
                return
            }

            var mkcolRequest = URLRequest(url: url)
            mkcolRequest.httpMethod = "MKCOL"
            mkcolRequest.timeoutInterval = Self.requestTimeout
            mkcolRequest.allowsCellularAccess = allowsCellularAccess
            mkcolRequest.setValue(self.authHeader(username: username, password: password), forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: mkcolRequest) { _, mkcolResponse, mkcolError in
                if let mkcolError {
                    completion(.failure(WebDAVError.networkError(mkcolError)))
                    return
                }
                guard let mkcolHTTPResponse = mkcolResponse as? HTTPURLResponse,
                      (200..<300).contains(mkcolHTTPResponse.statusCode) || mkcolHTTPResponse.statusCode == 405 else {
                    completion(.failure(WebDAVError.httpError(statusCode: (mkcolResponse as? HTTPURLResponse)?.statusCode ?? 0, message: "备份目录创建失败")))
                    return
                }
                completion(.success(()))
            }.resume()
        }.resume()
    }

    private func authHeader(username: String, password: String) -> String {
        let authString = "\(username):\(password)"
        let authData = authString.data(using: .utf8) ?? Data()
        return "Basic \(authData.base64EncodedString())"
    }

    private static func backupDirectoryURLString(from baseURLString: String) -> String {
        "\(sanitizeBaseURL(baseURLString))/\(backupDirectoryName)/"
    }

    private static func backupFileURLString(baseURLString: String, filename: String) -> String {
        "\(backupDirectoryURLString(from: baseURLString))\(encodedPathSegment(filename))"
    }

    private static func sanitizeBaseURL(_ value: String) -> String {
        var clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while clean.hasSuffix("/") {
            clean.removeLast()
        }
        let suffix = "/\(backupDirectoryName)"
        if clean.hasSuffix(suffix) {
            clean.removeLast(suffix.count)
        }
        return clean
    }

    private func sanitizeBaseURL(_ value: String) -> String {
        Self.sanitizeBaseURL(value)
    }

    private static func encodedPathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=:")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    public static func parseHTTPDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let syncDate = SyncTimestamp.date(from: trimmed) {
            return syncDate
        }
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, dd-MMM-yy HH:mm:ss zzz",
            "EEE MMM d HH:mm:ss yyyy"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
}

private final class WebDAVDirectoryParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var files: [WebDAVBackupFile] = []
    private var inResponse = false
    private var currentElement = ""
    private var currentText = ""
    private var href = ""
    private var size: Int64 = 0
    private var lastModified = ""

    init(data: Data) {
        self.data = data
    }

    func parse() -> [WebDAVBackupFile] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse() ? files : []
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let normalizedName = localName(elementName)
        currentElement = normalizedName
        currentText = ""
        if normalizedName == "response" {
            inResponse = true
            href = ""
            size = 0
            lastModified = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inResponse else { return }
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let normalizedName = localName(elementName)
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalizedName {
        case "href":
            href = text.removingPercentEncoding ?? text
        case "getcontentlength":
            size = Int64(text) ?? 0
        case "getlastmodified":
            lastModified = text
        case "response":
            if let filename = href.split(separator: "/").last.map(String.init),
               filename.hasSuffix(".json") {
                files.append(WebDAVBackupFile(filename: filename, size: size, lastModified: lastModified))
            }
            inResponse = false
        default:
            break
        }
        currentText = ""
    }

    private func localName(_ name: String) -> String {
        let lowercased = name.lowercased()
        if let suffix = lowercased.split(separator: ":").last {
            return String(suffix)
        }
        return lowercased
    }
}
