import SwiftUI

enum WalletSkin: String, CaseIterable, Identifiable {
    case forest, ice
    var id: String { rawValue }
    var title: LocalizedStringKey { self == .forest ? "森绿" : "冰蓝" }
}

enum WalletColorMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class WalletAppearance: ObservableObject {
    @Published var skin: WalletSkin { didSet { defaults.set(skin.rawValue, forKey: "wallet_skin") } }
    @Published var colorMode: WalletColorMode { didSet { defaults.set(colorMode.rawValue, forKey: "wallet_color_mode") } }
    @Published var animationsEnabled: Bool { didSet { defaults.set(animationsEnabled, forKey: "wallet_animations") } }
    @Published var compactList: Bool { didSet { defaults.set(compactList, forKey: "wallet_compact_list") } }
    @Published var reduceTransparency: Bool { didSet { defaults.set(reduceTransparency, forKey: "wallet_reduce_transparency") } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        skin = WalletSkin(rawValue: defaults.string(forKey: "wallet_skin") ?? "") ?? .ice
        colorMode = WalletColorMode(rawValue: defaults.string(forKey: "wallet_color_mode") ?? "") ?? .system
        animationsEnabled = defaults.object(forKey: "wallet_animations") as? Bool ?? true
        compactList = defaults.object(forKey: "wallet_compact_list") as? Bool ?? true
        reduceTransparency = defaults.bool(forKey: "wallet_reduce_transparency")
    }
}

struct WalletPalette {
    let skin: WalletSkin
    let scheme: ColorScheme
    private var dark: Bool { scheme == .dark }
    var accent: Color {
        skin == .ice ? Color(hex: dark ? 0xA8C6FF : 0x3465CD) : Color(hex: dark ? 0xA2E4C9 : 0x286253)
    }
    var background: Color {
        skin == .ice ? Color(hex: dark ? 0x151E30 : 0xE9EEF8) : Color(hex: dark ? 0x18211E : 0xE9EDE8)
    }
    var surface: Color {
        skin == .ice ? Color(hex: dark ? 0x23314B : 0xF6F8FF) : Color(hex: dark ? 0x23332B : 0xF6F9F5)
    }
    var selection: Color { accent.opacity(dark ? 0.17 : 0.1) }
    var line: Color { accent.opacity(dark ? 0.16 : 0.12) }
    var edge: Color { Color.white.opacity(dark ? 0.12 : 0.78) }
    var glow: Color {
        skin == .ice ? Color(hex: dark ? 0x284263 : 0xC8DFF4) : Color(hex: dark ? 0x345043 : 0xC5DECD)
    }
    var secondaryGlow: Color { Color(hex: dark ? 0x353055 : 0xD9D1F5) }
    var cardGradient: [Color] {
        skin == .ice ? [Color(hex: 0x5686C1), Color(hex: 0x1D375C)] : [Color(hex: 0x487D67), Color(hex: 0x18372D)]
    }
    var success: Color { Color(hex: dark ? 0x96DCC0 : 0x28775F) }
    var warning: Color { Color(hex: dark ? 0xF5C57D : 0x885514) }
}

private struct WalletPaletteKey: EnvironmentKey {
    static let defaultValue = WalletPalette(skin: .ice, scheme: .light)
}
private struct WalletAnimationKey: EnvironmentKey {
    static let defaultValue: Animation? = .spring(response: 0.28, dampingFraction: 0.85)
}
private struct WalletLockedKey: EnvironmentKey {
    static let defaultValue = true
}
extension EnvironmentValues {
    var walletIsLocked: Bool {
        get { self[WalletLockedKey.self] }
        set { self[WalletLockedKey.self] = newValue }
    }
    var walletPalette: WalletPalette {
        get { self[WalletPaletteKey.self] }
        set { self[WalletPaletteKey.self] = newValue }
    }
    var walletAnimation: Animation? {
        get { self[WalletAnimationKey.self] }
        set { self[WalletAnimationKey.self] = newValue }
    }
}

struct WalletThemeModifier: ViewModifier {
    @EnvironmentObject private var appearance: WalletAppearance
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        let palette = WalletPalette(skin: appearance.skin, scheme: colorScheme)
        content
            .environment(\.walletPalette, palette)
            .environment(\.walletAnimation, appearance.animationsEnabled && !reduceMotion ? .spring(response: 0.28, dampingFraction: 0.85) : nil)
            .tint(palette.accent)
            .transaction { transaction in
                if !appearance.animationsEnabled || reduceMotion {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
            .background(WalletBackground(palette: palette))
    }
}

struct WalletBackground: View {
    let palette: WalletPalette
    var body: some View {
        palette.background.ignoresSafeArea()
    }
}

struct WalletSurface: ViewModifier {
    @Environment(\.walletPalette) private var palette
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content.padding(padding)
            .background(palette.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.edge, lineWidth: 1))
    }
}

struct WalletGlass: ViewModifier {
    @EnvironmentObject private var appearance: WalletAppearance
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.walletPalette) private var palette
    func body(content: Content) -> some View {
        content.background {
            if appearance.reduceTransparency || systemReduceTransparency {
                palette.surface.ignoresSafeArea(.container, edges: .top)
            } else {
                Rectangle().fill(.ultraThinMaterial).overlay(palette.surface.opacity(0.32))
                    .ignoresSafeArea(.container, edges: .top)
            }
        }
    }
}

struct WalletPageHeader<Actions: View>: View {
    let title: LocalizedStringKey
    let subtitle: String
    @ViewBuilder var actions: Actions
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 27, weight: .semibold)).accessibilityAddTraits(.isHeader)
                if !subtitle.isEmpty { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 12)
            actions
        }
    }
}

struct WalletFieldValue: View {
    let title: LocalizedStringKey
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .medium)).monospacedDigit().textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

enum WalletFormat {
    static func amount(_ value: Double?, currency: String? = "CNY") -> String {
        guard let value else { return String(localized: "未填写") }
        let code = currency?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        if code.isEmpty { return String(localized: "未设置币种") + " " + value.formatted(.number.precision(.fractionLength(0...2))) }
        return value.formatted(.currency(code: code).precision(.fractionLength(0...2)))
    }
    static func date(_ timestamp: Double?) -> String {
        guard let date = timestamp.flatMap({ DataMigrationManager.date(fromTimestamp: $0) }) else { return String(localized: "未填写") }
        return date.formatted(date: .numeric, time: .omitted)
    }
    static func day(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return String(localized: "未填写") }
        return String(localized: "每月 \(value) 日")
    }
}
