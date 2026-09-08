import SwiftUI

enum WalletSheetLayout {
    static func size(in parent: CGSize) -> CGSize {
        CGSize(width: min(860, max(0, parent.width - 64)), height: min(680, max(0, parent.height - 80)))
    }
}

private struct WalletSheetSizeKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 820, height: 580)
}

extension EnvironmentValues {
    var walletSheetSize: CGSize {
        get { self[WalletSheetSizeKey.self] }
        set { self[WalletSheetSizeKey.self] = newValue }
    }
}

struct WalletSheetHeader<Actions: View>: View {
    let title: LocalizedStringKey
    let subtitle: String
    let icon: String
    @ViewBuilder var actions: Actions
    @Environment(\.walletPalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.accent).frame(width: 38, height: 38)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 20, weight: .semibold)).accessibilityAddTraits(.isHeader)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            actions
        }
        .padding(.horizontal, 22).padding(.vertical, 18)
        .overlay(alignment: .bottom) { palette.line.frame(height: 1) }
    }
}

struct WalletFormSection<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    @ViewBuilder var content: Content
    @Environment(\.walletPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.accent)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(WalletSurface(padding: 18))
    }
}

struct WalletFormField<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
