import Foundation
import Network

public enum SyncNetworkPreference: String, CaseIterable, Identifiable {
    case wifiOnly
    case wifiAndCellular

    public static let defaultsKey = "webdav_sync_network_preference"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wifiOnly:
            return "仅 Wi‑Fi"
        case .wifiAndCellular:
            return "Wi‑Fi + 流量"
        }
    }

    public static var saved: SyncNetworkPreference {
        guard let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
              let preference = SyncNetworkPreference(rawValue: rawValue) else {
            return .wifiOnly
        }
        return preference
    }
}

public final class SyncNetworkMonitor: @unchecked Sendable {
    public static let shared = SyncNetworkMonitor()

    public enum Connection: Sendable {
        case wifi
        case cellular
        case other
        case unavailable
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.applist.cardwallet.sync-network")
    private let lock = NSLock()
    private var currentConnection: Connection?
    private var connectionWaiters: [CheckedContinuation<Connection, Never>] = []

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connection = Self.connection(for: path)
            lock.lock()
            currentConnection = connection
            let waiters = connectionWaiters
            connectionWaiters.removeAll()
            lock.unlock()
            waiters.forEach { $0.resume(returning: connection) }
        }
        monitor.start(queue: queue)
    }

    public func connection() async -> Connection {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let currentConnection {
                lock.unlock()
                continuation.resume(returning: currentConnection)
            } else {
                connectionWaiters.append(continuation)
                lock.unlock()
            }
        }
    }

    private static func connection(for path: NWPath) -> Connection {
        guard path.status == .satisfied else { return .unavailable }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        return .other
    }
}
