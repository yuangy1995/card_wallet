import SwiftUI
import LocalAuthentication

public struct SettingsView: View {
    // 💡 敏感安全凭证存储介质
    @State private var securityStorageMode = KeychainManager.currentStorageMode
    @State private var storageMigrationStatusText = ""
    @State private var storageMigrationSuccess = true
    
    // 💡 隐私安全卡片聚合与高阶动效控制
    @State private var isEditingSecurity = false
    @State private var isSecurityPulseAnimating = false
    
    // 密码锁设置
    @State private var lockPassword = ""
    @State private var isLockEnabled = false
    @State private var passwordStatusText = ""
    
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
    
    // 自动同步与 iCloud 配置存储
    @AppStorage("enable_icloud_sync") private var enableICloudSync = false
    @AppStorage("enable_webdav_bridge") private var enableWebDAVBridge = true
    @AppStorage("auto_check_interval") private var autoCheckInterval = 300.0
    
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared
    @ObservedObject private var cloudKitService = CloudKitSyncService.shared
    @ObservedObject private var bridgeService = WebDAVBridgeService.shared
    
    public var body: some View {
        Form {
            // Section 4: 🛡️ 全方位隐私安全与凭证保护 (锁屏防窥与凭证存储二合一，高级呼吸动效安心 UI)
            Section(header: HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                Text("全方位隐私安全与凭证保护")
            }) {
                if !isEditingSecurity {
                    // 💡 安心状态下的高阶原生 UI & 呼吸光环波纹动效
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 20) {
                            // 左侧：呼吸光环安全盾动效
                            ZStack {
                                // 呼吸波动外环 2
                                Circle()
                                    .stroke(Color.green.opacity(0.15), lineWidth: 2)
                                    .frame(width: 60, height: 60)
                                    .scaleEffect(isSecurityPulseAnimating ? 1.25 : 0.95)
                                    .opacity(isSecurityPulseAnimating ? 0.0 : 0.8)
                                
                                // 呼吸波动外环 1
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                    .scaleEffect(isSecurityPulseAnimating ? 1.15 : 0.98)
                                
                                // 中心防线主盾 (绿色-青色渐变，极佳科技拟物感)
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.85), Color.cyan.opacity(0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                    .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 3)
                                
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 65, height: 65)
                            .onAppear {
                                // 💡 启用优雅的呼吸微动画
                                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                    isSecurityPulseAnimating = true
                                }
                            }
                            
                            // 右侧：核心提示与防线评级
                            VStack(alignment: .leading, spacing: 4) {
                                Text("本地隐私安全防护已全面就绪")
                                    .font(.system(.subheadline, design: .rounded))
                                    .bold()
                                    .foregroundColor(.primary)
                                
                                let levelText = isLockEnabled ? "指纹或密码保护" : "本机加密保存"
                                Text("防护级别：\(levelText)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isLockEnabled ? .green : .orange)
                                
                                Text("您的卡号、CVV 和同步密码会加密保存在本机。")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 6)
                        
                        Divider()
                            .opacity(0.5)
                        
                        // 细分防护状态列表
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: isLockEnabled ? "lock.fill" : "lock.open.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(isLockEnabled ? .green : .orange)
                                    .frame(width: 14, alignment: .center)
                                
                                Text("自动闲置防窥锁屏:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Text(isLockEnabled ? "已启用" : "未开启 (建议前往配置以防窥)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isLockEnabled ? .green : .orange)
                            }
                            
                            if AutoLockManager.shared.isTouchIDAvailable {
                                HStack(spacing: 12) {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                        .frame(width: 14, alignment: .center)
                                    
                                    Text("生物特征硬件防护:")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Touch ID 解锁已开启")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                    .frame(width: 14, alignment: .center)
                                
                                Text("机密存储模式介质:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Text(securityStorageMode.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isEditingSecurity = true
                                }
                            }) {
                                Label("调整隐私安全策略", systemImage: "slider.horizontal.3")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.015))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                } else {
                    // 💡 卡片内嵌策略编辑模式 (平滑过渡)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.green)
                                Text("配置您的本地数据防护策略")
                            }
                                .font(.system(.subheadline, design: .rounded))
                                .bold()
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        // 1. 防窥锁屏配置子模块
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle("开启闲置/后台自动防窥锁屏", isOn: $isLockEnabled)
                                    .onChange(of: isLockEnabled) { _, newValue in
                                        if !newValue {
                                            AutoLockManager.shared.removePassword()
                                            lockPassword = ""
                                            withAnimation {
                                                passwordStatusText = "⚠️ 防窥锁屏密码已安全清除。"
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                withAnimation {
                                                    passwordStatusText = ""
                                                }
                                            }
                                        } else {
                                            if AutoLockManager.shared.hasPassword {
                                                lockPassword = "••••••"
                                            }
                                        }
                                    }
                            }
                            
                            if isLockEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        SecureField(AutoLockManager.shared.hasPassword ? "••••••" : "输入本地锁屏保护密码", text: $lockPassword)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 180)
                                        
                                        Button("确定设置") {
                                            if !lockPassword.isEmpty && lockPassword != "••••••" {
                                                AutoLockManager.shared.setPassword(lockPassword)
                                                withAnimation {
                                                    passwordStatusText = "✅ 锁屏密码已启用并受硬件保护！"
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                    withAnimation {
                                                        passwordStatusText = ""
                                                    }
                                                }
                                            } else if lockPassword == "••••••" {
                                                withAnimation {
                                                    passwordStatusText = "✅ 密码已处于锁定保护中，无需修改。"
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                    withAnimation {
                                                        passwordStatusText = ""
                                                    }
                                                }
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(lockPassword.isEmpty)
                                    }
                                    
                                    if !passwordStatusText.isEmpty {
                                        Text(passwordStatusText)
                                            .font(.system(size: 10))
                                            .foregroundColor(passwordStatusText.contains("✅") ? .green : .orange)
                                            .transition(.opacity)
                                    }
                                }
                                .padding(.leading, 8)
                                .transition(.slide)
                            }
                        }
                        
                        Divider()
                            .opacity(0.3)
                        
                        // 2. 凭证存储介质配置子模块
                        VStack(alignment: .leading, spacing: 8) {
                            Text("机密凭证存储介质：")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Picker("凭证存储介质", selection: $securityStorageMode) {
                                ForEach(KeychainManager.SecurityStorageMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: securityStorageMode) { _, newMode in
                                triggerStorageModeMigration(newMode)
                            }
                            
                            if !storageMigrationStatusText.isEmpty {
                                Text(storageMigrationStatusText)
                                    .font(.system(size: 10))
                                    .foregroundColor(storageMigrationSuccess ? .green : .red)
                                    .transition(.opacity)
                            }
                            
                            Text("说明：如果系统经常弹出钥匙串授权提示，建议选择 [应用内部加密存储]。这样可以减少系统密码弹窗，同时仍会加密保存您的同步账号。")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.8))
                                .lineSpacing(2)
                        }
                        
                        Divider()
                            .opacity(0.3)
                        
                        HStack {
                            if AutoLockManager.shared.isTouchIDAvailable {
                                Text("🔒 当前设备支持 Touch ID 解锁")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("保存并开启安全防护") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isEditingSecurity = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.015))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }
            }
            
            // Section 5: WebDAV 账号同步配置
            Section(header: HStack(spacing: 6) {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .foregroundColor(.cyan)
                Text("WebDAV 账号同步配置")
            }) {
                if connectionSuccess && !isEditingConfig {
                    // 绑定状态展示卡片
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            Image(systemName: "checkmark.icloud.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.green)
                                .padding(8)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("加密云同步已就绪")
                                    .font(.system(.subheadline, design: .rounded))
                                    .bold()
                                    .foregroundColor(.primary)
                                
                                Text("同步文件使用同步密钥加密保存到 WebDAV，方便多设备同步。")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Divider()
                            .opacity(0.6)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("服务地址:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                Text(webdavUrl)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            HStack(spacing: 8) {
                                Text("同步账号:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                Text(webdavUsername)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1)
                            }

                            HStack(spacing: 8) {
                                Text("同步方式:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                Text("加密云同步")
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1)
                            }
                        }
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isEditingConfig = true
                                }
                            }) {
                                Label("修改同步配置", systemImage: "pencil")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.02))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.vertical, 4)
                } else {
                    // 配置输入模式
                    TextField("WebDAV URL", text: $webdavUrl, prompt: Text("例如：https://dav.jianguoyun.com/dav/"))
                    TextField("用户名", text: $webdavUsername, prompt: Text("输入 WebDAV 账号邮箱"))
                    SecureField("应用密码", text: $webdavPassword, prompt: Text("输入 WebDAV 第三方应用独立授权密码"))
                    SecureField("同步密钥", text: $webdavSyncPassword, prompt: Text("三端必须填写同一个同步密钥"))
                    Text("该密钥用于加密 WebDAV 上的云同步文件。忘记后无法解密云端同步数据。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button(action: saveWebDAVConfig) {
                            Text(connectionSuccess ? "保存并重新测试" : "保存并测试连接")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isTestingConnection || webdavUrl.isEmpty || webdavUsername.isEmpty || webdavPassword.isEmpty || webdavSyncPassword.isEmpty)
                        
                        if connectionSuccess {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isEditingConfig = false
                                    loadSavedConfig()
                                }
                            }) {
                                Text("取消修改")
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if isTestingConnection {
                            ProgressView().scaleEffect(0.5).frame(width: 20, height: 20)
                        }
                        
                        if !connectionStatus.isEmpty {
                            Text(connectionStatus)
                                .font(.caption)
                                .foregroundColor(connectionSuccess ? .green : .red)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            
            // Section 6: iCloud 私有同步
            Section(header: HStack(spacing: 6) {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.cyan)
                Text("iCloud 私有同步")
            }) {
                Toggle("通过 iCloud 同步卡片与删除记录", isOn: $enableICloudSync)
                    .onChange(of: enableICloudSync) { _, enabled in
                        syncCoordinator.setICloudEnabled(enabled)
                    }

                Text(cloudKitService.statusDescription)
                    .font(.caption)
                    .foregroundColor(cloudKitService.isAvailable ? .green : .secondary)

                Text("iCloud 同步需要使用已开启云能力的正式构建；不可用时，WebDAV 加密云同步仍可正常使用。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Section 7: 自动同步
            Section(header: HStack(spacing: 6) {
                Image(systemName: "icloud.circle.fill")
                    .foregroundColor(.cyan)
                Text("自动同步")
            }) {
                Toggle("启用云端自动同步", isOn: $enableWebDAVBridge)
                    .onChange(of: enableWebDAVBridge) { _, enabled in
                        syncCoordinator.setWebDAVBridgeEnabled(enabled)
                    }
                
                if enableWebDAVBridge {
                    Picker("检测比对周期", selection: $autoCheckInterval) {
                        Text("每 1 分钟检测一次").tag(60.0)
                        Text("每 5 分钟检测一次 (默认)").tag(300.0)
                        Text("每 15 分钟检测一次").tag(900.0)
                        Text("每 30 分钟检测一次").tag(1800.0)
                        Text("每 1 小时检测一次").tag(3600.0)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: autoCheckInterval) { _, _ in
                        WebDAVBridgeService.shared.start()
                    }
                    .transition(.slide)
                }

                Text(bridgeService.statusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if bridgeService.isSyncing {
                    if bridgeService.syncProgress.total > 0 {
                        ProgressView(
                            value: Double(bridgeService.syncProgress.step),
                            total: Double(bridgeService.syncProgress.total)
                        )
                    }

                    if !bridgeService.syncProgress.detail.isEmpty {
                        Text(bridgeService.syncProgress.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("已用时：\(formatSyncDuration(bridgeService.syncElapsedSeconds))")
                        .font(.caption)
                        .foregroundColor(.cyan)

                    if let byteText = syncByteProgressText(bridgeService.syncProgress) {
                        Text(byteText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let duration = bridgeService.lastSyncDurationSeconds {
                    Text("上次耗时：\(formatSyncDuration(duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 14) {
                    Button("立即同步一次") {
                        WebDAVBridgeService.shared.synchronize(forceUpload: true)
                    }
                    .disabled(!enableWebDAVBridge || bridgeService.isSyncing)
                    
                    Text("详细同步变更日志请在「工具 -> 同步历史与详情」菜单中查看。")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadSavedConfig()
            isLockEnabled = AutoLockManager.shared.hasPassword
            if isLockEnabled {
                lockPassword = "••••••"
            }
        }
    }
    
    private func triggerStorageModeMigration(_ newMode: KeychainManager.SecurityStorageMode) {
        let success = KeychainManager.migrate(to: newMode)
        withAnimation {
            storageMigrationSuccess = success
            if success {
                storageMigrationStatusText = "✅ 安全凭据已成功双向热迁移至 [\(newMode.displayName)]！"
            } else {
                storageMigrationStatusText = "❌ 迁移安全凭据失败，请检查系统钥匙串权限"
            }
        }
        // 3秒后自动淡出
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                storageMigrationStatusText = ""
            }
        }
    }
    
    private func loadSavedConfig() {
        if let config = WebDAVClient.shared.loadConfig() {
            webdavUrl = config.url
            webdavUsername = config.username
            webdavPassword = KeychainManager.load(key: "webdav_password") ?? ""
            webdavSyncPassword = KeychainManager.load(key: "webdav_sync_password_v4") ?? ""
            
            if !webdavUrl.isEmpty && !webdavUsername.isEmpty && !webdavPassword.isEmpty && !webdavSyncPassword.isEmpty {
                connectionSuccess = true
                connectionStatus = "✅ 连接成功！云端同步就绪。"
                isEditingConfig = false
            }
        }
    }
    
    private func saveWebDAVConfig() {
        let trimmedSyncPassword = webdavSyncPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSyncPassword.count >= 10 else {
            connectionSuccess = false
            connectionStatus = "❌ 同步密钥至少 10 位"
            return
        }

        isTestingConnection = true
        connectionStatus = "正在测试连接并验证 credit-card-backup 目录..."
        
        let result = WebDAVClient.shared.saveConfig(url: webdavUrl, username: webdavUsername, password: webdavPassword)
        switch result {
        case .success:
            KeychainManager.save(key: "webdav_sync_password_v4", value: trimmedSyncPassword)
            WebDAVClient.shared.testConnection { res in
                DispatchQueue.main.async {
                    self.isTestingConnection = false
                    switch res {
                    case .success:
                        self.connectionSuccess = true
                        self.connectionStatus = "✅ 连接成功！云端同步就绪。"
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            self.isEditingConfig = false
                        }
                        
                        syncCoordinator.setWebDAVBridgeEnabled(true)
                    case .failure(let error):
                        self.connectionSuccess = false
                        self.connectionStatus = "❌ 连接失败: \(error.localizedDescription)"
                    }
                }
            }
        case .failure(let error):
            isTestingConnection = false
            connectionSuccess = false
            connectionStatus = "❌ \(error.localizedDescription)"
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
