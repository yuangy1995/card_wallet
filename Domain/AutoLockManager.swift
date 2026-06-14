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
            isLocked = true
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
    }

    public func userInteracted() {
        guard !isLocked else { return }
        resetTimer()
    }

    public func appWillResignActive() {
        let isEnabled = UserDefaults.standard.bool(forKey: "app_lock_enabled")
        guard isEnabled else { return }
        lock()
    }

    public func appDidBecomeActive() {
        let isEnabled = UserDefaults.standard.bool(forKey: "app_lock_enabled")
        guard isEnabled, isLocked else { return }
    }

    private func resetTimer() {
        let isEnabled = UserDefaults.standard.bool(forKey: "app_lock_enabled")
        guard isEnabled else { return }
        lockTimer?.invalidate()
        lockTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
    }
}
