import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @State private var isLockEnabled = false
    @State private var lockPassword = ""
    @State private var confirmPassword = ""
    @State private var newPasswordInput = ""
    @State private var isEditingPassword = false
    @State private var passwordStatusMessage = ""
    @State private var biometricAvailable = false
    @State private var biometricType: LABiometryType = .none
    @State private var isSecurityPulseAnimating = false
    @State private var showResetAlert = false
    @State private var showCloudSync = false
    @State private var hasStoredWebDAVUsername = false
    @State private var hasStoredWebDAVPassword = false
    @State private var hasStoredSyncPassword = false
    @State private var showSyncHistory = false
    @AppStorage("enable_face_id") private var enableFaceID = false
    @AppStorage("app_lock_enabled") private var appLockEnabled = false
    @AppStorage("enable_webdav_sync") private var enableWebDAVSync = false
    @AppStorage("webdav_url") private var webdavURL = ""

    var body: some View {
        NavigationStack {
            List {
                // 安全防护状态
                securityStatusSection

                // 云端同步
                cloudSyncSection

                // 锁屏设置
                lockSection

                // 关于
                aboutSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showCloudSync) {
                CloudSyncView()
            }
            .navigationDestination(isPresented: $showSyncHistory) {
                SyncHistoryView()
            }
            .onAppear {
                checkBiometric()
                refreshStoredConfigState()
            }
            .onChange(of: showCloudSync) { _, isShowing in
                if !isShowing {
                    refreshStoredConfigState()
                }
            }
        }
    }

    // MARK: - 云端同步
    private var cloudSyncSection: some View {
        Section {
            Button {
                showCloudSync = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(syncStatusColor.opacity(0.14))
                            .frame(width: 42, height: 42)
                        Image(systemName: syncCoordinator.syncStatus.iconName)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(syncStatusColor)
                            .symbolEffect(.pulse, isActive: syncCoordinator.syncStatus == .syncing)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("WebDAV 加密同步")
                            .font(.system(.subheadline, weight: .semibold))
                        Text(syncSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)

            if enableWebDAVSync {
                Button {
                    guard !syncCoordinator.isSynchronizing else { return }
                    if hasCompleteWebDAVConfig {
                        Task { await syncCoordinator.synchronize(forceUpload: true) }
                    } else {
                        showCloudSync = true
                    }
                } label: {
                    Label(syncActionTitle, systemImage: syncActionIcon)
                }
                .disabled(syncCoordinator.isSynchronizing)

                Button {
                    showSyncHistory = true
                } label: {
                    HStack {
                        Label("同步记录", systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Label("云端同步", systemImage: "icloud.and.arrow.up.fill")
        } footer: {
            Text("使用与 Web、Android、Mac 相同的 WebDAV V4 加密同步文件。地址、账号和同步密钥一致时，数据可以互通。")
        }
    }

    // MARK: - 安全状态
    private var securityStatusSection: some View {
        Section {
            HStack(spacing: 16) {
                // 呼吸光环安全盾
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.15), lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .scaleEffect(isSecurityPulseAnimating ? 1.25 : 0.95)
                        .opacity(isSecurityPulseAnimating ? 0.0 : 0.8)
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .scaleEffect(isSecurityPulseAnimating ? 1.15 : 0.98)
                    Circle()
                        .fill(LinearGradient(colors: [Color.green.opacity(0.85), Color.cyan.opacity(0.85)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 3)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 65, height: 65)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isSecurityPulseAnimating = true
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("本地隐私安全防护已就绪")
                        .font(.system(.subheadline, weight: .semibold))
                    Text("防护级别：\(appLockEnabled ? (enableFaceID ? "生物识别保护" : "密码保护") : "本机加密保存")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(appLockEnabled ? .green : .orange)
                    Text("您的卡号、CVV 和同步密码均加密保存在本机。")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Label("安全防护状态", systemImage: "lock.shield.fill")
        }
    }

    // MARK: - 锁屏设置
    private var lockSection: some View {
        Section {
            Toggle(isOn: $appLockEnabled.animation()) {
                Label("启用锁屏保护", systemImage: appLockEnabled ? "lock.fill" : "lock.open.fill")
            }
            .onChange(of: appLockEnabled) { _, enabled in
                if !enabled {
                    UserDefaults.standard.set(false, forKey: "app_lock_enabled")
                }
            }

            if appLockEnabled {
                if biometricAvailable {
                    Toggle(isOn: $enableFaceID) {
                        Label(biometricType == .faceID ? "使用 Face ID" : "使用 Touch ID",
                              systemImage: biometricType == .faceID ? "faceid" : "touchid")
                    }
                }

                // 密码管理
                if isEditingPassword {
                    HStack {
                        Label("新密码", systemImage: "key.fill")
                        SecureField("请输入新密码", text: $newPasswordInput)
                            .multilineTextAlignment(.trailing)
                    }
                    Button {
                        savePassword()
                    } label: {
                        Text("保存密码")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    if !passwordStatusMessage.isEmpty {
                        Text(passwordStatusMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button {
                        isEditingPassword = true
                        newPasswordInput = ""
                        passwordStatusMessage = ""
                    } label: {
                        Label(lockPassword.isEmpty ? "设置锁屏密码" : "修改锁屏密码",
                              systemImage: "key.badge.shield.fill")
                    }
                }
            }
        } header: {
            Label("锁屏与隐私", systemImage: "lock.rectangle.stack.fill")
        }
    }

    // MARK: - 关于
    private var aboutSection: some View {
        Section {
            HStack {
                Label("版本", systemImage: "info.circle.fill")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label("清除所有数据", systemImage: "trash.fill")
                    .foregroundColor(.red)
            }
            .alert("确认清除所有数据", isPresented: $showResetAlert) {
                Button("清除", role: .destructive) {
                    syncCoordinator.commit(cards: [], deletedCardIDs: Set(syncCoordinator.cards.map(\.id)))
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这将删除本机所有卡片数据，无法恢复。")
            }
        } header: {
            Label("关于", systemImage: "info.circle")
        }
    }

    private var syncSubtitle: String {
        let cleanURL = webdavURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.isEmpty {
            return "未配置"
        }
        if !hasCompleteWebDAVConfig {
            return hasStoredSyncPassword ? "配置未完整 · \(shortURL(cleanURL))" : "配置未完整：缺少同步密钥 · \(shortURL(cleanURL))"
        }
        if enableWebDAVSync {
            switch syncCoordinator.syncStatus {
            case .failure(let message) where message.contains("同步密钥") && hasStoredSyncPassword:
                return "已配置，等待重新同步 · \(shortURL(cleanURL))"
            default:
                return "\(syncCoordinator.syncStatus.displayText) · \(shortURL(cleanURL))"
            }
        }
        return "已配置，自动同步未启用"
    }

    private var syncStatusColor: Color {
        if !hasCompleteWebDAVConfig {
            return .orange
        }
        switch syncCoordinator.syncStatus {
        case .idle:    return enableWebDAVSync ? .secondary : .orange
        case .syncing: return .cyan
        case .success: return .green
        case .warning: return .orange
        case .failure(let message):
            return message.contains("同步密钥") && hasStoredSyncPassword ? .orange : .red
        }
    }

    private var syncActionTitle: String {
        if syncCoordinator.isSynchronizing {
            return "正在同步"
        }
        return hasCompleteWebDAVConfig ? "立即同步" : "补全同步配置"
    }

    private var syncActionIcon: String {
        if syncCoordinator.isSynchronizing {
            return "arrow.triangle.2.circlepath.icloud"
        }
        return hasCompleteWebDAVConfig ? "arrow.triangle.2.circlepath.icloud" : "key.icloud"
    }

    private var hasCompleteWebDAVConfig: Bool {
        !webdavURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        hasStoredWebDAVUsername &&
        hasStoredWebDAVPassword &&
        hasStoredSyncPassword
    }

    private func shortURL(_ url: String) -> String {
        url.count > 28 ? "\(url.prefix(25))..." : url
    }

    // MARK: - Helpers
    private func checkBiometric() {
        let context = LAContext()
        var error: NSError?
        biometricAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
        lockPassword = KeychainManager.load(key: "app_lock_password") ?? ""
    }

    private func refreshStoredConfigState() {
        hasStoredWebDAVUsername = !(KeychainManager.load(key: "webdav_username") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        hasStoredWebDAVPassword = !(KeychainManager.load(key: "webdav_password") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        hasStoredSyncPassword = !(KeychainManager.load(key: "webdav_sync_password_v4") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private func savePassword() {
        guard newPasswordInput.count >= 4 else {
            passwordStatusMessage = "密码不能少于 4 位"
            return
        }
        KeychainManager.save(key: "app_lock_password", value: newPasswordInput)
        lockPassword = newPasswordInput
        newPasswordInput = ""
        isEditingPassword = false
        passwordStatusMessage = "密码已保存"
    }
}
