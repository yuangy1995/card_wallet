import SwiftUI

public struct SyncDetailView: View {
    private let bridge = WebDAVBridgeService.shared
    public var onBack: () -> Void
    @State private var history: [SyncHistoryEntry] = []
    @State private var selectedID: String?
    @State private var historyFilter = "all"
    @Environment(\.walletPalette) private var palette

    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }

    private var filteredHistory: [SyncHistoryEntry] {
        history.filter { historyFilter == "all" || (historyFilter == "error" ? $0.status != "success" : $0.status == "success") }
    }
    private var selectedEntry: SyncHistoryEntry? {
        filteredHistory.first { $0.id == selectedID } ?? filteredHistory.first
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WalletPageHeader(title: "云端同步", subtitle: String(localized: "状态、进度和每次变更，都在这里。")) {
                Button(action: onBack) { Label("连接设置", systemImage: "slider.horizontal.3") }
            }
            Group {
                WebDAVStatusPanel(onConfigure: onBack) { selectedID = nil }
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("同步记录").font(.headline)
                            Spacer()
                            Picker("记录筛选", selection: $historyFilter) {
                                Text("全部").tag("all")
                                Text("成功").tag("success")
                                Text("需处理").tag("error")
                            }
                            .labelsHidden().frame(width: 95)
                        }
                        if filteredHistory.isEmpty {
                            ContentUnavailableView("暂无同步记录", systemImage: "clock.arrow.circlepath", description: Text("完成同步后，可以在这里查看结果。"))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            WalletSyncHistoryList(entries: filteredHistory, selectedID: $selectedID)
                        }
                    }
                    .frame(minWidth: 245, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    Group {
                        if let entry = selectedEntry { SyncHistoryDetail(entry: entry) }
                        else {
                            ContentUnavailableView("查看同步详情", systemImage: "doc.text.magnifyingglass", description: Text("选择一条记录，查看具体卡片变化。"))
                        }
                    }
                    .frame(minWidth: 290, maxWidth: .infinity, maxHeight: .infinity)
                    .modifier(WalletSurface(padding: 14))
                }
                Text("变更按本机与云端分别记录；显示的是已记录的卡片变化，不是文件数量。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .onReceive(bridge.$syncHistory) { entries in
            history = entries
            if !entries.contains(where: { $0.id == selectedID }) { selectedID = entries.first?.id }
        }
        .onChange(of: historyFilter) { _, _ in selectedID = filteredHistory.first?.id }
    }

}

private struct WebDAVStatusPanel: View {
    @ObservedObject private var bridge = WebDAVBridgeService.shared
    let onConfigure: () -> Void
    let onSync: () -> Void
    @Environment(\.walletPalette) private var palette
    private var state: WalletSyncState {
        .resolve(enabled: bridge.isEnabled, syncing: bridge.isSyncing, message: bridge.statusDescription, latestStatus: bridge.syncHistory.first?.status, lastSuccess: bridge.lastConvergenceAt)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: state.icon).font(.system(size: 24))
                    .foregroundStyle(state == .attention ? palette.warning : palette.accent)
                    .frame(width: 49, height: 49)
                    .background(palette.selection, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.title).font(.system(size: 20, weight: .semibold))
                    Text(state.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if state == .unconfigured || state == .disabled {
                    Button("连接设置", action: onConfigure).buttonStyle(.borderedProminent)
                } else {
                    Button {
                        KeychainManager.retryFailedReads()
                        onSync()
                        bridge.synchronize(forceUpload: true)
                    } label: { Label(bridge.isSyncing ? "同步中" : "立即同步", systemImage: "arrow.triangle.2.circlepath") }
                    .buttonStyle(.borderedProminent).disabled(bridge.isSyncing)
                }
            }
            if bridge.isSyncing {
                if bridge.syncProgress.total > 0 {
                    ProgressView(value: Double(bridge.syncProgress.step), total: Double(bridge.syncProgress.total))
                } else { ProgressView().controlSize(.small) }
                HStack {
                    Text(LocalizedStringKey(bridge.syncProgress.phase))
                    Spacer()
                    if let bytes = bridge.syncProgress.transferredBytes, let total = bridge.syncProgress.totalBytes, total > 0 {
                        Text("\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
                    }
                    Text("已用时 \(Int(bridge.syncElapsedSeconds)) 秒").monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary)
            } else if let date = bridge.lastConvergenceAt {
                Label("上次成功：\(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .modifier(WalletSurface(padding: 18))
    }
}

private struct SyncHistoryDetail: View {
    let entry: SyncHistoryEntry
    @Environment(\.walletPalette) private var palette
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text(entry.status == "success" ? "本次同步详情" : "这次同步需要处理")
                    .font(.system(size: 15, weight: .semibold))
                Text(entry.finishedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                if entry.status != "success" {
                    Label("同步没有正常完成", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(palette.warning)
                    Text(entry.message.contains("密钥") || entry.message.contains("解密") ? "无法读取云端卡片，请确认各设备使用相同的同步密钥。" : "请检查网络、云盘地址和读写权限后重试。本机卡片仍保留。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    WalletFieldValue(title: "上传备份", value: entry.uploadedFile == nil ? "0" : "1")
                    WalletFieldValue(title: "读取备份", value: entry.downloadedFiles.count.formatted())
                    WalletFieldValue(title: "耗时", value: String(localized: "\(Int(ceil(entry.durationSeconds))) 秒"))
                }
                Divider()
                changeGroup("本机变更", changes: entry.localChanges)
                changeGroup("云端变更", changes: entry.remoteChanges)
                DisclosureGroup("使用的备份文件") {
                    VStack(alignment: .leading, spacing: 9) {
                        if let uploaded = entry.uploadedFile { Text("上传：\(uploaded)") }
                        ForEach(entry.downloadedFiles, id: \.self) { file in Text("读取：\(file)") }
                        if entry.uploadedFile == nil && entry.downloadedFiles.isEmpty { Text("本次无需读写备份文件。") }
                    }
                    .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled).padding(.top, 8)
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(3)
        }
    }

    private func changeGroup(_ title: LocalizedStringKey, changes: [SyncCardChangeDetail]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(title).font(.system(size: 13, weight: .semibold)); Spacer(); Text("\(changes.count) 项").font(.caption).foregroundStyle(.secondary) }
            if changes.isEmpty {
                Text("没有记录到卡片变更。").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(changes) { change in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: change.kind == "deleted" ? "minus.circle" : change.kind == "added" ? "plus.circle" : "pencil.circle")
                                .foregroundStyle(change.kind == "deleted" ? Color.red : palette.accent)
                            Text(change.cardName.hasPrefix("已删除卡片") ? String(localized: "已删除的卡片") : change.cardName)
                                .font(.system(size: 12, weight: .medium))
                        }
                        ForEach(change.fields.indices, id: \.self) { index in
                            let field = change.fields[index]
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey(field.label)).foregroundStyle(.secondary)
                                Text("\(WalletSyncState.safeValue(label: field.label, value: field.oldValue)) → \(WalletSyncState.safeValue(label: field.label, value: field.newValue))")
                                    .textSelection(.enabled)
                            }
                            .font(.caption).padding(.leading, 24)
                        }
                    }
                    Divider()
                }
                if changes.count == 30 { Text("本次显示前三十项变更。").font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }
}
