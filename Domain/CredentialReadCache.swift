import Foundation

/// 仅在本次运行中复用读取结果；串行读取避免同步请求同时弹出授权。
final class CredentialReadCache {
    private let lock = NSRecursiveLock()
    private var results: [String: Result<String?, Error>] = [:]

    func read(key: String, loader: () -> Result<String?, Error>) -> Result<String?, Error> {
        lock.lock()
        defer { lock.unlock() }
        if let result = results[key] { return result }
        let result = loader()
        results[key] = result
        return result
    }

    func retryFailures(key: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        results = results.filter { entry in
            if let key, entry.key != key { return true }
            if case .failure = entry.value { return false }
            return true
        }
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        results.removeAll()
    }
}
