import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator

    @State private var selectedAngle: Double? = nil
    @State private var selectedBrand: String? = nil

    private var cards: [SharedCard] { syncCoordinator.cards }
    private var creditCards: [SharedCard] { cards.filter { $0.cardCategory != "debit" } }
    private var debitCards: [SharedCard] { cards.filter { $0.cardCategory == "debit" } }

    private var totalLimitByCurrency: [String: Double] {
        Dictionary(uniqueKeysWithValues: WalletCardRules.creditLimits(cards).map {
            ($0.key.isEmpty ? "未设置" : $0.key, $0.value)
        })
    }

    private typealias BankLimit = (bank: String, limit: Double, currency: String)
    private typealias InterestFreeCard = (card: SharedCard, days: Int)

    // Keep aggregation outside ViewBuilder and give intermediate values concrete types.
    // This avoids an expensive nested tuple/Dictionary inference path in Swift 6.
    private var bankLimits: [BankLimit] {
        let grouped: [String: [SharedCard]] = Dictionary(grouping: creditCards) { card in
            BankNameNormalizer.normalizedKey(card.bank)
        }
        var rows: [BankLimit] = []
        for (bank, bankCards) in grouped {
            let limits: [String: Double] = WalletCardRules.creditLimits(bankCards)
            for (code, amount) in limits {
                let currencyLabel = code.isEmpty ? "未设置" : code
                rows.append((bank: "\(bank) (\(currencyLabel))", limit: amount, currency: code))
            }
        }
        rows.sort { left, right in
            if left.limit != right.limit { return left.limit > right.limit }
            return left.bank < right.bank
        }
        return rows
    }

    private var bestUsageCards: [InterestFreeCard] {
        var rows: [InterestFreeCard] = []
        let today = Date()
        for card in creditCards {
            let days = WalletCardRules.interestFreeDays(card, today: today)
            if days >= 0 { rows.append((card: card, days: days)) }
        }
        rows.sort { left, right in
            if left.days != right.days { return left.days > right.days }
            return left.card.id < right.card.id
        }
        return Array(rows.prefix(5))
    }

    private var annualFeeAlertCards: [SharedCard] {
        creditCards.filter { card in
            guard let result = DateCalculator.annualFeeDetection(for: card) else { return false }
            return result.kind == .unqualified || result.kind == .warning || result.kind == .overdue
        }.sorted { a, b in
            let da = DateCalculator.annualFeeRemainingDays(a.nextAnnualFeeCollectionTime) ?? Int.max
            let db = DateCalculator.annualFeeRemainingDays(b.nextAnnualFeeCollectionTime) ?? Int.max
            return da < db
        }
    }

    private var brandDistribution: [(brand: String, count: Int)] {
        var counts: [String: Int] = [:]
        for card in creditCards {
            let brand = CardBrand.detect(from: card.cardNumber, level: card.level).displayName
            counts[brand, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map { (brand: $0.key, count: $0.value) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 总览统计卡片
                overviewSection
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 年费预警
                if !annualFeeAlertCards.isEmpty {
                    annualFeeAlertSection
                        .padding(.horizontal, 16)
                }

                // 总额度展示
                totalLimitSection
                    .padding(.horizontal, 16)

                // 银行额度分布
                if !bankLimits.isEmpty {
                    bankLimitChartSection
                        .padding(.horizontal, 16)
                }

                // 卡组织分布
                if !brandDistribution.isEmpty {
                    brandDistributionSection
                        .padding(.horizontal, 16)
                }

                // 最优用卡建议
                bestUsageSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("统计分析")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - 总览
    private var overviewSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "全部", value: "\(cards.count)", subtitle: "张卡片", color: .cyan, icon: "wallet.bifold.fill")
            statCard(title: "信用卡", value: "\(creditCards.count)", subtitle: "张", color: .blue, icon: "creditcard.fill")
            statCard(title: "储蓄卡", value: "\(debitCards.count)", subtitle: "张", color: Color(hex: "#FFD700"), icon: "banknote.fill")

            NavigationLink(destination: StatDetailListView(type: .bank, cards: cards)) {
                statCard(title: "发卡行", value: "\(Set(cards.map { $0.bank }).count)", subtitle: "家", color: .purple, icon: "building.columns.fill")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: StatDetailListView(type: .country, cards: cards)) {
                statCard(title: "发卡国", value: "\(Set(cards.map { $0.country }).count)", subtitle: "个", color: .green, icon: "globe")
            }
            .buttonStyle(.plain)

            let expiryStats = DateCalculator.cardExpiryStats(for: cards)
            NavigationLink(destination: StatDetailListView(type: .expiry, cards: cards)) {
                statCard(
                    title: "即将到期",
                    value: "\(expiryStats.soonExpiring + expiryStats.expiredCards)",
                    subtitle: "张",
                    color: expiryStats.soonExpiring + expiryStats.expiredCards > 0 ? .red : .secondary,
                    icon: "exclamationmark.triangle.fill"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func statCard(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(title + " " + subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 年费预警
    private var annualFeeAlertSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("年费预警", icon: "exclamationmark.triangle.fill", color: .orange)
            VStack(spacing: 0) {
                ForEach(Array(annualFeeAlertCards.prefix(5).enumerated()), id: \.element.id) { index, card in
                    if index > 0 { Divider().padding(.leading, 16) }
                    if let result = DateCalculator.annualFeeDetection(for: card) {
                        annualFeeAlertRow(card: card, result: result)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func annualFeeAlertRow(card: SharedCard, result: DateCalculator.AnnualFeeDetectionResult) -> some View {
        HStack(spacing: 12) {
            let (color, icon): (Color, String) = {
                switch result.kind {
                case .unqualified: return (.orange, "exclamationmark.circle.fill")
                case .warning:     return (.yellow, "clock.badge.exclamationmark.fill")
                case .overdue:     return (.red, "xmark.circle.fill")
                }
            }()
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(card.bank)
                    .font(.system(.subheadline, weight: .semibold))
                Text(card.alias ?? (card.level ?? ""))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            let label: String = {
                switch result.kind {
                case .unqualified: return "未达标 \(result.days)天后收费"
                case .warning:     return "\(result.days)天后收费"
                case .overdue:     return "已逾期\(result.days)天"
                }
            }()
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 总额度
    private var totalLimitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("总授信额度", icon: "banknote.fill", color: .cyan)
            VStack(spacing: 0) {
                ForEach(Array(totalLimitByCurrency.sorted { c1, c2 in
                    if c1.key == "CNY" { return true }
                    if c2.key == "CNY" { return false }
                    if c1.key == "USD" { return true }
                    if c2.key == "USD" { return false }
                    return c1.key < c2.key
                }.enumerated()), id: \.element.key) { index, pair in
                    if index > 0 { Divider().padding(.leading, 16) }
                    HStack {
                        Text(pair.key)
                            .font(.system(.body, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatCurrency(pair.value, currency: pair.key))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 银行额度图表
    private var bankLimitChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("各行额度分布", icon: "chart.bar.fill", color: .blue)
            let topBanks = Array(bankLimits.prefix(8))
            Chart(topBanks, id: \.bank) { item in
                BarMark(
                    x: .value("额度", item.limit),
                    y: .value("银行", item.bank)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v >= 10000 ? "\(Int(v/10000))万" : "\(Int(v))")
                                .font(.system(size: 10))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(height: CGFloat(topBanks.count * 38 + 40))
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 卡组织分布
    private var brandDistributionSection: some View {
        let colors: [Color] = [.cyan, .blue, .purple, .orange, .red, Color(hex: "#FFD700"), .green]
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("卡组织分布", icon: "chart.pie.fill", color: .purple)
            Chart(brandDistribution, id: \.brand) { item in
                SectorMark(
                    angle: .value("数量", item.count),
                    innerRadius: .ratio(selectedBrand == item.brand ? 0.45 : 0.55),
                    outerRadius: .ratio(selectedBrand == item.brand ? 1.05 : 1.0),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("品牌", item.brand))
                .cornerRadius(4)
                .opacity(selectedBrand == nil || selectedBrand == item.brand ? 1.0 : 0.6)
            }
            .chartForegroundStyleScale(range: colors)
            .chartAngleSelection(value: $selectedAngle)
            .chartLegend(.hidden)
            .frame(height: 200)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .onChange(of: selectedAngle) { _, newValue in
                updateSelectedBrand(from: newValue)
            }

            // 图例
            FlowLayout(spacing: 8) {
                ForEach(Array(brandDistribution.enumerated()), id: \.element.brand) { index, item in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            if selectedBrand == item.brand {
                                selectedBrand = nil
                            } else {
                                selectedBrand = item.brand
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colors[index % colors.count])
                                .frame(width: 8, height: 8)
                            Text("\(item.brand)(\(item.count))")
                                .font(.system(size: 11, weight: selectedBrand == item.brand ? .bold : .regular))
                                .foregroundColor(selectedBrand == item.brand ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 最优用卡建议
    private var bestUsageSection: some View {
        let bestCards = bestUsageCards
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("免息期最优用卡", icon: "trophy.fill", color: Color(hex: "#FFD700"))

            if bestCards.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "info.circle").foregroundColor(.secondary)
                        Text("请在卡片中填写账单日和还款日以获取建议")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(bestCards.enumerated()), id: \.element.card.id) { index, item in
                        if index > 0 { Divider().padding(.leading, 16) }
                        bestUsageRow(index: index, item: item)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func bestUsageRow(index: Int, item: InterestFreeCard) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(index == 0 ? Color(hex: "#FFD700").opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 32, height: 32)
                Text("\(index + 1)")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundColor(index == 0 ? Color(hex: "#FFD700") : .secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.card.bank)
                    .font(.system(.subheadline, weight: .semibold))
                Text(item.card.alias ?? (item.card.level ?? ""))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("最长 \(item.days) 天")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.cyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let amountString = formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"

        guard currency != "未设置" else {
            return amountString
        }
        let symbol: String
        switch currency {
        case "CNY", "CNH": symbol = "¥"
        case "USD": symbol = "$"
        case "HKD": symbol = "HK$"
        case "EUR": symbol = "€"
        case "JPY": symbol = "JP¥"
        case "GBP": symbol = "£"
        default: symbol = "\(currency) "
        }
        return "\(symbol)\(amountString)"
    }

    private func normalizedCurrency(_ value: String?) -> String {
        let currency = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return currency.isEmpty ? "未设置" : currency
    }

    private func updateSelectedBrand(from angle: Double?) {
        guard let angle = angle else {
            selectedBrand = nil
            return
        }
        let total = brandDistribution.reduce(0) { $0 + $1.count }
        guard total > 0 else { return }

        var currentSum = 0
        for item in brandDistribution {
            let nextSum = currentSum + item.count
            if angle >= Double(currentSum) && angle < Double(nextSum) {
                withAnimation(.spring(duration: 0.3)) {
                    selectedBrand = item.brand
                }
                return
            }
            currentSum = nextSum
        }
    }
}

// MARK: - FlowLayout（简单流式布局）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 300
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentY += lineHeight + spacing
                currentX = 0
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentY += lineHeight + spacing
                currentX = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
