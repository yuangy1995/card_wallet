import SwiftUI
import UniformTypeIdentifiers

public struct StatisticsView: View {
    public let cards: [SharedCard]
    public var onShowCard: ((SharedCard) -> Void)?
    @Environment(\.walletPalette) private var palette
    @State private var snapshot = CardStatistics(cards: [])
    @State private var currency = "CNY"
    @State private var feeStatus = "2"
    @State private var exportFailed = false
    @State private var feeReviewExpanded = true
    @State private var limitReviewExpanded = false
    @State private var lowLimitReviewExpanded = false
    private let statuses = [("1", "已达标"), ("2", "待确认"), ("3", "终免年费")]

    public init(cards: [SharedCard], onShowCard: ((SharedCard) -> Void)? = nil) {
        self.cards = cards
        self.onShowCard = onShowCard
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 23) {
                WalletPageHeader(title: "卡片统计", subtitle: String(localized: "卡片与额度，一目了然。")) {
                    Button(action: exportReport) { Label("导出报告", systemImage: "square.and.arrow.up") }
                        .disabled(cards.isEmpty)
                }
                if cards.isEmpty {
                    ContentUnavailableView("还没有统计数据", systemImage: "chart.bar.xaxis", description: Text("添加卡片后，这里会显示额度与年费概况。"))
                } else {
                    overview
                    bankDistribution
                    feeOverview
                    cardComposition
                    reviewSections
                }
            }
            .padding(24)
        }
        .onAppear(perform: refresh)
        .onChange(of: cards) { _, _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refresh() }
        .alert("报告未能保存", isPresented: $exportFailed) { Button("好", role: .cancel) {} } message: {
            Text("请选择可写入的位置后重试。")
        }
    }

    private var overview: some View {
        HStack(alignment: .top, spacing: 15) {
            metric("全部卡片", value: String(localized: "\(cards.count) 张"), note: String(localized: "\(snapshot.creditCards.count) 张信用卡 · \(snapshot.debitCards.count) 张储蓄卡"))
            VStack(alignment: .leading, spacing: 10) {
                Text("信用额度").font(.caption).foregroundStyle(.secondary)
                ForEach(snapshot.currencies, id: \.self) { code in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(code).font(.caption).foregroundStyle(.secondary).frame(width: 30, alignment: .leading)
                        Text(WalletFormat.amount(snapshot.totalLimits[code], currency: code))
                            .font(.system(size: 22, weight: .medium)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                }
                if snapshot.currencies.isEmpty { Text("—").font(.title2) }
                Spacer(minLength: 4)
                Text("按币种分别统计，共享额度不重复计算").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).modifier(WalletSurface(padding: 17))
            metric("发卡银行", value: String(localized: "\(snapshot.bankCount) 家"), note: String(localized: "已填写的还款日分布在 \(snapshot.dueDates.count) 个日期"))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var bankDistribution: some View {
        let limits = snapshot.bankLimits.filter { $0.currency == currency }
        let maximum = limits.map(\.amount).max() ?? 1
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("银行信用额度").font(.headline)
                Spacer()
                Picker("币种", selection: $currency) { ForEach(snapshot.currencies, id: \.self) { Text($0.isEmpty ? String(localized: "未设置币种") : $0).tag($0) } }
                    .frame(width: 140)
            }
            if limits.isEmpty {
                Text("暂无已填写的信用额度。").foregroundStyle(.secondary)
            }
            ForEach(limits) { item in
                HStack(spacing: 16) {
                    Text(item.bank).font(.system(size: 12)).frame(width: 100, alignment: .leading).lineLimit(2)
                    GeometryReader { proxy in
                        Capsule().fill(palette.line)
                        Capsule().fill(palette.accent.opacity(0.8)).frame(width: proxy.size.width * CGFloat(item.amount / maximum))
                    }
                    .frame(height: 8).accessibilityHidden(true)
                    Text(WalletFormat.amount(item.amount, currency: currency)).font(.system(size: 12, weight: .medium)).monospacedDigit().frame(width: 120, alignment: .trailing)
                }
            }
            Text("同银行、地区和币种的共享额度按最高值计入；独立额度分别计入。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .modifier(WalletSurface(padding: 20))
    }

    private var feeOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("年费达标情况").font(.headline)
                Spacer()
                Text("仅统计信用卡").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                ForEach(statuses, id: \.0) { status in
                    Button { feeStatus = status.0 } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(LocalizedStringKey(status.1)).font(.caption)
                            Text("\(snapshot.cards(withFeeStatus: status.0).count) 张").font(.system(size: 23, weight: .medium)).monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .foregroundStyle(feeStatus == status.0 ? palette.accent : .primary)
                        .background(feeStatus == status.0 ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(feeStatus == status.0 ? [.isSelected] : [])
                }
            }
            Divider()
            let matchingCards = snapshot.cards(withFeeStatus: feeStatus)
            if matchingCards.isEmpty { Text("这个分类暂时没有卡片。").font(.caption).foregroundStyle(.secondary) }
            ForEach(matchingCards) { card in
                cardRow(card, detail: card.isQualified == "3" ? String(localized: "终免年费") : String(localized: "年费 \(WalletFormat.amount(card.annualFee, currency: card.type)) · 下次收取 \(WalletFormat.date(card.nextAnnualFeeCollectionTime))"))
            }
        }
        .modifier(WalletSurface(padding: 20))
    }

    private var cardComposition: some View {
        let brands = Dictionary(grouping: snapshot.creditCards) { CardBrand.detect(from: $0.cardNumber, level: $0.level).displayName }
        let expiry = DateCalculator.cardExpiryStats(for: cards)
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 15) {
                Text("信用卡组织").font(.headline)
                ForEach(brands.keys.sorted(), id: \.self) { name in
                    HStack { Text(name).font(.caption); Spacer(); Text("\(brands[name]?.count ?? 0) 张").monospacedDigit() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).modifier(WalletSurface(padding: 20))
            VStack(alignment: .leading, spacing: 15) {
                Text("卡片有效期").font(.headline)
                HStack { Text("已过期"); Spacer(); Text("\(expiry.expiredCards) 张").foregroundStyle(.red) }
                HStack { Text("即将到期"); Spacer(); Text("\(expiry.soonExpiring) 张").foregroundStyle(palette.warning) }
                HStack { Text("有效期正常"); Spacer(); Text("\(expiry.normalCards) 张") }
                Divider()
                Text("储蓄卡覆盖 \(snapshot.debitCountries) 个地区、\(snapshot.debitBanks) 家银行、\(snapshot.debitCurrencies) 种币种。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .font(.system(size: 12)).monospacedDigit()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).modifier(WalletSurface(padding: 20))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var reviewSections: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("年费与额度检查").font(.headline)
            Text("依据已填写的卡片信息整理，不代表银行的提额或销卡建议。")
                .font(.caption).foregroundStyle(.secondary)
            reviewPanel("年费待确认", subtitle: String(localized: "未来六十天内需要留意的年费"), icon: "calendar.badge.exclamationmark", count: snapshot.pendingFees.count, expanded: $feeReviewExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    if snapshot.pendingFees.isEmpty { Text("暂时没有需要留意的年费。").foregroundStyle(.secondary) }
                    ForEach(snapshot.pendingFees) { item in
                        cardRow(item.card, detail: String(localized: "\(item.days) 天后收取 · \(WalletFormat.amount(item.card.annualFee, currency: item.card.type))"))
                    }
                    let fees = snapshot.annualFees.filter { $0.value > 0 }.sorted { $0.key < $1.key }.map { WalletFormat.amount($0.value, currency: $0.key) }.joined(separator: " / ")
                    if !fees.isEmpty { Text("所有待确认卡片的年费合计：\(fees)").font(.caption).foregroundStyle(.secondary) }
                }.padding(.top, 12)
            }
            reviewPanel("提额记录", subtitle: String(localized: "距上次记录已满一百八十天"), icon: "clock.arrow.circlepath", count: snapshot.oldLimitUpdates.count, expanded: $limitReviewExpanded) {
                VStack(spacing: 12) {
                    if snapshot.oldLimitUpdates.isEmpty { Text("暂无符合条件的记录。").foregroundStyle(.secondary) }
                    ForEach(snapshot.oldLimitUpdates) { item in cardRow(item.card, detail: String(localized: "距上次提额 \(item.days) 天")) }
                }.padding(.top, 12)
            }
            reviewPanel("低额度卡片", subtitle: String(localized: "按已填写的额度筛选，未填写的不计入"), icon: "creditcard", count: snapshot.lowLimitCards.count, expanded: $lowLimitReviewExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("人民币低于 5,000 元、美元或欧元低于 800、港币低于 6,000、日元低于 100,000；其他币种按 5,000 筛选。未填写额度的卡片不计入。")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(snapshot.lowLimitCards) { card in cardRow(card, detail: WalletFormat.amount(card.limit, currency: card.type)) }
                    if snapshot.lowLimitCards.isEmpty { Text("暂无符合条件的卡片。").foregroundStyle(.secondary) }
                }.padding(.top, 12)
            }
        }
    }

    private func reviewPanel<Content: View>(_ title: LocalizedStringKey, subtitle: String, icon: String, count: Int, expanded: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { expanded.wrappedValue.toggle() } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 18)).foregroundStyle(palette.accent)
                        .frame(width: 38, height: 38).background(palette.selection, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title).font(.system(size: 14, weight: .semibold))
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 10)
                    Text("\(count) 张").font(.system(size: 13, weight: .medium)).monospacedDigit()
                        .foregroundStyle(palette.accent).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(palette.selection, in: Capsule())
                    Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(.secondary)
                }.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded.wrappedValue ? "已展开" : "已收起")
            if expanded.wrappedValue {
                Divider().padding(.top, 16)
                content().frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .modifier(WalletSurface(padding: 18))
    }

    private func metric(_ title: LocalizedStringKey, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 25, weight: .medium)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Text(note).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).modifier(WalletSurface(padding: 17))
    }
    private func cardRow(_ card: SharedCard, detail: String) -> some View {
        HStack(spacing: 14) {
            WalletBankLogo(bank: card.bank, country: card.country, width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("\(card.bank) · \(String(card.cardNumber.suffix(4)))").font(.system(size: 12, weight: .medium))
                if let alias = card.alias, !alias.isEmpty { Text(alias).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                .frame(maxWidth: 270, alignment: .trailing)
            if let onShowCard {
                Button { onShowCard(card) } label: { Label("查看", systemImage: "chevron.right").labelStyle(.titleAndIcon) }
                    .buttonStyle(.borderless).help("查看卡片").accessibilityLabel("查看卡片")
            }
        }
        .padding(12)
        .background(palette.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.line, lineWidth: 1))
    }
    private func refresh() {
        snapshot = CardStatistics(cards: cards)
        if !snapshot.currencies.contains(currency) { currency = snapshot.currencies.first ?? "CNY" }
    }
    private func exportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "卡片统计_\(Date().ISO8601Format().prefix(10)).csv"
        panel.begin { response in
            guard response == .OK, let url = panel.url, !AutoLockManager.shared.isLocked else { return }
            var rows = [
                [String(localized: "全部卡片"), String(localized: "信用卡"), String(localized: "储蓄卡"), String(localized: "发卡银行")],
                ["\(snapshot.cards.count)", "\(snapshot.creditCards.count)", "\(snapshot.debitCards.count)", "\(snapshot.bankCount)"],
                [], [String(localized: "银行"), String(localized: "币种"), String(localized: "信用额度")]
            ]
            rows += snapshot.bankLimits.map { [$0.bank, $0.currency, String($0.amount)] }
            rows += [[], [String(localized: "年费状态"), String(localized: "卡片数量")]]
            rows += statuses.map { [NSLocalizedString($0.1, comment: ""), String(snapshot.cards(withFeeStatus: $0.0).count)] }
            rows += [[], [String(localized: "储蓄卡地区"), String(localized: "储蓄卡银行"), String(localized: "储蓄卡币种")], ["\(snapshot.debitCountries)", "\(snapshot.debitBanks)", "\(snapshot.debitCurrencies)"]]
            do { try ("\u{FEFF}" + rows.map(CardStatistics.csvRow).joined()).write(to: url, atomically: true, encoding: .utf8) }
            catch { exportFailed = true }
        }
    }
}
