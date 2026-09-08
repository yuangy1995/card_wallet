import SwiftUI

struct WalletChoice<Value: Hashable>: Identifiable {
    let value: Value
    let title: LocalizedStringKey
    var icon: String? = nil
    var id: Value { value }
}

/// 独立的轻量标签，不使用系统分段控件的整块灰底。
struct WalletChoiceBar<Value: Hashable>: View {
    let title: LocalizedStringKey
    @Binding var selection: Value
    let choices: [WalletChoice<Value>]
    var showsTitle = false
    var iconOnly = false
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletAnimation) private var animation

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if showsTitle { Text(title).font(.subheadline) }
            HStack(spacing: 6) {
                ForEach(choices) { choice in
                    Button {
                        withAnimation(animation) { selection = choice.value }
                    } label: {
                        HStack(spacing: 6) {
                            if let icon = choice.icon { Image(systemName: icon) }
                            if !iconOnly { Text(choice.title) }
                        }
                        .font(.system(size: 12, weight: selection == choice.value ? .semibold : .medium))
                        .foregroundStyle(selection == choice.value ? palette.accent : Color.secondary)
                        .padding(.horizontal, iconOnly ? 10 : 13)
                        .frame(minHeight: 32)
                        .background(selection == choice.value ? palette.surface.opacity(0.95) : .clear, in: Capsule())
                        .overlay(Capsule().stroke(selection == choice.value ? palette.accent.opacity(0.3) : .clear, lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(Text(choice.title))
                    .accessibilityLabel(choice.title)
                    .accessibilityAddTraits(selection == choice.value ? [.isSelected] : [])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
