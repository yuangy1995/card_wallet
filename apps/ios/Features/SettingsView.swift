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
    @State private var showHelp = false
    @State private var showIconSelection = false
    @State private var currentIconName: String? = nil
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

                // 帮助
                helpSection

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
            .navigationDestination(isPresented: $showHelp) {
                IOSHelpView()
            }
            .navigationDestination(isPresented: $showIconSelection) {
                AppIconSelectionView(currentIconName: $currentIconName)
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
                syncCoordinator.refreshWebDAVConfigurationState()
                currentIconName = UIApplication.shared.alternateIconName
                if appLockEnabled && lockPassword.isEmpty {
                    appLockEnabled = false
                }
            }
            .onChange(of: showCloudSync) { _, isShowing in
                if !isShowing {
                    refreshStoredConfigState()
                    syncCoordinator.refreshWebDAVConfigurationState()
                }
            }
            .fullScreenCover(isPresented: $showSetPasswordSheet, onDismiss: {
                if lockPassword.isEmpty {
                    appLockEnabled = false
                }
            }) {
                NavigationStack {
                    VStack(spacing: 0) {
                        // 顶部安全区精致卡片
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 76, height: 76)
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.85), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                            .padding(.top, 10)
                            
                            VStack(spacing: 8) {
                                Text(lockPassword.isEmpty ? "设置密码保护" : "修改锁屏密码")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text(passwordStepInstruction)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // 点阵显示
                            HStack(spacing: 16) {
                                ForEach(0..<6, id: \.self) { index in
                                    Circle()
                                        .fill(index < passwordInput.count ? Color.blue : Color.primary.opacity(0.15))
                                        .frame(width: 13, height: 13)
                                        .scaleEffect(index < passwordInput.count ? 1.25 : 1.0)
                                        .animation(.spring(duration: 0.2), value: passwordInput.count)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.vertical, 26)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.primary.opacity(0.02))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 40)
                        
                        if !passwordStatusMessage.isEmpty {
                            Text(passwordStatusMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 18)
                                .transition(.opacity)
                        }
                        
                        Spacer(minLength: 20)
                        
                        customKeyboard
                            .padding(.bottom, 35)
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
                        Image(systemName: syncIconName)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(syncStatusColor)
                            .symbolEffect(.pulse, isActive: hasCompleteWebDAVConfig && syncCoordinator.syncStatus == .syncing)
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
                        syncCoordinator.requestManualSync()
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

            Button {
                showIconSelection = true
            } label: {
                HStack {
                    Label("应用图标", systemImage: "app.badge.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(currentIconText)
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

    private var currentIconText: String {
        guard let name = currentIconName else { return "经典" }
        switch name {
        case "AppIcon-Minimal": return "极简"
        case "AppIcon-Cool": return "炫酷"
        case "AppIcon-Retro": return "复古"
        default: return "经典"
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

    // MARK: - 帮助
    private var helpSection: some View {
        Section {
            Button {
                showHelp = true
            } label: {
                HStack {
                    Label("使用帮助", systemImage: "questionmark.circle.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Label("帮助与说明", systemImage: "lifepreserver.fill")
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
            return .secondary
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

    private var syncIconName: String {
        hasCompleteWebDAVConfig ? syncCoordinator.syncStatus.iconName : "icloud.slash"
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
        VStack(spacing: 18) {
            ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                HStack(spacing: 32) {
                    ForEach(row, id: \.self) { num in
                        keyboardButton(String(num))
                    }
                }
            }
            HStack(spacing: 32) {
                Button {
                    withAnimation { passwordInput = "" }
                } label: {
                    Text("清空")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(KeyboardButtonStyle(isFeatureButton: true))

                keyboardButton("0")

                Button {
                    if !passwordInput.isEmpty {
                        _ = withAnimation { passwordInput.removeLast() }
                    }
                } label: {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                .buttonStyle(KeyboardButtonStyle(isFeatureButton: true))
            }
        }
    }

    private func keyboardButton(_ label: String) -> some View {
        Button {
            guard passwordInput.count < 6 else { return }
            withAnimation(.spring(duration: 0.1)) { passwordInput += label }
        } label: {
            Text(label)
                .font(.system(size: 26, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
        }
        .buttonStyle(KeyboardButtonStyle(isFeatureButton: false))
    }
}

enum PasswordStep {
    case enter
    case confirm(String)
}

enum AppIconOption: String, CaseIterable, Identifiable {
    case classic
    case minimal
    case cool
    case retro
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .classic: return "经典"
        case .minimal: return "极简"
        case .cool: return "炫酷"
        case .retro: return "复古"
        }
    }
    
    var assetName: String? {
        switch self {
        case .classic: return nil
        case .minimal: return "AppIcon-Minimal"
        case .cool: return "AppIcon-Cool"
        case .retro: return "AppIcon-Retro"
        }
    }
    
    var previewImageName: String {
        switch self {
        case .classic: return "preview_icon_classic"
        case .minimal: return "preview_icon_minimal"
        case .cool: return "preview_icon_cool"
        case .retro: return "preview_icon_retro"
        }
    }
}

struct AppIconSelectionView: View {
    @Binding var currentIconName: String?
    @State private var showToast = false
    @State private var toastMessage = ""
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("选择您喜爱的应用图标，它将显示在您的设备桌面上。")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(AppIconOption.allCases) { option in
                            Button {
                                changeAppIcon(to: option)
                            } label: {
                                VStack(spacing: 12) {
                                    ZStack {
                                        Image(option.previewImageName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 88, height: 88)
                                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                    .stroke(currentIconName == option.assetName ? Color.blue : Color.clear, lineWidth: 3.5)
                                            )
                                        
                                        if currentIconName == option.assetName {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(.blue)
                                                .background(Circle().fill(.white))
                                                .offset(x: 32, y: -32)
                                        }
                                    }
                                    
                                    Text(option.displayName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(currentIconName == option.assetName ? .blue : .primary)
                                }
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                        .shadow(color: .black.opacity(0.015), radius: 4, y: 2)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(currentIconName == option.assetName ? Color.blue.opacity(0.15) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("更换应用图标")
            .navigationBarTitleDisplayMode(.inline)
            
            // 自定义毛玻璃 Toast 提示层，设计极其精美
            if showToast {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20, weight: .semibold))
                        Text(toastMessage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8))
                            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.92)))
                    
                    Spacer()
                }
                .padding(.top, 40)
                .zIndex(999)
            }
        }
    }
    
    private func changeAppIcon(to option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        
        UIApplication.shared.setAlternateIconName(option.assetName) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("更换应用图标失败: \(error.localizedDescription)")
                } else {
                    currentIconName = option.assetName
                    toastMessage = "已成功将应用图标更换为“\(option.displayName)”"
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        showToast = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showToast = false
                        }
                    }
                }
            }
        }
    }
}

struct KeyboardButtonStyle: ButtonStyle {
    let isFeatureButton: Bool
    var forcePressed: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed || forcePressed
        configuration.label
            .frame(width: 78, height: 78)
            .background(
                ZStack {
                    // 1. 基础圆圈背景（按下时变为优雅且明显的淡蓝色）
                    Circle()
                        .fill(
                            isPressed
                            ? Color.blue.opacity(0.18)
                            : (isFeatureButton ? Color.primary.opacity(0.08) : Color.primary.opacity(0.06))
                        )
                    
                    // 2. 边框线（数字按键，未按下时显示）
                    if !isFeatureButton && !isPressed {
                        Circle()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    }
                    
                    // 3. 点击时的蓝色径向水波纹微光反馈特效（提升亮度和对比度）
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.55), Color.blue.opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 39
                            )
                        )
                        .opacity(isPressed ? 1.0 : 0.0)
                        .scaleEffect(isPressed ? 1.0 : 0.5)
                }
            )
            // 强化了按下缩放的深度，从 0.90 提升到 0.84，点击手感极佳
            .scaleEffect(isPressed ? 0.84 : 1.0)
            // 弹簧动画略微收紧，增加“弹润”的回弹张力
            .animation(.spring(response: 0.16, dampingFraction: 0.52), value: isPressed)
    }
}

private struct IOSHelpView: View {
    var body: some View {
        List {
            Section("快速开始") {
                HelpRow(
                    icon: "plus.circle.fill",
                    title: "添加卡片",
                    detail: "在卡包页点击右下角“+”，选择信用卡或储蓄卡后填写资料。"
                )
                HelpRow(
                    icon: "line.3.horizontal.decrease.circle.fill",
                    title: "分组与排序",
                    detail: "使用卡包右上角筛选按钮，可按银行、卡组织、级别或国家分组，并切换额度、免息期等排序。"
                )
                HelpRow(
                    icon: "checklist",
                    title: "批量管理",
                    detail: "点击卡包右上角批量操作按钮，勾选多张卡后可统一修改类别、年费和有效期，或批量删除。"
                )
            }

            Section("提醒与通知") {
                HelpRow(
                    icon: "bell.badge.fill",
                    title: "系统提醒",
                    detail: "允许通知后，应用会提前排程账单日、还款日、年费和有效期提醒；即使应用退到后台或未运行，iOS 也能按排程投递。"
                )
                HelpRow(
                    icon: "moon.zzz.fill",
                    title: "没有收到通知",
                    detail: "请在系统设置中确认已允许通知，并检查专注模式、定时摘要和通知声音设置。"
                )
            }

            Section("数据与安全") {
                HelpRow(
                    icon: "icloud.fill",
                    title: "跨设备同步",
                    detail: "在云端同步中配置 WebDAV 和同步密钥。各设备需使用相同密钥，数据才可正常解密合并。"
                )
                HelpRow(
                    icon: "lock.shield.fill",
                    title: "本机保护",
                    detail: "卡片数据在本机加密保存。启用应用锁后，可使用密码或生物识别解锁；忘记密码时可通过本机卡片信息验证。"
                )
                HelpRow(
                    icon: "externaldrive.fill.badge.checkmark",
                    title: "存储管理",
                    detail: "设置中的存储管理可查看本机数据、图片和缓存占用，并清理可安全重建的缓存。"
                )
            }
        }
        .navigationTitle("使用帮助")
        .navigationBarTitleDisplayMode(.large)
    }

    private struct HelpRow: View {
        let icon: String
        let title: String
        let detail: String

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.body, weight: .semibold))
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
