import SwiftUI
import LocalAuthentication

enum WalletSettingsSection: String, CaseIterable, Identifiable {
    case appearance = "外观"
    case security = "安全"
    case sync = "同步"
    case data = "数据与帮助"
    case updates = "软件更新"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .appearance: return "paintpalette"
        case .security: return "lock.shield"
        case .sync: return "arrow.triangle.2.circlepath"
        case .data: return "tray"
        case .updates: return "arrow.down.circle"
        }
    }
}

struct SettingsView: View {
    @Binding var selectedSection: WalletSettingsSection
    @EnvironmentObject private var appearance: WalletAppearance
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletAnimation) private var walletAnimation
    @State private var showingDisableLockConfirmation = false
    private var lockManager: AutoLockManager { AutoLockManager.shared }
    
    
    // 密码锁设置
    @State private var lockPassword = ""
    @State private var isLockEnabled = false
    @State private var passwordStatusText = ""
    @State private var showingHelp = false
    @State private var showingStorageManagement = false
    
    // WebDAV 同步配置
    @State private var webdavUrl = ""
    @State private var webdavUsername = ""
    @State private var webdavPassword = ""
    @State private var webdavSyncPassword = ""
    
    // 同步连接状态
    @State private var connectionStatus = ""
    @State private var isTestingConnection = false
    @State private var connectionSuccess = false
    @State private var isEditingConfig = false
    
    // WebDAV 自动同步配置
    @AppStorage("enable_webdav_bridge") private var enableWebDAVBridge = true
    @AppStorage("auto_check_interval") private var autoCheckInterval = 300.0
    
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared
    @ObservedObject private var bridgeService = WebDAVBridgeService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            WalletPageHeader(title: "设置", subtitle: String(localized: "按你的习惯，打理这个卡包。")) {}
                .padding(.horizontal, 24).padding(.top, 24)
            WalletSettingsTabs(selection: $selectedSection)
                .padding(.horizontal, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedSection {
                    case .appearance: appearanceSettings
                    case .security: securitySettings
                    case .sync: syncSettings
                    case .data: dataSettings
                    case .updates: WalletUpdateSettings()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
        }
        .onAppear(perform: loadSelectedSection)
        .onChange(of: selectedSection) { _, _ in loadSelectedSection() }
        .alert("关闭自动锁定？", isPresented: $showingDisableLockConfirmation) {
            Button("取消", role: .cancel) { isLockEnabled = true }
            Button("关闭", role: .destructive) {
                lockManager.removePassword()
                isLockEnabled = lockManager.hasPassword
                passwordStatusText = isLockEnabled ? String(localized: "未能关闭，请检查密码存储权限。") : String(localized: "自动锁定已关闭。")
            }
        } message: {
            Text("关闭后将移除解锁密码，打开卡包时不再需要验证。卡片数据仍会加密保存。")
        }
        .sheet(isPresented: $showingStorageManagement) {
            MacStorageManagementView().modifier(WalletThemeModifier())
        }
        .sheet(isPresented: $showingHelp) {
            MacHelpView().modifier(WalletThemeModifier())
        }
    }

    private var appearanceSettings: some View { WalletAppearanceSettings() }

    private var securitySettings: some View {
        Group {
            WalletFormSection(title: "锁定与密码", icon: "lock.shield") {
                WalletSettingsToggle(title: "自动锁定", detail: "闲置五分钟或设备休眠时，自动保护卡片信息。", icon: "lock", isOn: $isLockEnabled)
                    .onChange(of: isLockEnabled) { _, enabled in
                        if !enabled && lockManager.hasPassword { showingDisableLockConfirmation = true }
                    }
                if isLockEnabled {
                    Divider()
                    WalletFormField(title: lockManager.hasPassword ? "新密码" : "设置解锁密码") {
                        SecureField(lockManager.hasPassword ? "新密码" : "设置解锁密码", text: $lockPassword, prompt: Text("至少六位"))
                    }.frame(maxWidth: 400)
                    Button(lockManager.hasPassword ? "更新密码" : "保存并开启") {
                        if lockManager.setPassword(lockPassword) {
                            lockPassword = ""
                            passwordStatusText = String(localized: "密码已保存。")
                        } else {
                            passwordStatusText = String(localized: "密码未保存，请检查存储权限后重试。")
                        }
                    }
                    .disabled(lockPassword.count < 6)
                    .buttonStyle(.borderedProminent)
                    if !lockManager.hasPassword { Text("设置密码后，自动锁定才会启用。").font(.caption).foregroundStyle(.secondary) }
                }
                if !passwordStatusText.isEmpty { Text(passwordStatusText).font(.caption).foregroundStyle(.secondary) }
                if lockManager.isTouchIDAvailable { Label("此 Mac 支持 Touch ID 解锁", systemImage: "touchid").foregroundStyle(palette.accent) }
                Text("忘记密码时，可以在锁定页面核对已有卡片信息找回。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            WalletFormSection(title: "密码保存方式", icon: "internaldrive") {
                Label("本地加密保存", systemImage: "lock.doc").foregroundStyle(palette.accent)
                Text("解锁密码和云盘凭证加密保存在这台 Mac 上，日常使用无需系统钥匙串授权。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var syncSettings: some View {
        Group {
            WalletFormSection(title: "WebDAV 云盘", icon: "externaldrive") {
                if connectionSuccess && !isEditingConfig {
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.icloud").font(.title2).foregroundStyle(palette.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("云盘连接已保存").font(.headline)
                            Text(webdavUrl).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Button("修改连接") { isEditingConfig = true }
                    }
                } else {
                    WalletFormField(title: "服务器地址") { TextField("服务器地址", text: $webdavUrl, prompt: Text("https://")) }
                    HStack(alignment: .top, spacing: 18) {
                        WalletFormField(title: "用户名") { TextField("用户名", text: $webdavUsername) }
                        WalletFormField(title: "应用密码") { SecureField("应用密码", text: $webdavPassword) }
                    }
                    WalletFormField(title: "同步密钥") { SecureField("同步密钥", text: $webdavSyncPassword) }
                    Text("各设备需填写相同的同步密钥。请妥善保管，忘记后无法读取云端卡片。")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("保存并测试连接", action: saveWebDAVConfig)
                            .buttonStyle(.borderedProminent)
                            .disabled(isTestingConnection || webdavUrl.isEmpty || webdavUsername.isEmpty || webdavPassword.isEmpty || webdavSyncPassword.isEmpty)
                        if isTestingConnection { ProgressView().controlSize(.small) }
                        if connectionSuccess {
                            Button("取消修改") { loadSavedConfig(); isEditingConfig = false }
                        }
                    }
                }
                if !connectionStatus.isEmpty { Text(connectionStatus).font(.caption).foregroundStyle(.secondary) }
            }
            WalletFormSection(title: "自动同步", icon: "arrow.triangle.2.circlepath") {
                WalletSettingsToggle(title: "启用云盘同步", detail: "让各设备上的卡片保持一致。", icon: "cloud", isOn: $enableWebDAVBridge)
                    .onChange(of: enableWebDAVBridge) { _, enabled in syncCoordinator.setWebDAVBridgeEnabled(enabled) }
                if enableWebDAVBridge {
                    Picker("自动检查频率", selection: $autoCheckInterval) {
                        Text("每分钟").tag(60.0)
                        Text("每五分钟").tag(300.0)
                        Text("每十五分钟").tag(900.0)
                        Text("每三十分钟").tag(1800.0)
                        Text("每小时").tag(3600.0)
                    }
                    .onChange(of: autoCheckInterval) { _, _ in bridgeService.start() }
                }
                Text("同步进度、历史记录和每次卡片变更，可在左侧“云端同步”中查看。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var dataSettings: some View {
        Group {
            WalletFormSection(title: "存储与数据", icon: "internaldrive") {
                Button { showingStorageManagement = true } label: { Label("存储管理", systemImage: "internaldrive") }
                Text("查看卡片图片占用与缓存。清理缓存不会删除卡片或云端数据。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            WalletFormSection(title: "帮助", icon: "questionmark.circle") {
                Button { showingHelp = true } label: { Label("使用帮助", systemImage: "questionmark.circle") }
                Text("检查卡片、优惠用卡和卡片统计，可从侧栏直接打开。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    
    private func loadSelectedSection() {
        if selectedSection == .sync { loadSavedConfig() }
        if selectedSection == .security { isLockEnabled = lockManager.hasPassword }
    }

    private func loadSavedConfig() {
        KeychainManager.retryFailedReads()
        if let config = WebDAVClient.shared.loadConfig() {
            webdavUrl = config.url
            webdavUsername = config.username
            webdavPassword = KeychainManager.load(key: "webdav_password") ?? ""
            webdavSyncPassword = KeychainManager.load(key: "webdav_sync_password_v4") ?? ""
            
            if !webdavUrl.isEmpty && !webdavUsername.isEmpty && !webdavPassword.isEmpty && !webdavSyncPassword.isEmpty {
                connectionSuccess = true
                connectionStatus = String(localized: "已载入保存的云盘设置。")
                isEditingConfig = false
            }
        }
    }
    
    private func saveWebDAVConfig() {
        let trimmedSyncPassword = webdavSyncPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSyncPassword.count >= 10 else {
            connectionSuccess = false
            connectionStatus = String(localized: "同步密钥至少需要十位。")
            return
        }

        isTestingConnection = true
        connectionStatus = String(localized: "正在检查云盘连接与读写权限…")
        
        let result = WebDAVClient.shared.saveConfig(url: webdavUrl, username: webdavUsername, password: webdavPassword)
        switch result {
        case .success:
            guard case .success = KeychainManager.save(key: "webdav_sync_password_v4", value: trimmedSyncPassword) else {
                isTestingConnection = false
                connectionSuccess = false
                connectionStatus = String(localized: "同步密钥未能保存，请检查密码存储权限后重试。")
                return
            }
            WebDAVClient.shared.testConnection { res in
                DispatchQueue.main.async {
                    self.isTestingConnection = false
                    switch res {
                    case .success:
                        self.connectionSuccess = true
                        self.connectionStatus = String(localized: "连接成功，云盘可以正常读写。")
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            self.isEditingConfig = false
                        }
                        
                        syncCoordinator.setWebDAVBridgeEnabled(true)
                    case .failure(let error):
                        self.connectionSuccess = false
                        self.connectionStatus = String(localized: "连接失败，请检查地址、账号、密码和网络后重试。")
                        print("WebDAV connection failed: \(error.localizedDescription)")
                    }
                }
            }
        case .failure(let error):
            isTestingConnection = false
            connectionSuccess = false
            connectionStatus = String(localized: "设置未能保存，请检查密码存储权限。")
            print("WebDAV configuration failed: \(error.localizedDescription)")
        }
    }

    private func formatSyncDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(ceil(duration)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分\(seconds)秒"
        }
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        }
        return "\(seconds)秒"
    }

    private func syncByteProgressText(_ progress: SyncFileProgress) -> String? {
        guard let transferred = progress.transferredBytes,
              let total = progress.totalBytes,
              total > 0 else {
            return nil
        }
        let prefix = progress.phase.contains("上传") || progress.phase.contains("保存") ? "已上传" : "已下载"
        return "\(prefix) \(formatBytes(transferred)) / \(formatBytes(total))"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

private struct MacHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("使用帮助", systemImage: "questionmark.circle.fill")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    helpSection(
                        "卡包管理",
                        icon: "creditcard.fill",
                        lines: [
                            "使用右上角“新增卡片”录入信用卡或储蓄卡。",
                            "搜索支持银行、别名、卡号和卡类别；分组与排序设置位于卡包顶部。",
                            "点击“批量操作”可批量更新年费、有效期、卡类别或删除卡片。"
                        ]
                    )
                    helpSection(
                        "优惠用卡与提醒",
                        icon: "sparkles",
                        lines: [
                            String(localized: "侧栏中的“优惠用卡”可按所选日期比较免息期。"),
                            "卡片提醒涵盖账单日、还款日、年费和有效期。",
                            "允许系统通知后，提醒会提前排程；即使应用退出，macOS 仍可按计划投递。"
                        ]
                    )
                    helpSection(
                        "云同步",
                        icon: "icloud.fill",
                        lines: [
                            "WebDAV 使用同步密钥加密，四端可共享同一份同步账本。",
                            String(localized: "密码在本机加密保存，不会随卡片上传。"),
                            String(localized: "点击侧栏底部的“云端同步”，查看同步历史与字段变更详情。")
                        ]
                    )
                    helpSection(
                        "安全与快捷键",
                        icon: "lock.shield.fill",
                        lines: [
                            "可开启密码和 Touch ID，并在忘记密码时通过本机卡片信息验证。",
                            "卡片详情中按 ⌘E 编辑，Esc 关闭弹窗。",
                            "请勿将同步密钥、完整卡号或 CVV 分享给他人。"
                        ]
                    )
                }
                .padding(24)
            }
        }
        .frame(width: 680, height: 620)
    }

    private func helpSection(_ title: String, icon: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.cyan)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(line)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035))
        .cornerRadius(12)
    }
}

private struct MacStorageManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var localDataSize: Int64 = 0
    @State private var cacheSize: Int64 = 0
    @State private var cloudSize: Int64 = 0
    @State private var cloudFileCount = 0
    @State private var cloudStatus = "正在读取云端空间..."
    @State private var isLoading = false
    @State private var cleanupMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("存储管理", systemImage: "internaldrive.fill")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    storageCard("本机卡片与账本", value: formatBytes(localDataSize), icon: "externaldrive.fill", color: .cyan)
                    storageCard("缓存与临时文件", value: formatBytes(cacheSize), icon: "archivebox.fill", color: .orange)
                    storageCard("WebDAV 云端", value: formatBytes(cloudSize), icon: "icloud.fill", color: .purple)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("云端备份")
                        .font(.headline)
                    Text(cloudStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if cloudFileCount > 0 {
                        Text("共 \(cloudFileCount) 个备份文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.035))
                .cornerRadius(12)

                HStack {
                    Button("重新检测") { refresh() }
                        .disabled(isLoading)
                    Button("清理缓存", role: .destructive) { clearCaches() }
                        .disabled(isLoading || cacheSize == 0)
                    if isLoading { ProgressView().controlSize(.small) }
                    Spacer()
                    Text(cleanupMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Text("清理缓存不会删除卡片、同步账本、WebDAV 配置或安全密码。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
        .frame(width: 720, height: 430)
        .onAppear(perform: refresh)
    }

    private func storageCard(_ title: LocalizedStringKey, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(12)
    }

    private func refresh() {
        isLoading = true
        cleanupMessage = ""
        let manager = FileManager.default
        if let appSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            localDataSize = directorySize(appSupport.appendingPathComponent("CardWallet", isDirectory: true))
        }
        if let caches = manager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let ownCache = WalletCacheStorage.directory(in: caches)
            let values = try? ownCache.resourceValues(forKeys: [.isSymbolicLinkKey])
            cacheSize = values?.isSymbolicLink == true ? 0 : directorySize(ownCache)
        }

        guard WebDAVClient.shared.loadConfig() != nil else {
            cloudSize = 0
            cloudFileCount = 0
            cloudStatus = "尚未配置 WebDAV 云同步"
            isLoading = false
            return
        }

        WebDAVClient.shared.getBackupList { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let files):
                    cloudSize = files.reduce(0) { $0 + $1.size }
                    cloudFileCount = files.count
                    cloudStatus = files.isEmpty ? "云端暂无备份文件" : "已读取云端备份占用"
                case .failure(let error):
                    cloudSize = 0
                    cloudFileCount = 0
                    cloudStatus = "读取失败：\(error.localizedDescription)"
                }
                isLoading = false
            }
        }
    }

    private func clearCaches() {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        do {
            try WalletCacheStorage.clear(in: caches)
            URLCache.shared.removeAllCachedResponses()
            refresh()
            cleanupMessage = String(localized: "缓存已清理，需要时会重新生成。卡片和图片未被删除。")
        } catch {
            cleanupMessage = String(localized: "部分缓存未能清理，请检查权限后重试。")
        }
    }

    private func directorySize(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}
