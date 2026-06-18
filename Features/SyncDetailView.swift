import SwiftUI

public struct SyncDetailView: View {
    @ObservedObject private var bridgeService = WebDAVBridgeService.shared
    public var onBack: () -> Void

    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 顶部返回与标题栏
            HStack(spacing: 14) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("返回工具")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundColor(.purple)
                    Text("同步历史与详情")
                        .font(.title3)
                        .bold()
                }
                
                Spacer()
                
                // 重新执行同步按钮
                Button(action: {
                    WebDAVBridgeService.shared.synchronize(forceUpload: true)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("立即同步")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(bridgeService.isSyncing ? Color.secondary.opacity(0.1) : Color.cyan.opacity(0.12))
                    .foregroundColor(bridgeService.isSyncing ? .secondary : .cyan)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(bridgeService.isSyncing)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))

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

                    if let byteText = syncByteProgressText(bridgeService.syncProgress) {
                        Text(byteText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon(entry.status))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(statusColor(entry.status))
                    Text(formatDateTime(entry.finishedAt))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(entry.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 18)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("本机 \(entry.localChanges.count) / 云端 \(entry.remoteChanges.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatDuration(entry.durationSeconds))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, alignment: .trailing)
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
