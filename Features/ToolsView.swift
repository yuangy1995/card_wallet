import SwiftUI

struct ToolsView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 16) {
                    // 自定义顶部标题行
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.7), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("工具")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)

                    // 同步记录
                    NavigationLink(value: ToolType.syncHistory) {
                        ToolCardView(
                            title: "同步记录",
                            subtitle: "查看与 WebDAV 云盘的数据同步记录",
                            iconName: "clock.arrow.circlepath",
                            iconColor: Color(hex: "#B8860B"),
                            iconBgColor: Color(hex: "#B8860B").opacity(0.12)
                        )
                    }
                    .buttonStyle(.plain)

                    // 优惠用卡
                    NavigationLink(value: ToolType.bestUsage) {
                        ToolCardView(
                            title: "优惠用卡",
                            subtitle: "实时计算卡片当前可用免息期，智能推荐今日消费首选卡片",
                            iconName: "sparkles",
                            iconColor: .purple,
                            iconBgColor: .purple.opacity(0.12)
                        )
                    }
                    .buttonStyle(.plain)

                    // 统计分析
                    NavigationLink(value: ToolType.statistics) {
                        ToolCardView(
                            title: "统计分析",
                            subtitle: "查看信用额度、储蓄卡币种、共享额度和年费预警",
                            iconName: "chart.bar.fill",
                            iconColor: .blue,
                            iconBgColor: .blue.opacity(0.12)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: ToolType.dataDiagnostics) {
                        ToolCardView(
                            title: "数据异常检测",
                            subtitle: "检查重复卡号、账单还款配置、有效期格式和共享额度一致性",
                            iconName: "exclamationmark.triangle.fill",
                            iconColor: .orange,
                            iconBgColor: .orange.opacity(0.12)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ToolType.self) { type in
                switch type {
                case .syncHistory:
                    SyncHistoryView()
                case .bestUsage:
                    BestUsageView()
                case .statistics:
                    StatisticsView()
                case .dataDiagnostics:
                    DataDiagnosticsView(cards: syncCoordinator.cards)
                }
            }
        }
    }
}

private enum ToolType: Hashable {
    case syncHistory
    case bestUsage
    case statistics
    case dataDiagnostics
}

private struct DataDiagnosticsView: View {
    let cards: [SharedCard]

    private var issues: [DateCalculator.DataQualityIssue] {
        DateCalculator.analyzeDataQuality(cards: cards)
    }

    var body: some View {
        List {
            if issues.isEmpty {
                ContentUnavailableView("未发现明显数据异常", systemImage: "checkmark.shield.fill")
            } else {
                Section {
                    ForEach(issues) { issue in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: iconName(for: issue.severity))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(color(for: issue.severity))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(issue.severity) · \(issue.title)")
                                    .font(.system(.body, weight: .semibold))
                                if !issue.cardName.isEmpty {
                                    Text(issue.cardName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                Text(issue.detail)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("共 \(issues.count) 项")
                }
            }
        }
        .navigationTitle("数据异常检测")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func color(for severity: String) -> Color {
        switch severity {
        case "严重": return .red
        case "警告": return .orange
        default: return .blue
        }
    }

    private func iconName(for severity: String) -> String {
        switch severity {
        case "严重": return "xmark.octagon.fill"
        case "警告": return "exclamationmark.triangle.fill"
        default: return "info.circle.fill"
        }
    }
}

private struct ToolCardView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let iconColor: Color
    let iconBgColor: Color

    var body: some View {
        HStack(spacing: 16) {
            // 左侧 Icon 容器
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconBgColor)
                    .frame(width: 46, height: 46)
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // 中间文本
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.body, weight: .bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // 右侧指示箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 2)
    }
}
