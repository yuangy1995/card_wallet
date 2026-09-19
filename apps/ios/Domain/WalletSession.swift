import Foundation

/// A new identity is created on every unlock. Checking a Boolean lock flag alone
/// cannot reject work from the previous session after a quick lock/unlock.
final class WalletSession: @unchecked Sendable {
    @TaskLocal static var current: WalletSession?
    private let lock = NSLock()
    private var valid = true
    var isValid: Bool { lock.withLock { valid } }
    func revoke() { lock.withLock { valid = false } }
    func check() throws {
        guard isValid else { throw CancellationError() }
    }
}
