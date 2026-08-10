import SwiftUI

enum ToolSubView: String, CaseIterable, Identifiable {
    case bestUsage = "优惠用卡"
    case dataQualityIssues = "数据异常检测"
    case statistics = "数据与统计分析"
    case syncDetail = "同步历史与详情"

    var id: String { rawValue }
}

struct ToolsCenterView: View {
    let cards: [SharedCard]
    @Binding var activeSubView: ToolSubView?
    let onEdit: (SharedCard) -> Void

    var body: some View {
        Group {
            if let subView = activeSubView {
                switch subView {
                case .bestUsage:
                    MacBestUsageView(
                        cards: cards,
                        onBack: goBack,
                        onEdit: onEdit
                    )
                case .dataQualityIssues:
                    DataQualityIssuesView(
                        cards: cards,
                        onBack: goBack,
                        onEditCard: onEdit
                    )
                case .statistics:
                    StatisticsToolDetailView(cards: cards, onBack: goBack)
                case .syncDetail:
                    SyncDetailView(onBack: goBack)
                }
            } else {
                ToolsMainMenuView(cards: cards) { subView in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeSubView = subView
                    }
                }
            }
        }
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeSubView = nil
        }
    }
}

private struct ToolsMainMenuView: View {
    let cards: [SharedCard]
    let onSelect: (ToolSubView) -> Void

    private var issues: [DateCalculator.DataQualityIssue] {
        DateCalculator.analyzeDataQuality(cards: cards)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSectionHeader(
                    iconName: "wrench.and.screwdriver.fill",
                    iconColor: SoftColors.cyan,
                    title: "工具",
                    subtitle: "数据管理与分析中心"
                )

                VStack(spacing: 16) {
                    ToolMenuButton(
                        iconName: "sparkles",
                        iconColor: SoftColors.purple,
                        title: "优惠用卡",
                        description: "根据今天的消费日期实时计算可用免息期，推荐当前首选信用卡",
                        badgeText: nil,
                        badgeColor: nil,
                        action: { onSelect(.bestUsage) }
                    )

                    ToolMenuButton(
                        iconName: "exclamationmark.triangle.fill",
                        iconColor: issues.isEmpty ? SoftColors.green : SoftColors.orange,
                        title: "数据异常检测",
                        description: "一键分析检测重复卡号、格式异常、不合法账单日/还款日等数据质量问题",
                        badgeText: issues.isEmpty ? "正常" : "\(issues.count) 项异常",
                        badgeColor: issues.isEmpty ? SoftColors.green : SoftColors.orange,
                        action: { onSelect(.dataQualityIssues) }
                    )

                    ToolMenuButton(
                        iconName: "chart.pie.fill",
                        iconColor: SoftColors.blue,
                        title: "数据与统计分析",
                        description: "以直观图表展示信用卡额度占比、银行分布，推荐下一次最佳提额卡片",
                        badgeText: nil,
                        badgeColor: nil,
                        action: { onSelect(.statistics) }
                    )

                    ToolMenuButton(
                        iconName: "clock.arrow.circlepath",
                        iconColor: SoftColors.purple,
                        title: "同步历史与详情",
                        description: "查看 WebDAV 云端同步的耗时、读写文件历史、本机/云端变更的卡片详情日志",
                        badgeText: nil,
                        badgeColor: nil,
                        action: { onSelect(.syncDetail) }
                    )
                }
                .padding(.horizontal, AppVisualMetrics.pagePadding)
                .padding(.bottom, AppVisualMetrics.pagePadding)
            }
            .frame(maxWidth: 800, alignment: .leading)
        }
    }
}

private struct MacBestUsageView: View {
    let cards: [SharedCard]
    let onBack: () -> Void
    let onEdit: (SharedCard) -> Void

    private var creditCards: [SharedCard] {
        cards.filter { $0.cardCategory != "debit" }
    }

    private var rankedCards: [(card: SharedCard, days: Int)] {
        creditCards
            .map { ($0, DateCalculator.calculateInterestFreeDays(card: $0)) }
            .filter { $0.1 >= 0 }
            .sorted { $0.1 > $1.1 }
    }

    private var invalidCards: [SharedCard] {
        creditCards.filter { DateCalculator.calculateInterestFreeDays(card: $0) < 0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                iconName: "sparkles",
                iconColor: SoftColors.purple,
                title: "优惠用卡",
                subtitle: "按今天实时计算每张信用卡的可用免息期"
            ) {
                HStack(spacing: 10) {
                    BackToToolsButton(action: onBack)
                    AppStatusPill(text: "实时计算", color: SoftColors.purple, systemImage: "calendar")
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("根据账单日、还款日及账单日消费归属规则，按当前日期计算每张卡的实际可用免息期。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if rankedCards.isEmpty {
                        AppEmptyState(
                            iconName: "creditcard.trianglebadge.exclamationmark",
                            title: "暂无可推荐的信用卡",
                            message: "请先为信用卡配置账单日和还款日，之后这里会自动给出优先推荐。",
                            accentColor: SoftColors.purple
                        )
                        .frame(maxWidth: .infinity, minHeight: 260)
                    } else {
                        ForEach(Array(rankedCards.enumerated()), id: \.element.card.id) { index, item in
                            HStack(spacing: 16) {
                                Text(rankText(index))
                                    .font(.title2)
                                    .frame(width: 44)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(displayName(item.card))
                                        .font(.headline)
                                    Text("账单日 \(item.card.accountBillDate ?? "-") 日 · 还款日 \(item.card.dueDate ?? "-") 日")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(spacing: 2) {
                                    Text("\(item.days)")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(index == 0 ? .orange : .cyan)
                                    Text("天免息期")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Button("配置") { onEdit(item.card) }
                                    .buttonStyle(.bordered)
                            }
                            .padding(16)
                            .background(index == 0 ? Color.orange.opacity(0.08) : Color.primary.opacity(0.035))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(index == 0 ? Color.orange.opacity(0.25) : Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }

                    if !invalidCards.isEmpty {
                        DisclosureGroup("\(invalidCards.count) 张信用卡尚未配置完整账单信息") {
                            VStack(spacing: 8) {
                                ForEach(invalidCards) { card in
                                    HStack {
                                        Text(displayName(card))
                                        Spacer()
                                        Button("去配置") { onEdit(card) }
                                            .buttonStyle(.link)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(14)
                        .appPanel(cornerRadius: 14, tint: SoftColors.purple)
                    }
                }
                .padding(24)
                .frame(maxWidth: 820)
            }
        }
    }

    private func displayName(_ card: SharedCard) -> String {
        [card.bank, card.alias ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func rankText(_ index: Int) -> String {
        switch index {
        case 0: return "#1"
        case 1: return "#2"
        case 2: return "#3"
        default: return "#\(index + 1)"
        }
    }
}

private struct DataQualityIssuesView: View {
    let cards: [SharedCard]
    let onBack: () -> Void
    let onEditCard: (SharedCard) -> Void

    private var issues: [DateCalculator.DataQualityIssue] {
        DateCalculator.analyzeDataQuality(cards: cards)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                iconName: "exclamationmark.triangle.fill",
                iconColor: issues.isEmpty ? SoftColors.green : SoftColors.orange,
                title: "数据异常检测",
                subtitle: "检查重复卡号、日期格式、账单日和还款日等数据质量问题"
            ) {
                HStack(spacing: 10) {
                    BackToToolsButton(action: onBack)
                    AppStatusPill(
                        text: issues.isEmpty ? "数据良好" : "\(issues.count) 项待处理",
                        color: issues.isEmpty ? SoftColors.green : SoftColors.orange,
                        systemImage: issues.isEmpty ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
                    )
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            if issues.isEmpty {
                VStack {
                    AppEmptyState(
                        iconName: "checkmark.shield.fill",
                        title: "非常好！未检测到任何数据异常",
                        message: "所有卡号、账单日、还款日、年费及有效期格式均处于健康状态。",
                        accentColor: SoftColors.green
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.01))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)], spacing: 16) {
                        ForEach(issues) { issue in
                            let associatedCard = findCard(for: issue.cardName)
                            DataIssueGridItem(
                                issue: issue,
                                card: associatedCard,
                                onAction: {
                                    if let card = associatedCard {
                                        onEditCard(card)
                                    }
                                }
                            )
                        }
                    }
                    .padding(24)
                }
                .background(Color.primary.opacity(0.005))
            }
        }
    }

    private func findCard(for cardName: String) -> SharedCard? {
        guard !cardName.isEmpty else { return nil }
        return cards.first { card in
            let bank = card.bank.trimmingCharacters(in: .whitespacesAndNewlines)
            let alias = (card.alias ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let name = "\(bank.isEmpty ? "未知银行" : bank) - \(alias.isEmpty ? "未命名卡片" : alias)"
            return name == cardName
        }
    }
}

private struct StatisticsToolDetailView: View {
    let cards: [SharedCard]
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                iconName: "chart.pie.fill",
                iconColor: SoftColors.blue,
                title: "数据与统计分析",
                subtitle: "查看额度结构、银行分布和提额建议"
            ) {
                BackToToolsButton(action: onBack)
            }

            Divider()
                .background(Color.white.opacity(0.1))

            StatisticsView(cards: cards)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct BackToToolsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                Text("返回工具")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .appPanel(cornerRadius: AppVisualMetrics.controlCornerRadius, tint: Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 工具箱高级卡片菜单项按钮

private struct ToolMenuButton: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let description: String
    let badgeText: String?
    let badgeColor: Color?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        if let bText = badgeText, let bColor = badgeColor {
                            Text(bText)
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(bColor.opacity(0.15))
                                .foregroundColor(bColor)
                                .cornerRadius(6)
                        }
                    }

                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            .padding(18)
            .appPanel(cornerRadius: 14, tint: isHovered ? iconColor : Color.secondary)
            .scaleEffect(isHovered ? 1.006 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hover
            }
        }
    }
}

// MARK: - 异常数据网格卡片

private struct DataIssueGridItem: View {
    let issue: DateCalculator.DataQualityIssue
    let card: SharedCard?
    let onAction: () -> Void

    @State private var isHovered = false

    private var severityColor: Color {
        switch issue.severity {
        case "严重":
            return SoftColors.red
        case "警告":
            return SoftColors.orange
        default:
            return SoftColors.cyan
        }
    }

    private var severityIcon: String {
        switch issue.severity {
        case "严重":
            return "xmark.octagon.fill"
        case "警告":
            return "exclamationmark.triangle.fill"
        default:
            return "info.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: severityIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(issue.severity)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(severityColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(severityColor.opacity(0.12))
                .cornerRadius(6)

                Spacer()

                if let card = card {
                    Text(card.cardCategory == "debit" ? "储蓄卡" : "信用卡")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)

                if let card = card {
                    Text("\(card.bank) · \(card.alias ?? "无别名")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.8))
                } else if !issue.cardName.isEmpty {
                    Text(issue.cardName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.8))
                }
            }

            Text(issue.detail)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if card != nil {
                Spacer(minLength: 0)

                HStack {
                    if let card = card {
                        Text("尾号 *\(card.cardNumber.suffix(4))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: onAction) {
                        HStack(spacing: 4) {
                            Text("去处理")
                            Image(systemName: "pencil")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(severityColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .appPanel(cornerRadius: 14, tint: isHovered ? severityColor : Color.secondary)
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hover
            }
        }
    }
}
