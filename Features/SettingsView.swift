import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @State private var isLockEnabled = false
    @State private var lockPassword = ""
    @State private var passwordInput = ""
    @State private var passwordStep: PasswordStep = .enter
    @State private var passwordStatusMessage = ""
    @State private var biometricAvailable = false
    @State private var biometricType: LABiometryType = .none
    @State private var showResetAlert = false
    @State private var showSetPasswordSheet = false
    @State private var showCloudSync = false
    @State private var hasStoredWebDAVUsername = false
    @State private var hasStoredWebDAVPassword = false
    @State private var hasStoredSyncPassword = false

    @State private var showStorageManagement = false
    @State private var showAppearanceDialog = false
    @AppStorage("app_appearance") private var appAppearance = "light"
    @AppStorage("enable_face_id") private var enableFaceID = false
    @AppStorage("app_lock_enabled") private var appLockEnabled = false
    @AppStorage("enable_webdav_sync") private var enableWebDAVSync = false
    @AppStorage("webdav_url") private var webdavURL = ""

    var body: some View {
        NavigationStack {
            List {
                // 自定义顶部标题行
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.7), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("设置")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))

                // 云端同步
                cloudSyncSection

                // 锁屏设置
                lockSection

                // 外观设置
                appearanceSection

                // 存储管理
                storageSection

                // 关于
                aboutSection
            }
            .toolbar(.hidden, for: .navigationBar)
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationDestination(isPresented: $showCloudSync) {
                CloudSyncView()
            }

            .navigationDestination(isPresented: $showStorageManagement) {
                StorageManagementView()
            }
            .confirmationDialog("选择外观模式", isPresented: $showAppearanceDialog, titleVisibility: .visible) {
                Button("浅色") { appAppearance = "light" }
                Button("深色") { appAppearance = "dark" }
                Button("跟随系统") { appAppearance = "system" }
                Button("取消", role: .cancel) {}
            }
            .onAppear {
                checkBiometric()
                refreshStoredConfigState()
                if appLockEnabled && lockPassword.isEmpty {
                    appLockEnabled = false
                }
            }
            .onChange(of: showCloudSync) { _, isShowing in
                if !isShowing {
                    refreshStoredConfigState()
                }
            }
            .fullScreenCover(isPresented: $showSetPasswordSheet, onDismiss: {
                if lockPassword.isEmpty {
                    appLockEnabled = false
                }
            }) {
                NavigationStack {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Text(passwordStepInstruction)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        // 点阵显示
                        HStack(spacing: 12) {
                            ForEach(0..<6, id: \.self) { index in
                                Circle()
                                    .fill(index < passwordInput.count ? Color.blue : Color.primary.opacity(0.15))
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(index < passwordInput.count ? 1.2 : 1.0)
                                    .animation(.spring(duration: 0.2), value: passwordInput.count)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if !passwordStatusMessage.isEmpty {
                            Text(passwordStatusMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                        
                        customKeyboard
                            .padding(.bottom, 20)
                    }
                    .navigationTitle(lockPassword.isEmpty ? "设置锁屏密码" : "修改锁屏密码")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showSetPasswordSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(passwordStepLabel) {
                                handlePasswordNext()
                            }
                            .disabled(passwordInput.count < 4)
                        }
                    }
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


            }
        } header: {
            Label("云端同步", systemImage: "icloud.and.arrow.up.fill")
        } footer: {
            Text("使用与 Web、Android、Mac 相同的 WebDAV V4 加密同步文件。地址、账号和同步密钥一致时，数据可以互通。")
        }
    }

    // MARK: - 锁屏设置
    private var lockSection: some View {
        Section {
            Toggle(isOn: $appLockEnabled.animation()) {
                Label("启用锁屏保护", systemImage: appLockEnabled ? "lock.fill" : "lock.open.fill")
            }
            .onChange(of: appLockEnabled) { _, enabled in
                if enabled {
                    if lockPassword.isEmpty {
                        passwordInput = ""
                        passwordStep = .enter
                        passwordStatusMessage = ""
                        showSetPasswordSheet = true
                    }
                } else {
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

                Button {
                    passwordInput = ""
                    passwordStep = .enter
                    passwordStatusMessage = ""
                    showSetPasswordSheet = true
                } label: {
                    Label("修改锁屏密码", systemImage: "key.badge.shield.fill")
                }
                .buttonStyle(.plain)
            }
        } header: {
            Label("锁屏与隐私", systemImage: "lock.rectangle.stack.fill")
        }
    }

    // MARK: - 外观设置
    private var appearanceSection: some View {
        Section {
            Button {
                showAppearanceDialog = true
            } label: {
                HStack {
                    Label("外观模式", systemImage: appearanceIcon)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(appearanceText)
                        .font(.system(.body))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Label("个性化", systemImage: "paintpalette.fill")
        }
    }

    private var appearanceText: String {
        switch appAppearance {
        case "light": return "浅色"
        case "dark": return "深色"
        default: return "跟随系统"
        }
    }

    private var appearanceIcon: String {
        switch appAppearance {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        default: return "square.grid.2x2.fill"
        }
    }

    // MARK: - 存储管理
    private var storageSection: some View {
        Section {
            Button {
                showStorageManagement = true
            } label: {
                HStack {
                    Label("存储管理", systemImage: "internaldrive.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Label("存储与空间", systemImage: "folder.badge.gearshape.fill")
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
        case .syncing: return .blue
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

    private func saveNewPassword(_ password: String) {
        KeychainManager.save(key: "app_lock_password", value: password)
        lockPassword = password
        passwordInput = ""
        passwordStep = .enter
        passwordStatusMessage = ""
        showSetPasswordSheet = false
    }

    private func handlePasswordNext() {
        switch passwordStep {
        case .enter:
            if passwordInput.count >= 4 {
                passwordStep = .confirm(passwordInput)
                passwordInput = ""
                passwordStatusMessage = ""
            } else {
                passwordStatusMessage = "密码不能少于 4 位"
            }
        case .confirm(let firstPassword):
            if passwordInput == firstPassword {
                saveNewPassword(passwordInput)
            } else {
                passwordStatusMessage = "两次输入的密码不一致，请重新输入"
                passwordStep = .enter
                passwordInput = ""
            }
        }
    }

    private var passwordStepLabel: String {
        switch passwordStep {
        case .enter:
            return "下一步"
        case .confirm:
            return "确认"
        }
    }

    private var passwordStepInstruction: String {
        switch passwordStep {
        case .enter:
            return "请输入 4-6 位数字密码"
        case .confirm:
            return "请再次输入密码以确认"
        }
    }

    private var customKeyboard: some View {
        VStack(spacing: 12) {
            ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(row, id: \.self) { num in
                        keyboardButton(String(num))
                    }
                }
            }
            HStack(spacing: 20) {
                Button {
                    withAnimation { passwordInput = "" }
                } label: {
                    ZStack {
                        Circle().fill(Color.primary.opacity(0.06)).frame(width: 64, height: 64)
                        Text("清空")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }

                keyboardButton("0")

                Button {
                    if !passwordInput.isEmpty {
                        _ = withAnimation { passwordInput.removeLast() }
                    }
                } label: {
                    ZStack {
                        Circle().fill(Color.primary.opacity(0.06)).frame(width: 64, height: 64)
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    private func keyboardButton(_ label: String) -> some View {
        Button {
            guard passwordInput.count < 6 else { return }
            withAnimation(.spring(duration: 0.1)) { passwordInput += label }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                Text(label)
                    .font(.system(.title2, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

enum PasswordStep {
    case enter
    case confirm(String)
}
