import Foundation

/// Callbacks may outlive a lock. They keep this revocable box, not the private payload.
final class LockScopedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value?

    init(_ value: Value) { storage = value }

    var value: Value? {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func update(_ body: (inout Value) -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard storage != nil else { return }
        body(&storage!)
    }

    func invalidate() {
        lock.lock(); defer { lock.unlock() }
        storage = nil
    }
}
