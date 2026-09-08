import SwiftUI

struct WalletSettingsTabs: View {
    @Binding var selection: WalletSettingsSection
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletAnimation) private var animation

    var body: some View {
        HStack(spacing: 10) {
            ForEach(WalletSettingsSection.allCases) { section in
                Button { withAnimation(animation) { selection = section } } label: {
                    Label(LocalizedStringKey(section.rawValue), systemImage: section.icon)
                        .font(.system(size: 13, weight: selection == section ? .semibold : .medium))
                        .foregroundStyle(selection == section ? palette.accent : Color.secondary)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(selection == section ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == section ? [.isSelected] : [])
            }
        }
    }
}

struct WalletSettingsToggle: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let icon: String
    @Binding var isOn: Bool
    @Environment(\.walletPalette) private var palette

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(palette.accent)
                .frame(width: 36, height: 36).background(palette.selection, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).fixedSize()
        }
        .padding(.vertical, 5)
    }
}
