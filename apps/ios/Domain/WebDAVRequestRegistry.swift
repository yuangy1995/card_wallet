import Foundation

/// Only tracks this client's requests; locking cannot cancel unrelated URLSession users.
final class WebDAVRequestRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [URLSessionTask] = []
    private var suspended = false

    func start(_ task: URLSessionTask) {
        lock.lock()
        tasks.removeAll { $0.state == .completed }
        let allowed = !suspended
        if allowed { tasks.append(task) }
        lock.unlock()
        if allowed { task.resume() } else { task.cancel(); task.resume() }
    }

    func setSuspended(_ value: Bool) {
        lock.lock()
        suspended = value
        let active = value ? tasks : []
        if value { tasks.removeAll() }
        lock.unlock()
        active.forEach { $0.cancel() }
    }

    func cancelAll() {
        lock.lock()
        let active = tasks
        tasks.removeAll()
        lock.unlock()
        active.forEach { $0.cancel() }
    }
}
