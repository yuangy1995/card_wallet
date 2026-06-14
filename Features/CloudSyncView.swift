import SwiftUI

public struct CloudSyncView: View {
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
    @State private var showingSyncHistory = false
    
    // 自动收敛与 iCloud 配置项
    @AppStorage("enable_icloud_sync") private var enableICloudSync = false
    @AppStorage("enable_webdav_bridge") private var enableWebDAVBridge = true
    @AppStorage("auto_check_interval") private var autoCheckInterval = 300.0
    
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
                    } else if let duration = bridgeService.lastSyncDurationSeconds {
                        Text("上次耗时：\(formatSyncDuration(duration))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button("立即同步一次") {
                            WebDAVBridgeService.shared.synchronize(forceUpload: true)
                        }
                        .disabled(!enableWebDAVBridge || bridgeService.isSyncing)

                        Button("同步记录与详情") {
                            showingSyncHistory = true
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .onAppear {
            loadSavedConfig()
        }
        .sheet(isPresented: $showingSyncHistory) {
            MacSyncHistorySheet(bridgeService: bridgeService)
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
}

private struct MacSyncHistorySheet: View {
    @ObservedObject var bridgeService: WebDAVBridgeService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                currentStatusCard

                if bridgeService.syncHistory.isEmpty {
                    ContentUnavailableView(
                        "暂无同步记录",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("完成一次 WebDAV 同步后，这里会显示耗时、读写文件和变更详情。")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(bridgeService.syncHistory) { entry in
                            DisclosureGroup {
                                historyDetail(entry)
                                    .padding(.vertical, 8)
                            } label: {
                                historyHeader(entry)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .padding(20)
            .frame(minWidth: 720, minHeight: 540)
            .navigationTitle("同步记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        WebDAVBridgeService.shared.synchronize(forceUpload: true)
                    } label: {
                        Label("重新执行同步", systemImage: "arrow.clockwise")
                    }
                    .disabled(bridgeService.isSyncing)
                }
            }
        }
    }

    private var currentStatusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: bridgeService.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.icloud.fill")
                .font(.system(size: 28))
                .foregroundColor(bridgeService.isSyncing ? .cyan : .green)
                .frame(width: 42, height: 42)
                .background((bridgeService.isSyncing ? Color.cyan : Color.green).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                Text(bridgeService.isSyncing ? "正在同步" : "同步空闲")
                    .font(.headline)
                Text(bridgeService.statusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if bridgeService.isSyncing, bridgeService.syncProgress.total > 0 {
                    ProgressView(
                        value: Double(bridgeService.syncProgress.step),
                        total: Double(bridgeService.syncProgress.total)
                    )
                    .frame(maxWidth: 360)
                }
            }

            Spacer()

            if bridgeService.isSyncing {
                Text("已用时 \(formatDuration(bridgeService.syncElapsedSeconds))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let duration = bridgeService.lastSyncDurationSeconds {
                Text("上次耗时 \(formatDuration(duration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func historyHeader(_ entry: SyncHistoryEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon(entry.status))
                .foregroundColor(statusColor(entry.status))
            VStack(alignment: .leading, spacing: 3) {
                Text(formatDateTime(entry.finishedAt))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(entry.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("本机 \(entry.localChanges.count) / 云端 \(entry.remoteChanges.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(formatDuration(entry.durationSeconds))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func historyDetail(_ entry: SyncHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            detailBlock("同步文件") {
                detailLine("上传", entry.uploadedFile?.isEmpty == false ? entry.uploadedFile! : "无")
                if entry.downloadedFiles.isEmpty {
                    detailLine("读取", "无，已跳过下载解析")
                } else {
                    ForEach(entry.downloadedFiles, id: \.self) { filename in
                        detailLine("读取", filename)
                    }
                }
            }

            changeBlock(title: "本机变更", changes: entry.localChanges)
            changeBlock(title: "云端变更", changes: entry.remoteChanges)
        }
    }

    private func detailBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 42, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    private func changeBlock(title: String, changes: [SyncCardChangeDetail]) -> some View {
        detailBlock(title) {
            if changes.isEmpty {
                Text("无")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(changes) { change in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(kindText(change.kind))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusColor(change.kind).opacity(0.16))
                                .foregroundColor(statusColor(change.kind))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            Text(change.cardName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        ForEach(change.fields.indices, id: \.self) { index in
                            let field = change.fields[index]
                            HStack(spacing: 8) {
                                Text(field.label)
                                    .foregroundColor(.secondary)
                                    .frame(width: 94, alignment: .leading)
                                Text(field.oldValue.isEmpty ? "空" : field.oldValue)
                                    .lineLimit(1)
                                Text("→")
                                    .foregroundColor(.secondary)
                                Text(field.newValue.isEmpty ? "空" : field.newValue)
                                    .foregroundColor(.cyan)
                                    .lineLimit(1)
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.top, 6)
                    Divider()
                        .opacity(0.45)
                }
            }
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "success":
            return "checkmark.circle.fill"
        case "warning":
            return "exclamationmark.triangle.fill"
        case "error", "danger":
            return "xmark.octagon.fill"
        default:
            return "info.circle.fill"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "success", "added":
            return .green
        case "warning":
            return .orange
        case "error", "danger", "deleted":
            return .red
        case "modified":
            return .cyan
        default:
            return .secondary
        }
    }

    private func kindText(_ kind: String) -> String {
        switch kind {
        case "added":
            return "新增"
        case "modified":
            return "修改"
        case "deleted":
            return "删除"
        default:
            return kind
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
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
}
