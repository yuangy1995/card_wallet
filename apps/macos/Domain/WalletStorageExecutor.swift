import Foundation

/// The serial queue owns blocking file/crypto work; callers suspend rather than block MainActor.
final class WalletStorageExecutor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "wallet.macos.local-storage", qos: .userInitiated)
    func perform<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result(catching: work)) }
        }
    }
}

/// MainActor is reentrant at await. Keep candidate -> durable save -> publication in FIFO order.
@MainActor
final class WalletMutationGate {
    private var held = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func acquire() async {
        if !held { held = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() {
        if waiters.isEmpty { held = false }
        else { waiters.removeFirst().resume() }
    }
}
