import Foundation
import Combine

@MainActor
public final class AutoLockManager: ObservableObject {
    public static let shared = AutoLockManager()

    @Published public private(set) var isLocked = false
    private var lockTimer: Timer?
    private let timeoutInterval: TimeInterval = 60.0

    private init() {
        checkInitialLock()
    }

    private func checkInitialLock() {
        let isEnabled = UserDefaults.standard.bool(forKey: "app_lock_enabled")
        if isEnabled {
            let savedPassword = KeychainManager.load(key: "app_lock_password") ?? ""
            if savedPassword.isEmpty {
                UserDefaults.standard.set(false, forKey: "app_lock_enabled")
            } else {
                isLocked = true
            }
        }
    }

    public func unlock() {
        isLocked = false
        resetTimer()
    }

    public func lock() {
        lockTimer?.invalidate()
        lockTimer = nil
        isLocked = true
        SyncCoordinator.shared.setSuspended(isLocked: true)
        CardSystemNotificationCenter.shared.suspendForLock()
    }

    public func userInteracted() {
        guard !isLocked else { return }
        resetTimer()
    }

    public func appWillResignActive() {
        let isEnabled = UserDefaults.standard.bool(forKey: "app_lock_enabled")
        guard isEnabled else { return }
        let savedPassword = KeychainManager.load(key: "app_lock_password") ?? ""
        if savedPassword.isEmpty {
            UserDefaults.standard.set(false, forKey: "app_lock_enabled")
            return
        }
        lock()
    }

    public func appDidBecomeActive() {
        let isEnabled = UserDefaults.standard.bool(forKey: "app_lock_enabled")
        guard isEnabled, isLocked else { return }
    }

    private func resetTimer() {
        let isEnabled = UserDefaults.standard.bool(forKey: "app_lock_enabled")
        guard isEnabled else { return }
        let savedPassword = KeychainManager.load(key: "app_lock_password") ?? ""
        if savedPassword.isEmpty {
            UserDefaults.standard.set(false, forKey: "app_lock_enabled")
            return
        }
        lockTimer?.invalidate()
        lockTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
    }
}
