import SwiftUI

struct WalletSyncHistoryList: View {
    let entries: [SyncHistoryEntry]
    @Binding var selectedID: String?
    @FocusState private var focusedID: String?
    @State private var hoveredID: String?
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletAnimation) private var animation

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(entries) { entry in
                        let selected = entry.id == (selectedID ?? entries.first?.id)
                        Button {
                            selectedID = entry.id
                            focusedID = entry.id
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: entry.status == "success" ? "checkmark.circle" : "exclamationmark.circle")
                                    .foregroundStyle(entry.status == "success" ? palette.success : palette.warning)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.finishedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(selected ? palette.accent : Color.primary)
                                    Text("本机 \(entry.localChanges.count) 项 · 云端 \(entry.remoteChanges.count) 项")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(entry.status == "success" ? "同步完成" : "需要处理")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if selected {
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(palette.accent)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                            .background(selected ? palette.selection : palette.surface.opacity(hoveredID == entry.id ? 0.65 : 0.25), in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? palette.accent.opacity(0.35) : palette.line.opacity(0.5), lineWidth: 1))
                            .contentShape(RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                        .focusable().focusEffectDisabled().focused($focusedID, equals: entry.id)
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(focusedID == entry.id ? palette.accent.opacity(0.6) : .clear, lineWidth: 1).allowsHitTesting(false))
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                        .onHover { hoveredID = $0 ? entry.id : nil }
                        .animation(animation, value: selected)
                        .onKeyPress(.upArrow) { move(from: entry.id, offset: -1, proxy: proxy); return .handled }
                        .onKeyPress(.downArrow) { move(from: entry.id, offset: 1, proxy: proxy); return .handled }
                        .id(entry.id)
                    }
                }.padding(2)
            }
        }
    }

    private func move(from id: String, offset: Int, proxy: ScrollViewProxy) {
        guard let index = entries.firstIndex(where: { $0.id == id }), entries.indices.contains(index + offset) else { return }
        let id = entries[index + offset].id
        selectedID = id
        focusedID = id
        proxy.scrollTo(id, anchor: .center)
    }
}
