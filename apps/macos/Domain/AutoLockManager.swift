import Foundation
import SwiftUI
import LocalAuthentication

@Observable
@MainActor
public class AutoLockManager {
    public static let shared = AutoLockManager()
    
    /// 当前是否处于模糊锁屏状态
    public var isLocked: Bool = false {
        didSet {
            // Mac 作为桥接中心，锁定期间暂停远端数据读取与写入。
            SyncCoordinator.shared.setSuspended(isLocked: isLocked)
        }
    }
    
    /// 自动锁定超时时间（5分钟 = 300秒）
    private let autoLockTimeout: TimeInterval = 300.0
    
    private var lastActivityTime: Date = Date()
    private var inactivityTimer: Timer?
    public private(set) var hasPassword = false
    public private(set) var credentialAccessFailed = false
    
    private init() {
        // 💡 如果系统已保存防窥解锁密码，冷启动时必须默认处于锁屏状态，强制用户进行解锁
        switch KeychainManager.loadResult(key: "app_lock_password") {
        case .success(let password): hasPassword = password != nil
        case .failure:
            hasPassword = true // 拒绝系统授权不等于没有密码。
            credentialAccessFailed = true
        }
        if hasPassword {
            self.isLocked = true
        }
        setupLifecycleListeners()
        if !isLocked { resetInactivityTimer() }
    }
    
    /// 重置用户闲置计时器（鼠标移动、按键点击等任何活跃交互时触发）
    public func resetActivity() {
        lastActivityTime = Date()
        
        // 如果当前已经锁屏，不需要在活跃时解锁，由解锁凭证说了算
        if isLocked { return }
        
        if inactivityTimer == nil && hasPassword { resetInactivityTimer() }
    }
    
    /// 强制执行手动锁定 (对应 Web 端 manualLock)
    public func lock() {
        guard hasPasswordSet() else { return }
        DispatchQueue.main.async {
            self.isLocked = true
            self.stopInactivityTimer()
        }
    }
    
    /// 验证应用解锁密码
    public func unlock(password: String) -> Bool {
        KeychainManager.retryFailedReads()
        let result = KeychainManager.loadResult(key: "app_lock_password")
        guard case .success(let storedPassword) = result else {
            credentialAccessFailed = true
            return false
        }
        credentialAccessFailed = false
        guard let savedPassword = storedPassword else {
            // 如果没设置过密码，直接放行
            hasPassword = false
            stopInactivityTimer()
            isLocked = false
            resetActivity()
            return true
        }
        
        if password == savedPassword {
            DispatchQueue.main.async {
                self.isLocked = false
                self.resetActivity()
            }
            return true
        }
        return false
    }
    
    /// 校验是否已经设置了应用解锁密码
    public func hasPasswordSet() -> Bool {
        hasPassword
    }

    public func retryCredentialAccess() {
        KeychainManager.retryFailedReads()
        switch KeychainManager.loadResult(key: "app_lock_password") {
        case .success(let password):
            credentialAccessFailed = false
            hasPassword = password != nil
            if !hasPassword { isLocked = false; resetActivity() }
        case .failure:
            credentialAccessFailed = true
        }
    }
    
    /// 设定应用解锁密码并保存至既有本地加密凭证文件（历史接口名不代表钥匙串后端）。
    @discardableResult
    public func setPassword(_ password: String) -> Bool {
        guard case .success = KeychainManager.save(key: "app_lock_password", value: password) else { return false }
        hasPassword = true
        resetActivity()
        return true
    }
    
    /// 一键清除解锁密码，关闭应用锁定功能
    public func removePassword() {
        guard KeychainManager.delete(key: "app_lock_password") else { return }
        hasPassword = false
        DispatchQueue.main.async {
            self.isLocked = false
            self.stopInactivityTimer()
        }
    }
    
    // ==========================================
    // 💡 Touch ID 生物指纹识别秒级解锁
    // ==========================================
    
    /// 💡 当前设备硬件是否支持生物指纹识别 (Touch ID) 解锁，供界面做降级兼容动态渲染
    public var isTouchIDAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    public func evaluateTouchID(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // 1. 检查设备硬件是否支持生物识别（Touch ID）
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "验证 Touch ID 以快速解锁卡包"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isLocked = false
                        self.resetActivity()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }
        } else {
            // 设备不支持 Touch ID，回调通知外层降级使用密码
            completion(false)
        }
    }
    
    // ==========================================
    // 💡 闲置与前后台休眠监测机制 (OS Integration)
    // ==========================================
    
    private func resetInactivityTimer() {
        stopInactivityTimer()
        
        guard hasPasswordSet() else { return }
        
        // 开启 10 秒轮询一次的闲置状态检查
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkInactivity() }
        }
    }
    
    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    private func checkInactivity() {
        guard hasPasswordSet() && !isLocked else { return }
        
        let elapsed = Date().timeIntervalSince(lastActivityTime)
        if elapsed >= autoLockTimeout {
            lock()
            print("闲置超时：应用已自动锁定")
        }
    }
    
    /// 注册 macOS 系统级通知监听（休眠唤醒、应用切回前台）
    private func setupLifecycleListeners() {
        let center = NotificationCenter.default
        
        // 1. 监听应用重新回到前台活跃状态
        center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkLifecycleLock() }
        }
        
        // 2. 监听 macOS 系统进入休眠
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            // 系统将要休眠，直接强制上锁，确保唤醒时处于安全锁定状态
            MainActor.assumeIsolated { self?.lock() }
        }
        
        // 3. 监听 macOS 屏幕进入休眠
        center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lock() }
        }
    }
    
    private func checkLifecycleLock() {
        guard hasPasswordSet() else { return }
        
        // 如果当前已经锁了，保持现状即可
        if isLocked { return }
        
        let elapsed = Date().timeIntervalSince(lastActivityTime)
        if elapsed >= autoLockTimeout {
            lock()
        } else {
            // 切回前台时，自动重置闲置计时
            resetActivity()
        }
    }
}
