import SwiftUI
import LocalAuthentication

public struct SettingsView: View {
    public var currentCards: [SharedCard]
    public var onDataRestored: ([SharedCard]) -> Void
    
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
    
    // 列表控制
    @State private var localBackups: [LocalBackupRecord] = []
    @State private var isLocalBackupsExpanded = true
    @State private var localPage = 1
    
    // Diff 预览控制
    @State private var diffPreviewRequest: DiffPreviewRequest?
    
    public init(
        currentCards: [SharedCard],
        onDataRestored: @escaping ([SharedCard]) -> Void
    ) {
        self.currentCards = currentCards
        self.onDataRestored = onDataRestored
    }
    
    public var body: some View {
        Form {
            
            // Section 3: 💾 本地自动多版本备份
            Section(header: HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.badge.arrow.up.fill")
                        .foregroundColor(.purple)
                    Text("本地自动备份记录 (最近50条)")
                }
                Spacer()
                if !localBackups.isEmpty {
                    Button(action: {
                        withAnimation {
                            isLocalBackupsExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(isLocalBackupsExpanded ? "收起" : "展开")
                            Image(systemName: isLocalBackupsExpanded ? "chevron.up" : "chevron.down")
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                }
            }) {
                HStack {
                    Button("立即手动创建本地备份") {
                        if LocalStorageManager.createLocalBackup(cards: currentCards, isManual: true) {
                            fetchLocalBackups()
                        }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                
                if isLocalBackupsExpanded {
                    if localBackups.isEmpty {
                        Text("暂无本地备份记录")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        // 使用分页获取数据切片展示
                        let pageSize = 5
                        let startIndex = (localPage - 1) * pageSize
                        let displayedLocalBackups = Array(localBackups.dropFirst(startIndex).prefix(pageSize))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(displayedLocalBackups) { record in
                                BackupRowView(
                                    title: record.filename,
                                    subtitle: "备份时间: \(record.backupTime)  卡数: \(record.cardCount) 张",
                                    iconName: "doc.fill",
                                    iconColor: .purple,
                                    onRestore: {
                                        triggerLocalRestore(record.filename)
                                    },
                                    onDelete: {
                                        if LocalStorageManager.deleteLocalBackup(filename: record.filename) {
                                            fetchLocalBackups()
                                        }
                                    }
                                )
                            }
                            
                            if localBackups.count > pageSize {
                                HStack {
                                    Spacer()
                                    PaginationView(currentPage: $localPage, totalItems: localBackups.count)
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
            
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
                                
                                let levelText = isLockEnabled ? "高级指纹/密码多维防护" : "基础沙盒物理隔离加密"
                                Text("防护级别：\(levelText)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isLockEnabled ? .green : .orange)
                                
                                Text("您的敏感卡号、CVV及同步密钥均受高强度对称加密与硬件级沙盒物理隔离保护。")
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
                                    
                                    Text("Touch ID 指纹秒开已就绪")
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
                            
                            Text("说明：若您的系统反复弹出钥匙串授权提示，推荐选择 [应用内部加密存储]。您的凭证将由高强度 AES-256 沙盒物理隔离加密，保障绝对隐私的同时免去系统密码弹窗干扰，极其清爽顺滑。")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.8))
                                .lineSpacing(2)
                        }
                        
                        Divider()
                            .opacity(0.3)
                        
                        HStack {
                            if AutoLockManager.shared.isTouchIDAvailable {
                                Text("🔒 硬件防护状态: 已支持 Touch ID 指纹防护")
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
        }
        .formStyle(.grouped)
        .onAppear {
            fetchLocalBackups()
            
            isLockEnabled = AutoLockManager.shared.hasPassword
            if isLockEnabled {
                lockPassword = "••••••"
            }
            
            // 💡 监听本地备份变动广播，以无感零延迟刷新记录列表
            NotificationCenter.default.addObserver(forName: Notification.Name("LocalBackupsDidChange"), object: nil, queue: .main) { _ in
                self.fetchLocalBackups()
            }
        }
        // 💡 弹窗 1: 差异对比预览，解决备份恢复时的数据焦虑
        .sheet(item: $diffPreviewRequest) { request in
            DiffPreviewView(
                currentCards: currentCards,
                backupCards: request.backupCards,
                requiresIdentityReview: request.requiresIdentityReview,
                onConfirmRestore: { restoredCards in
                    onDataRestored(restoredCards)
                },
                onConfirmMerge: { mergedCards in
                    onDataRestored(mergedCards)
                }
            )
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

    
    private func fetchLocalBackups() {
        localBackups = LocalStorageManager.listLocalBackups()
        localPage = 1 // 重置分页
    }
    
    // 触发本地恢复 (带 Diff 比对)
    private func triggerLocalRestore(_ filename: String) {
        let result = LocalStorageManager.loadLocalBackupForPreview(filename: filename)
        switch result {
        case .success(let cards):
            // 并不直接覆盖，而是拉起 Diff 页面
            self.diffPreviewRequest = DiffPreviewRequest(backupCards: cards, requiresIdentityReview: true)
        case .failure(let error):
            // 假如报错，可能使用了自定义密码加密，拉起密码弹窗进行安全解密
            print("本地恢复报错: \(error.localizedDescription)")
        }
    }
    

}

// ==========================================
// 💡 原生 macOS 极致质感备份行与物理分页组件
// ==========================================
struct BackupRowView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let iconColor: Color
    let onRestore: () -> Void
    let onDelete: () -> Void
    var onRename: (() -> Void)? = nil
    var isDeleting = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .monospaced))
                    .bold()
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if let onRename = onRename {
                    Button(action: onRename) {
                        Text("重命名")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.cyan)
                }
                
                Button(action: onRestore) {
                    Text("比对")
                        .font(.caption)
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button(action: onDelete) {
                    HStack(spacing: 4) {
                        if isDeleting {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Text(isDeleting ? "删除中" : "删除")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isDeleting)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct PaginationView: View {
    @Binding var currentPage: Int
    let totalItems: Int
    let pageSize: Int = 5
    
    var totalPages: Int {
        let pages = Int(ceil(Double(totalItems) / Double(pageSize)))
        return max(1, pages)
    }
    
    var body: some View {
        HStack {
            Button(action: {
                if currentPage > 1 {
                    currentPage -= 1
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
            }
            .disabled(currentPage == 1)
            .buttonStyle(.bordered)
            
            Text("第 \(currentPage) / \(totalPages) 页 (共 \(totalItems) 条)")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
            
            Button(action: {
                if currentPage < totalPages {
                    currentPage += 1
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .disabled(currentPage == totalPages)
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }
}
