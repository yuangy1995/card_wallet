import SwiftUI

enum SoftColors {
    static let red = Color(red: 1.0, green: 57.0/255.0, blue: 60.0/255.0)
    static let blue = Color(red: 0.0, green: 198.0/255.0, blue: 246.0/255.0)
    static let orange = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let purple = Color(red: 0.62, green: 0.42, blue: 0.96)
    static let green = Color(red: 0.06, green: 0.73, blue: 0.50)
    static let cyan = Color(red: 0.0, green: 0.85, blue: 0.95)
}

enum AppVisualMetrics {
    static let pagePadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 20
    static let panelCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 10
}

enum BankVisualStyle {
    static func color(for bankName: String) -> Color {
        if bankName.contains("招商") { return .red }
        if bankName.contains("建设") { return .blue }
        if bankName.contains("中国") { return .red }
        if bankName.contains("工商") { return .red }
        if bankName.contains("农业") { return .green }
        if bankName.contains("交通") { return .blue }
        if bankName.contains("浦发") { return .blue }
        if bankName.contains("兴业") { return .blue }
        if bankName.contains("中信") { return .red }
        if bankName.contains("民生") { return .green }
        if bankName.contains("光大") { return .orange }
        if bankName.contains("广发") { return .red }
        if bankName.contains("平安") { return .orange }
        if bankName.contains("汇丰") { return .red }
        if bankName.contains("渣打") { return .blue }
        if bankName.contains("花旗") { return .blue }
        if bankName.contains("工银") { return .red }

        let hash = abs(bankName.hashValue)
        let colors: [Color] = [.cyan, .teal, .blue, .purple, .pink, .indigo]
        return colors[hash % colors.count]
    }
}

struct BankAvatar: View {
    let bankName: String
    var size: CGFloat = 26
    var fontSize: CGFloat = 11

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            BankVisualStyle.color(for: bankName),
                            BankVisualStyle.color(for: bankName).opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(String(bankName.prefix(1)))
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct AppSectionHeader<Trailing: View>: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(
        iconName: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.iconName = iconName
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconColor.opacity(0.13))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 16)
            trailing()
        }
        .padding(.horizontal, AppVisualMetrics.pagePadding)
        .padding(.top, AppVisualMetrics.pagePadding)
        .padding(.bottom, 16)
    }
}

extension AppSectionHeader where Trailing == EmptyView {
    init(iconName: String, iconColor: Color, title: String, subtitle: String? = nil) {
        self.init(iconName: iconName, iconColor: iconColor, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct AppEmptyState: View {
    let iconName: String
    let title: String
    let message: String
    var accentColor: Color = SoftColors.cyan
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 76, height: 76)
                Image(systemName: iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(0.85))
            }

            VStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: 420)
        .padding(28)
        .appPanel(cornerRadius: 20, tint: accentColor)
    }
}

struct AppStatusPill: View {
    let text: String
    let color: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.13))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

private struct AppPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func appPanel(
        cornerRadius: CGFloat = AppVisualMetrics.panelCornerRadius,
        tint: Color = SoftColors.cyan
    ) -> some View {
        modifier(AppPanelModifier(cornerRadius: cornerRadius, tint: tint))
    }
}
