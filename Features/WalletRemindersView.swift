import SwiftUI

struct CardReminderView: View {
    let cards: [SharedCard]
    let onShowCard: (SharedCard) -> Void
    let onEditCard: (SharedCard) -> Void
    let onConfirmAnnualFees: (Set<String>) -> Void
    @Environment(\.walletPalette) private var palette
    @State private var items: [ReminderItem] = []
    @State private var filter = "all"
    @State private var confirming = false
    @State private var confirmingIDs: Set<String> = []

    private enum Kind: String, CaseIterable {
        case repayment = "还款"
        case bill = "账单"
        case annual = "年费"
        case expiry = "有效期"
        var title: LocalizedStringKey {
            switch self {
            case .repayment: return "还款日提醒"
            case .bill: return "账单日提醒"
            case .annual: return "年费管理"
            case .expiry: return "卡片有效期"
            }
        }
        var icon: String {
            switch self {
            case .repayment: return "calendar.badge.clock"
            case .bill: return "doc.text"
            case .annual: return "calendar.badge.exclamationmark"
            case .expiry: return "creditcard.trianglebadge.exclamationmark"
            }
        }
    }
    private struct ReminderItem: Identifiable {
        var id: String { kind.rawValue + card.id }
        let card: SharedCard
        let kind: Kind
        let detail: String
        let tag: String
        let days: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WalletPageHeader(title: "卡片提醒", subtitle: String(localized: "重要的日子，提前安排好。")) {
                Button("重新检查", action: refresh)
            }
            WalletChoiceBar(title: "提醒类型", selection: $filter,
                choices: [WalletChoice(value: "all", title: "全部")] + Kind.allCases.map { WalletChoice(value: $0.rawValue, title: LocalizedStringKey($0.rawValue)) })
            if items.filter({ filter == "all" || $0.kind.rawValue == filter }).isEmpty {
                ContentUnavailableView("暂无这类提醒", systemImage: "calendar.badge.checkmark", description: Text("根据已填写的卡片信息，暂时没有需要处理的事项。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(Kind.allCases, id: \.rawValue) { kind in
                            let group = items.filter { $0.kind == kind }
                            if !group.isEmpty && (filter == "all" || filter == kind.rawValue) {
                                VStack(alignment: .leading, spacing: 13) {
                                    HStack {
                                        Text(kind.title).font(.headline)
                                        Text("\(group.count) 项").font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        if kind == .annual {
                                            Button("全部确认达标") { confirmingIDs = Set(group.map { $0.card.id }); confirming = true }
                                                .buttonStyle(.borderless).font(.caption)
                                        }
                                    }
                                    ForEach(group) { item in reminderRow(item) }
                                }
                                .modifier(WalletSurface(padding: 18))
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .onAppear(perform: refresh)
        .onChange(of: cards) { _, _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refresh() }
        .alert("确认本周期年费已达标？", isPresented: $confirming) {
            Button("取消", role: .cancel) {}
            Button("确认已达标") { onConfirmAnnualFees(confirmingIDs) }
        } message: {
            Text("请确认这 \(confirmingIDs.count) 张卡片已满足银行的年费减免条件。确认后，年费日期会顺延一年。")
        }
    }

    private func reminderRow(_ item: ReminderItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.kind.icon).font(.system(size: 19))
                .foregroundStyle(item.kind == .annual || item.days < 0 ? palette.warning : palette.accent)
                .frame(width: 42, height: 44).background(palette.selection, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text("\(item.card.bank) · \(String(item.card.cardNumber.suffix(4)))").font(.system(size: 13, weight: .semibold))
                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                Text(item.tag).font(.caption2).foregroundStyle(item.days < 0 ? Color.red : palette.accent)
            }
            Spacer(minLength: 12)
            if item.kind == .annual {
                Button("确认达标") { confirmingIDs = [item.card.id]; confirming = true }
            } else if item.kind == .expiry {
                Button("更新有效期") { onEditCard(item.card) }
            } else {
                Button("查看卡片") { onShowCard(item.card) }
            }
        }
        .padding(.vertical, 7)
    }

    private func refresh() {
        var results = DateCalculator.billingCycleReminderItems(for: cards).map { item in
            ReminderItem(card: item.card, kind: item.reminder.kind == .repayment ? .repayment : .bill,
                         detail: item.reminder.kind == .repayment ? String(localized: "还款日 \(item.reminder.date.formatted(date: .numeric, time: .omitted))，请核对本期账单。") : String(localized: "账单日 \(item.reminder.date.formatted(date: .numeric, time: .omitted))，请留意出账。"),
                         tag: item.reminder.days == 0 ? String(localized: "今天") : String(localized: "还有 \(item.reminder.days) 天"), days: item.reminder.days)
        }
        for card in cards {
            if DateCalculator.annualFeeDetection(for: card) != nil {
                let days = DateCalculator.annualFeeRemainingDays(card.nextAnnualFeeCollectionTime) ?? 0
                results.append(ReminderItem(card: card, kind: .annual, detail: String(localized: "年费日期 \(WalletFormat.date(card.nextAnnualFeeCollectionTime)) · \(WalletFormat.amount(card.annualFee, currency: card.type))"), tag: days < 0 ? String(localized: "已超过 \(-days) 天") : String(localized: "还有 \(days) 天"), days: days))
            }
            if let status = DateCalculator.cardExpiryStatus(valid: card.valid), status != .normal {
                results.append(ReminderItem(card: card, kind: .expiry, detail: String(localized: "有效期 \(card.valid ?? "—")，请留意银行换卡安排。"), tag: status == .expired ? String(localized: "已到期") : String(localized: "即将到期"), days: status == .expired ? -1 : 0))
            }
        }
        items = results.sorted { $0.days == $1.days ? $0.id < $1.id : $0.days < $1.days }
    }
}
