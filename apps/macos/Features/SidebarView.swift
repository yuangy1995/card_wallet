import SwiftUI

public enum NavigationSection: Hashable {
    case allCards, annualFeeAlert, bestUsage, statistics, cardCheck, sync, settings
}

public struct SidebarView: View {
    @Binding public var selection: NavigationSection?
    @Binding public var selectedBank: String
    public let cards: [SharedCard]
    public let hasPassword: Bool
    public let onLock: () -> Void
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletAnimation) private var animation
    @State private var reminderCount = 0
    @State private var banks: [BankShortcut] = []

    public init(selection: Binding<NavigationSection?>, selectedBank: Binding<String>, cards: [SharedCard], hasPassword: Bool, onLock: @escaping () -> Void) {
        _selection = selection
        _selectedBank = selectedBank
        self.cards = cards
        self.hasPassword = hasPassword
        self.onLock = onLock
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("WalletLogo").resizable().scaledToFit().frame(width: 38, height: 38)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("卡包").font(.system(size: 20, weight: .semibold))
                    Text("卡片整理助手").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    item("全部卡片", icon: "rectangle.stack", section: .allCards, count: cards.count)
                    item("卡片提醒", icon: "calendar.badge.clock", section: .annualFeeAlert, count: reminderCount)
                    item("优惠用卡", icon: "sparkles", section: .bestUsage)
                    Text("管理").font(.caption2).foregroundStyle(.secondary).padding(.leading, 10).padding(.top, 19).padding(.bottom, 6)
                    item("卡片统计", icon: "chart.bar.xaxis", section: .statistics)
                    item("检查卡片", icon: "checkmark.shield", section: .cardCheck)
                    item("设置", icon: "slider.horizontal.3", section: .settings)

                    if !banks.isEmpty {
                        Divider().padding(.vertical, 14)
                        Text("按银行").font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.bottom, 4)
                        ForEach(banks) { bank in
                            Button {
                                withAnimation(animation) {
                                    selectedBank = selectedBank == bank.name ? "" : bank.name
                                    selection = .allCards
                                }
                            } label: {
                                HStack(spacing: 9) {
                                    WalletBankLogo(bank: bank.name, width: 18, height: 18).accessibilityHidden(true)
                                    Text(bank.name).lineLimit(1)
                                    Spacer(minLength: 3)
                                    Text(bank.count.formatted()).font(.caption2).monospacedDigit()
                                }
                                .font(.system(size: 12))
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .foregroundStyle(selectedBank == bank.name ? palette.accent : Color.secondary)
                                .background(selectedBank == bank.name ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("筛选银行：\(bank.name)"))
                        }
                    }
                }
                .padding(.horizontal, 10)
            }

            VStack(spacing: 10) {
                Button { selection = .sync } label: { WalletSidebarSyncStatus() }
                    .buttonStyle(.plain)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(selection == .sync ? palette.accent.opacity(0.5) : .clear, lineWidth: 1))
                    .accessibilityAddTraits(selection == .sync ? [.isSelected] : [])
                HStack {
                    Label("本机卡片已加密", systemImage: "shield.lefthalf.filled").font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if hasPassword {
                        Button(action: onLock) { Image(systemName: "lock") }
                            .buttonStyle(.plain).help("锁定卡包").accessibilityLabel("锁定卡包")
                    }
                    Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }
                        .buttonStyle(.plain).help("退出卡包").accessibilityLabel("退出卡包")
                }
            }
            .padding(13)
        }
        .modifier(WalletGlass())
        .navigationSplitViewColumnWidth(min: 180, ideal: 196, max: 240)
        .onAppear(perform: refresh)
        .onChange(of: cards) { _, _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refresh() }
    }

    private func item(_ title: LocalizedStringKey, icon: String, section: NavigationSection, count: Int = 0) -> some View {
        Button {
            withAnimation(animation) {
                if section == .allCards { selectedBank = "" }
                selection = section
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 17).accessibilityHidden(true)
                Text(title)
                Spacer(minLength: 2)
                if count > 0 { Text(count.formatted()).font(.caption2).monospacedDigit() }
            }
            .font(.system(size: 13, weight: selection == section ? .semibold : .regular))
            .foregroundStyle(selection == section ? palette.accent : Color.secondary)
            .padding(.horizontal, 11).frame(minHeight: 38)
            .background(selection == section ? palette.surface.opacity(0.92) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selection == section ? palette.edge : .clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == section ? [.isSelected] : [])
    }

    private func refresh() {
        let groups = Dictionary(grouping: cards) { BankNameNormalizer.normalizedKey($0.bank) }
        banks = groups.filter { !$0.key.isEmpty }.map { BankShortcut(name: BankNameNormalizer.groupDisplayName($0.value.map(\.bank)), count: $0.value.count) }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        reminderCount = DateCalculator.billingCycleReminderItems(for: cards).count
            + cards.filter { DateCalculator.annualFeeDetection(for: $0) != nil }.count
            + cards.filter { let state = DateCalculator.cardExpiryStatus(valid: $0.valid); return state == .expired || state == .soonExpiring }.count
    }

    private struct BankShortcut: Identifiable {
        var id: String { name }
        let name: String
        let count: Int
    }
}

private struct WalletSidebarSyncStatus: View {
    @ObservedObject private var bridge = WebDAVBridgeService.shared
    @Environment(\.walletPalette) private var palette
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: bridge.isSyncing ? "arrow.triangle.2.circlepath" : "icloud")
                .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("云端同步").font(.system(size: 12, weight: .medium))
                Text(bridge.isSyncing ? "正在同步" : "查看状态与记录").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .modifier(WalletSurface(padding: 10))
    }
}
