import SwiftUI

private struct CloudDeleteFeedback: Identifiable {
    let id = UUID()
    let isSuccess: Bool
    let title: String
    let filename: String
}

public struct CloudSyncView: View {
    public var currentCards: [SharedCard]
    public var onDataRestored: ([SharedCard]) -> Void
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared
    @ObservedObject private var cloudKitService = CloudKitSyncService.shared
    @ObservedObject private var bridgeService = WebDAVBridgeService.shared
    
    // WebDAV 配置
    @State private var webdavUrl = ""
    @State private var webdavUsername = ""
    @State private var webdavPassword = ""
    @State private var webdavSyncPassword = ""
    
    // 连接状态
    @State private var connectionStatus = ""
    @State private var isTestingConnection = false
    @State private var connectionSuccess = false
    @State private var isEditingConfig = false
    @State private var skeletonOpacity = 0.45
    
    // 列表控制
    @State private var cloudBackups: [WebDAVBackupFile] = []
    @State private var isLoadingCloud = false
    @State private var isCloudBackupsExpanded = true
    @State private var cloudPage = 1
    
    // Diff 预览控制
    @State private var diffPreviewRequest: DiffPreviewRequest?
    @State private var compareErrorMessage = ""
    
    // 密码弹窗控制 (针对云端加密备份解密)
    @State private var showingPasswordPrompt = false
    @State private var decryptPassword = ""
    @State private var rawCipherPendingDecrypt = ""
    @State private var pendingBackupFilename = ""
    
    // 自动收敛与 iCloud 配置项
    @AppStorage("enable_icloud_sync") private var enableICloudSync = false
    @AppStorage("enable_webdav_bridge") private var enableWebDAVBridge = true
    @AppStorage("auto_check_interval") private var autoCheckInterval = 300.0
    
    // 💡 云端备份重命名控制
    @State private var showingRenamePrompt = false
    @State private var oldFilenameToRename = ""
    @State private var newFilenameToRename = ""
    @State private var isRenaming = false
    @State private var renameError = ""

    // 云端备份手动删除控制
    @State private var showingDeleteConfirmation = false
    @State private var pendingDeleteFilename = ""
    @State private var deletingCloudFilename: String?
    @State private var deleteFeedback: CloudDeleteFeedback?
    
    public init(
        currentCards: [SharedCard],
        onDataRestored: @escaping ([SharedCard]) -> Void
    ) {
        self.currentCards = currentCards
        self.onDataRestored = onDataRestored
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部极简大厂级标题（SF Symbols 强力去 Emoji 原生风格）
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                    Text("云端同步")
                        .font(.title2)
                        .bold()
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            Form {
                // Section 1: WebDAV 账号同步配置
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

                // Section 2: WebDAV 与 iCloud 的 Mac 中心桥接
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
                        Text("已用时：\(formatSyncDuration(bridgeService.syncElapsedSeconds))")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    } else if let duration = bridgeService.lastSyncDurationSeconds {
                        Text("上次耗时：\(formatSyncDuration(duration))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("立即同步一次") {
                        WebDAVBridgeService.shared.synchronize(forceUpload: true)
                    }
                    .disabled(!enableWebDAVBridge || bridgeService.isSyncing)
                }
            }
            .formStyle(.grouped)
        }
        .onAppear {
            loadSavedConfig()
        }
        .alert("确认删除云端备份？", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {
                pendingDeleteFilename = ""
            }
            Button("永久删除", role: .destructive) {
                let filename = pendingDeleteFilename
                pendingDeleteFilename = ""
                executeDeleteCloud(filename)
            }
        } message: {
            Text("文件：\(pendingDeleteFilename)\n\n删除后无法从云端恢复此备份，请确认是否继续。")
        }
        .alert("无法打开备份比对", isPresented: Binding(
            get: { !compareErrorMessage.isEmpty },
            set: { if !$0 { compareErrorMessage = "" } }
        )) {
            Button("知道了", role: .cancel) {
                compareErrorMessage = ""
            }
        } message: {
            Text(compareErrorMessage)
        }
        // Diff 对比弹窗
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
        // 密码解密弹窗
        .sheet(isPresented: $showingPasswordPrompt) {
            VStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.open.fill")
                        .foregroundColor(.cyan)
                    Text("加密文件解密")
                }
                .font(.headline)
                
                Text("检测到此备份被自定义密码加密，请输入密码以解密恢复：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                SecureField("输入解密密码", text: $decryptPassword)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                
                HStack(spacing: 16) {
                    Button("取消") {
                        showingPasswordPrompt = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("解密并导入") {
                        executeDecryptRestore()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(decryptPassword.isEmpty)
                }
            }
            .padding(20)
            .frame(width: 320, height: 180)
        }
        // 💡 备份重命名 Sheet
        .sheet(isPresented: $showingRenamePrompt) {
            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.and.outline")
                        .foregroundColor(.cyan)
                    Text("重命名云备份文件")
                }
                .font(.headline)
                
                Text("输入该云端备份的新文件名 (需保留 .json 结尾)：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("新文件名", text: $newFilenameToRename)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
                
                if !renameError.isEmpty {
                    Text(renameError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                HStack(spacing: 16) {
                    Button("取消") {
                        showingRenamePrompt = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRenaming)
                    
                    Button("确认修改") {
                        executeRename()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(isRenaming || newFilenameToRename.isEmpty)
                }
            }
            .padding(20)
            .frame(width: 320, height: 200)
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
    
    private func fetchCloudBackups() {
        isLoadingCloud = true
        WebDAVClient.shared.getBackupList { result in
            DispatchQueue.main.async {
                self.isLoadingCloud = false
                switch result {
                case .success(let files):
                    self.cloudBackups = files
                    self.cloudPage = 1
                case .failure:
                    self.cloudBackups = []
                    self.cloudPage = 1
                }
            }
        }
    }
    
    private func triggerDownloadRestore(_ filename: String) {
        WebDAVClient.shared.downloadBackup(filename: filename) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let content):
                    self.processDownloadedContent(content, filename: filename)
                case .failure(let error):
                    self.compareErrorMessage = "下载云端备份失败：\(error.localizedDescription)"
                }
            }
        }
    }
    
    private func processDownloadedContent(_ content: String, filename: String) {
        do {
            let jsonString = try CryptoManager.decrypt(cipherText: content)
            self.completeRestoreWithJSON(jsonString)
        } catch {
            self.rawCipherPendingDecrypt = content
            self.pendingBackupFilename = filename
            self.decryptPassword = ""
            self.showingPasswordPrompt = true
        }
    }
    
    private func executeDecryptRestore() {
        showingPasswordPrompt = false
        do {
            let jsonString = try CryptoManager.decrypt(cipherText: rawCipherPendingDecrypt, password: decryptPassword)
            self.completeRestoreWithJSON(jsonString)
        } catch {
            compareErrorMessage = "密码解密失败：\(error.localizedDescription)"
        }
    }
    
    private func completeRestoreWithJSON(_ jsonString: String) {
        guard let cards = DataMigrationManager.cardsFromBackupJSON(jsonString) else {
            compareErrorMessage = "此备份文件不是可识别的账本格式，可能文件已损坏或不是本应用生成的备份。"
            return
        }
        let requiresIdentityReview = !DataMigrationManager.backupJSONIsV3Snapshot(jsonString)
        self.diffPreviewRequest = nil
        DispatchQueue.main.async {
            self.diffPreviewRequest = DiffPreviewRequest(
                backupCards: cards,
                requiresIdentityReview: requiresIdentityReview
            )
        }
    }
    
    private func requestDeleteCloud(_ filename: String) {
        guard deletingCloudFilename == nil else { return }
        pendingDeleteFilename = filename
        showingDeleteConfirmation = true
    }

    private func executeDeleteCloud(_ filename: String) {
        guard !filename.isEmpty else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            deletingCloudFilename = filename
            deleteFeedback = nil
        }

        WebDAVClient.shared.deleteBackup(filename: filename) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        self.deletingCloudFilename = nil
                        self.cloudBackups.removeAll { $0.filename == filename }
                        self.cloudPage = min(self.cloudPage, max(1, (self.cloudBackups.count + 4) / 5))
                        self.deleteFeedback = CloudDeleteFeedback(
                            isSuccess: true,
                            title: "云端备份删除成功",
                            filename: filename
                        )
                    }
                    self.scheduleDeleteFeedbackDismissal()
                case .failure(let error):
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        self.deletingCloudFilename = nil
                        self.deleteFeedback = CloudDeleteFeedback(
                            isSuccess: false,
                            title: "删除失败：\(error.localizedDescription)",
                            filename: filename
                        )
                    }
                    self.scheduleDeleteFeedbackDismissal()
                }
            }
        }
    }

    private func scheduleDeleteFeedbackDismissal() {
        guard let feedbackID = deleteFeedback?.id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard self.deleteFeedback?.id == feedbackID else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.deleteFeedback = nil
            }
        }
    }

    private func deleteOperationBanner(title: String, filename: String, color: Color, iconName: String = "trash", showsProgress: Bool) -> some View {
        HStack(spacing: 10) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(color)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .bold()
                    .foregroundColor(color)
                Text(filename)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
        .padding(.bottom, 4)
    }
    
    private func executeRename() {
        var cleanNewName = newFilenameToRename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNewName.isEmpty else {
            renameError = "文件名不能为空"
            return
        }
        
        if !cleanNewName.hasSuffix(".json") {
            cleanNewName += ".json"
        }
        
        if cleanNewName == oldFilenameToRename {
            showingRenamePrompt = false
            return
        }
        
        isRenaming = true
        renameError = ""
        
        WebDAVClient.shared.renameBackup(oldFilename: oldFilenameToRename, newFilename: cleanNewName) { result in
            DispatchQueue.main.async {
                self.isRenaming = false
                switch result {
                case .success:
                    self.showingRenamePrompt = false
                    self.fetchCloudBackups()
                case .failure(let error):
                    self.renameError = "❌ 重命名失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func formatFileSizeWithTwoDecimals(_ size: Int64) -> String {
        let bytes = Double(size)
        let kb = bytes / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(size) Bytes"
        }
    }
}
