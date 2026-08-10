import SwiftUI

// MARK: - 精美提醒看板条目卡片

struct ReminderDashboardItem: View {
    let card: SharedCard
    let title: String
    let detail: String
    let tag: String
    let themeColor: Color
    let actionLabel: String
    let onAction: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    BankAvatar(bankName: card.bank, size: 24, fontSize: 11)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(card.bank)
                            .font(.system(size: 13, weight: .semibold))
                        Text(card.alias ?? "未命名卡片")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(tag)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(themeColor.opacity(0.12))
                    .foregroundColor(themeColor)
                    .cornerRadius(6)
            }

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)

            Text(detail)
                .font(.system(size: 11.5))
                .foregroundColor(.primary.opacity(0.75))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("尾号 *\(card.cardNumber.suffix(4))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Text(actionLabel)
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .appPanel(cornerRadius: 14, tint: isHovered ? themeColor : Color.secondary)
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hover
            }
        }
    }
}
