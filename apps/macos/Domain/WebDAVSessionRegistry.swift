import Foundation

/// Session ownership is confined to this client; cancellation never affects unrelated networking.
final class WebDAVSessionRegistry: @unchecked Sendable {
    private final class WeakSession { weak var value: URLSession?; init(_ value: URLSession) { self.value = value } }
    private let lock = NSLock()
    private var base = URLSession(configuration: .ephemeral)
    private var transfers: [WeakSession] = []
    var session: URLSession { lock.lock(); defer { lock.unlock() }; return base }
    func make(configuration: URLSessionConfiguration, delegate: URLSessionDelegate? = nil, delegateQueue: OperationQueue? = nil) -> URLSession {
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        lock.lock(); transfers.removeAll { $0.value == nil }; transfers.append(WeakSession(session)); lock.unlock()
        return session
    }
    func cancelAll() {
        lock.lock()
        let old = [base] + transfers.compactMap(\.value)
        base = URLSession(configuration: .ephemeral); transfers.removeAll()
        lock.unlock()
        old.forEach { $0.invalidateAndCancel() }
    }
}
