import SwiftUI

struct CloudSyncView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator

    @State private var webdavUrl = ""
    @State private var webdavUsername = ""
    @State private var webdavPassword = ""
    @State private var webdavSyncPassword = ""
    @State private var isTestingConnection = false
    @State private var connectionMessage = ""
    @State private var connectionSuccess = false
    @State private var hasSavedWebDAVPassword = false
    @State private var hasSavedSyncPassword = false
    @State private var showSyncHistory = false
    @State private var isEditingConfig = false

    @AppStorage("enable_webdav_sync") private var enableWebDAVSync = false
    @AppStorage("auto_sync_interval") private var autoSyncInterval = 300.0

    var body: some View {
        Form {
            webdavSection

            if enableWebDAVSync && savedConfigReady {
                manualSyncSection
            }
        }
        .navigationTitle("云端同步")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationDestination(isPresented: $showSyncHistory) {
            SyncHistoryView()
        }
        .onAppear { loadConfig() }
        .onChange(of: enableWebDAVSync) { _, enabled in
            if enabled && !savedConfigReady {
                enableWebDAVSync = false
                syncCoordinator.setWebDAVEnabled(false)
                return
            }
            syncCoordinator.setWebDAVEnabled(enabled)
        }
    }

    // MARK: - WebDAV 配置
    private var webdavSection: some View {
        Section {
            if savedConfigReady && !isEditingConfig {
                connectedConfigSummary
            } else {
                if savedConfigReady {
                    editingConfigHeader
                }
                configForm
                configActionButtons
            }

            if savedConfigReady {
                Toggle("启用自动同步", isOn: $enableWebDAVSync)
                    .font(.system(.subheadline))
            }
        } header: {
            Label("WebDAV 同步配置", systemImage: "icloud.and.arrow.up.fill")
        }
    }

    private var connectedConfigSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 50, height: 50)
                    Image(systemName: "checkmark.icloud.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.green)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("加密云同步已就绪")
                            .font(.system(.subheadline, weight: .semibold))
                        Text("已连接")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }
                    Text(cleanWebDAVURL)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack {
                Label(cleanUsername, systemImage: "person.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    connectionMessage = ""
                    isEditingConfig = true
                } label: {
                    Label("修改配置", systemImage: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private var editingConfigHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("正在修改同步配置")
                    .font(.system(.subheadline, weight: .semibold))
                Text("留空密码会保留已保存的 WebDAV 密码。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("取消") {
                loadConfig()
                isEditingConfig = false
                connectionMessage = ""
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .padding(.vertical, 4)
    }

    private var configForm: some View {
        Group {
            HStack {
                Label("服务器地址", systemImage: "server.rack")
                Spacer()
                TextField("https://your-webdav.com/", text: $webdavUrl)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 220)
            }
            HStack {
                Label("用户名", systemImage: "person.fill")
                Spacer()
                TextField("用户名", text: $webdavUsername)
                    .autocapitalization(.none)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 220)
            }
            HStack {
                Label("密码", systemImage: "lock.fill")
                Spacer()
                SecureField(hasSavedWebDAVPassword ? "留空则保留已保存密码" : "密码", text: $webdavPassword)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 220)
            }
            HStack {
                Label("同步密钥", systemImage: "key.fill")
                Spacer()
                SecureField("用于加密同步文件", text: $webdavSyncPassword)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 220)
            }

            if !connectionMessage.isEmpty {
                Label(connectionMessage, systemImage: connectionSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(connectionSuccess ? .green : .red)
            }
        }
    }

    private var configActionButtons: some View {
        HStack(spacing: 12) {
            Button {
                testConnection()
            } label: {
                if isTestingConnection {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("测试连接").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(!canTestConnection)

            Button("保存配置") {
                saveConfig()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSaveConfig)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 手动同步
    private var manualSyncSection: some View {
        Section {
            Button {
                guard !syncCoordinator.isSynchronizing else { return }
                Task {
                    await syncCoordinator.synchronize(forceUpload: true)
                }
            } label: {
                HStack {
                    Label(syncCoordinator.isSynchronizing ? "正在同步" : "立即同步", systemImage: "arrow.triangle.2.circlepath.icloud.fill")
                    Spacer()
                    if syncCoordinator.isSynchronizing {
                        ProgressView()
                    } else {
                        Image(systemName: syncCoordinator.syncStatus.iconName)
                            .foregroundColor(syncStatusColor)
                    }
                }
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

            HStack {
                Text("上次同步")
                    .foregroundColor(.secondary)
                Spacer()
                if syncCoordinator.isSynchronizing {
                    Text("正在同步 \(formatDuration(syncCoordinator.syncElapsedSeconds))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else if let lastSync = syncCoordinator.lastSyncAt {
                    Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else if !syncCoordinator.cards.isEmpty {
                    Text("本机已有数据，尚未完成云端同步")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    Text("未同步过").foregroundColor(.secondary).font(.system(size: 13))
                }
            }
            if let duration = syncCoordinator.lastSyncDurationSeconds {
                HStack {
                    Text("上次耗时")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDuration(duration))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("同步操作", systemImage: "arrow.triangle.2.circlepath")
        }
    }

    // MARK: - Helpers
    private var syncStatusColor: Color {
        switch syncCoordinator.syncStatus {
        case .idle:    return .secondary
        case .syncing: return .blue
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        }
    }

    private var cleanWebDAVURL: String {
        var cleanURL = webdavUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.isEmpty, !cleanURL.hasSuffix("/") { cleanURL += "/" }
        return cleanURL
    }

    private var cleanUsername: String {
        webdavUsername.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanWebDAVPassword: String {
        webdavPassword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanSyncPassword: String {
        webdavSyncPassword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canTestConnection: Bool {
        !cleanWebDAVURL.isEmpty && !cleanUsername.isEmpty && (hasSavedWebDAVPassword || !cleanWebDAVPassword.isEmpty)
    }

    private var canSaveConfig: Bool {
        canTestConnection && !cleanSyncPassword.isEmpty
    }

    private var savedConfigReady: Bool {
        !cleanWebDAVURL.isEmpty && !cleanUsername.isEmpty && hasSavedWebDAVPassword && hasSavedSyncPassword
    }

    private func loadConfig() {
        webdavUrl = UserDefaults.standard.string(forKey: "webdav_url") ?? ""
        webdavUsername = KeychainManager.load(key: "webdav_username") ?? ""
        hasSavedWebDAVPassword = !(KeychainManager.load(key: "webdav_password") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let savedSyncPassword = KeychainManager.load(key: "webdav_sync_password_v4") ?? ""
        webdavSyncPassword = savedSyncPassword
        hasSavedSyncPassword = !savedSyncPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        connectionSuccess = savedConfigReady
        isEditingConfig = !savedConfigReady
        syncCoordinator.refreshWebDAVConfigurationState()
        if !savedConfigReady && enableWebDAVSync {
            enableWebDAVSync = false
            syncCoordinator.setWebDAVEnabled(false)
        }
    }

    private func saveConfig() {
        guard canSaveConfig else {
            connectionSuccess = false
            connectionMessage = "请完整填写 WebDAV 信息和同步密钥"
            return
        }

        switch WebDAVClient.shared.saveConfig(url: cleanWebDAVURL, username: cleanUsername, password: cleanWebDAVPassword) {
        case .success:
            break
        case .failure(let error):
            connectionSuccess = false
            connectionMessage = error.localizedDescription
            return
        }

        switch KeychainManager.save(key: "webdav_sync_password_v4", value: cleanSyncPassword) {
        case .success:
            break
        case .failure(let error):
            connectionSuccess = false
            connectionMessage = error.localizedDescription
            return
        }

        webdavUrl = cleanWebDAVURL
        webdavUsername = cleanUsername
        webdavSyncPassword = cleanSyncPassword
        hasSavedWebDAVPassword = true
        hasSavedSyncPassword = true
        syncCoordinator.refreshWebDAVConfigurationState()
        connectionSuccess = true
        connectionMessage = "配置已保存"
        isEditingConfig = false
        if enableWebDAVSync {
            Task { await syncCoordinator.synchronize(forceUpload: false) }
        }
    }

    private func testConnection() {
        guard canTestConnection else {
            connectionSuccess = false
            connectionMessage = "请先填写服务器、用户名和 WebDAV 密码"
            return
        }
        isTestingConnection = true
        connectionMessage = ""
        UserDefaults.standard.set(cleanWebDAVURL, forKey: "webdav_url")
        KeychainManager.save(key: "webdav_username", value: cleanUsername)
        if !cleanWebDAVPassword.isEmpty {
            KeychainManager.save(key: "webdav_password", value: cleanWebDAVPassword)
            hasSavedWebDAVPassword = true
        }
        webdavUrl = cleanWebDAVURL
        webdavUsername = cleanUsername
        WebDAVClient.shared.testConnection { result in
            Task { @MainActor in
                isTestingConnection = false
                switch result {
                case .success:
                    connectionSuccess = true
                    connectionMessage = savedConfigReady ? "连接成功" : "连接成功，请继续保存同步密钥"
                case .failure(let error):
                    connectionSuccess = false
                    connectionMessage = error.localizedDescription
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        if seconds >= 60 {
            return "\(seconds / 60)分\(seconds % 60)秒"
        }
        return "\(seconds)秒"
    }
}

struct SyncHistoryView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                currentProgressCard

                if syncCoordinator.syncHistory.isEmpty {
                    emptyHistory
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(syncCoordinator.syncHistory) { entry in
                            SyncHistoryEntryCard(entry: entry)
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("同步记录")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .toolbar {
            if syncCoordinator.isSynchronizing {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        syncCoordinator.cancelCurrentSync()
                    } label: {
                        Label("终止", systemImage: "stop.circle.fill")
                    }
                }
            }
        }
        .onAppear {
            syncCoordinator.refreshWebDAVConfigurationState()
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private var currentProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(statusColor.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: syncHistoryIconName)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .symbolEffect(.pulse, isActive: syncCoordinator.webDAVConfigReady && syncCoordinator.isSynchronizing)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(syncHistoryTitle)
                        .font(.system(.headline, weight: .semibold))
                    Text(syncHistoryDetail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if syncCoordinator.isSynchronizing, syncCoordinator.syncProgress.total > 0 {
                    Text("\(syncCoordinator.syncProgress.step)/\(syncCoordinator.syncProgress.total)")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if syncCoordinator.isSynchronizing {
                if syncCoordinator.syncProgress.total > 0 {
                    ProgressView(value: syncCoordinator.syncProgress.fraction)
                        .tint(.blue)
                } else {
                    ProgressView()
                        .tint(.blue)
                }
                HStack {
                    Text("已耗时 \(formatDuration(syncCoordinator.syncElapsedSeconds))")
                    Spacer()
                    if let downloaded = syncCoordinator.syncProgress.downloadedBytes,
                       let total = syncCoordinator.syncProgress.totalBytes,
                       total > 0 {
                        let prefix = syncCoordinator.syncProgress.step == 5 ? "已上传" : "已下载"
                        Text("\(prefix) \(formatBytes(downloaded)) / \(formatBytes(total))")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            } else if let duration = syncCoordinator.lastSyncDurationSeconds {
                Text("上次耗时 \(formatDuration(duration))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if syncCoordinator.isSynchronizing {
                    Button(role: .destructive) {
                        syncCoordinator.cancelCurrentSync()
                    } label: {
                        Label("终止当前同步", systemImage: "stop.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    Task { await syncCoordinator.synchronize(forceUpload: true) }
                } label: {
                    Label(syncHistoryActionTitle, systemImage: syncHistoryActionIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(syncCoordinator.isSynchronizing || !syncCoordinator.webDAVConfigReady)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private var emptyHistory: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("暂无同步记录")
                .font(.system(.headline, weight: .semibold))
            Text("执行一次同步后，这里会显示同步耗时、上传文件、读取文件和变更详情。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private var statusColor: Color {
        if !syncCoordinator.webDAVConfigReady {
            return .secondary
        }
        switch syncCoordinator.syncStatus {
        case .idle: return .secondary
        case .syncing: return .blue
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        }
    }

    private var syncHistoryIconName: String {
        syncCoordinator.webDAVConfigReady ? syncCoordinator.syncStatus.iconName : "icloud.slash"
    }

    private var syncHistoryTitle: String {
        if !syncCoordinator.webDAVConfigReady {
            return "未配置云端同步"
        }
        return syncCoordinator.isSynchronizing ? syncCoordinator.syncProgress.phase : syncCoordinator.syncStatus.displayText
    }

    private var syncHistoryDetail: String {
        if !syncCoordinator.webDAVConfigReady {
            return "请先在设置中完成 WebDAV 地址、账号、密码和同步密钥配置。"
        }
        return syncCoordinator.syncProgress.detail.isEmpty ? "WebDAV 云端同步" : syncCoordinator.syncProgress.detail
    }

    private var syncHistoryActionTitle: String {
        if !syncCoordinator.webDAVConfigReady {
            return "未配置云端同步"
        }
        return syncCoordinator.isSynchronizing ? "同步进行中" : "重新执行同步"
    }

    private var syncHistoryActionIcon: String {
        syncCoordinator.webDAVConfigReady ? "arrow.triangle.2.circlepath.icloud" : "icloud.slash"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        if seconds >= 60 {
            return "\(seconds / 60)分\(seconds % 60)秒"
        }
        return "\(seconds)秒"
    }
}

private struct SyncHistoryEntryCard: View {
    let entry: SyncHistoryEntry

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 14) {
                fileSection
                changeSection(title: "本机变更", changes: entry.localChanges)
                changeSection(title: "云端变更", changes: entry.remoteChanges)
            }
            .padding(.top, 12)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(formattedDate(entry.finishedAt))
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatDuration(entry.durationSeconds))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        SyncCountBadge(title: "本机", count: entry.localChanges.count, color: .blue)
                        SyncCountBadge(title: "云端", count: entry.remoteChanges.count, color: .green)
                        if entry.uploadedFile != nil {
                            SyncCountBadge(title: "上传", count: 1, color: .blue)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("同步文件")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 6) {
                if let uploadedFile = entry.uploadedFile {
                    fileRow(title: "上传", filename: uploadedFile, hasFile: true)
                } else {
                    fileRow(title: "上传", filename: "未上传文件", hasFile: false)
                }

                if entry.downloadedFiles.isEmpty {
                    fileRow(title: "读取", filename: "无读取文件", hasFile: false)
                } else {
                    ForEach(entry.downloadedFiles, id: \.self) { filename in
                        fileRow(title: "读取", filename: filename, hasFile: true)
                    }
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func changeSection(title: String, changes: [CardChangeDetail]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            if changes.isEmpty {
                HStack {
                    Text("无变更记录")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(changes) { change in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(change.kind)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(changeColor(for: change.kind), in: RoundedRectangle(cornerRadius: 4))
                            Text(change.cardName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                        }
                        ForEach(change.fields, id: \.self) { field in
                            HStack(alignment: .top, spacing: 8) {
                                Text(field.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 56, alignment: .leading)
                                Text(field.oldValue.isEmpty ? "—" : field.oldValue)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                                Text(field.newValue.isEmpty ? "—" : field.newValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fileRow(title: String, filename: String, hasFile: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(hasFile ? Color.blue : Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((hasFile ? Color.blue : Color.secondary).opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            
            Text(filename)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(hasFile ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }

    private func changeColor(for kind: String) -> Color {
        if kind.contains("新增") || kind.contains("Add") { return .green }
        if kind.contains("删除") || kind.contains("Delete") { return .red }
        return .blue
    }

    private var statusColor: Color {
        switch entry.status {
        case "success": return .green
        case "warning": return .orange
        default: return .red
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute().second())
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        if seconds >= 60 {
            return "\(seconds / 60)分\(seconds % 60)秒"
        }
        return "\(seconds)秒"
    }

}

private struct SyncCountBadge: View {
    var title: String
    var count: Int
    var color: Color

    var body: some View {
        Text("\(title) \(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}
