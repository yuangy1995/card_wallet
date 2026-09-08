import SwiftUI

struct MacBestUsageView: View {
    let cards: [SharedCard]
    let onEdit: (SharedCard) -> Void
    @Binding var date: Date
    @Environment(\.walletPalette) private var palette
    @State private var ranked: [UsageItem] = []
    @State private var incomplete: [SharedCard] = []
    private struct UsageItem: Identifiable {
        var id: String { card.id }
        let card: SharedCard
        let days: Int
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                WalletPageHeader(title: "优惠用卡", subtitle: String(localized: "选好消费日期，看清各张卡的免息时间。")) {}
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("计划消费日期").font(.system(size: 13, weight: .medium))
                        Text("根据账单日、还款日及消费归属计算。").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    DatePicker("计划消费日期", selection: $date, displayedComponents: .date).labelsHidden().frame(maxWidth: 170)
                    Button("今天") { date = Date() }
                }
                .modifier(WalletSurface())
                if ranked.isEmpty {
                    ContentUnavailableView("暂无可比较的信用卡", systemImage: "creditcard", description: Text("填写账单日和还款日后，即可比较免息时间。"))
                } else {
                    Text("按预计免息天数排列").font(.headline)
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 16) {
                            Text(String(index + 1)).font(.system(size: 17, weight: .medium)).monospacedDigit()
                                .frame(width: 35, height: 38).background(palette.selection, in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(item.card.bank) · \(String(item.card.cardNumber.suffix(4)))").font(.system(size: 14, weight: .semibold))
                                Text(item.card.alias ?? "").font(.caption).foregroundStyle(.secondary)
                                Text("账单日 \(item.card.accountBillDate ?? "—") 日 · 还款日 \(item.card.dueDate ?? "—") 日").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(spacing: 4) {
                                Text(item.days.formatted()).font(.system(size: 28, weight: .medium)).monospacedDigit().foregroundStyle(palette.accent)
                                Text("天免息期").font(.caption2).foregroundStyle(.secondary)
                            }
                            Button("调整日期") { onEdit(item.card) }
                        }
                        .modifier(WalletSurface(padding: 17))
                    }
                }
                if !incomplete.isEmpty {
                    DisclosureGroup("\(incomplete.count) 张信用卡需要完善账单信息") {
                        VStack(spacing: 13) {
                            ForEach(incomplete) { card in
                                HStack {
                                    Text("\(card.bank) · \(String(card.cardNumber.suffix(4)))")
                                    Spacer()
                                    Button("完善信息") { onEdit(card) }
                                }
                            }
                        }.padding(.top, 12)
                    }
                    .modifier(WalletSurface())
                }
                Text("仅按已填写的日期估算，实际账期与优惠请以银行为准。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .onAppear(perform: refresh)
        .onChange(of: cards) { _, _ in refresh() }
        .onChange(of: date) { _, _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            if Calendar.current.isDateInYesterday(date) { date = Date() } else { refresh() }
        }
    }
    private func refresh() {
        let items = cards.filter { $0.cardCategory != "debit" }.map { UsageItem(card: $0, days: DateCalculator.calculateInterestFreeDays(card: $0, today: date)) }
        ranked = items.filter { $0.days >= 0 }.sorted { $0.days == $1.days ? $0.id < $1.id : $0.days > $1.days }
        incomplete = items.filter { $0.days < 0 }.map(\.card)
    }
}
