import SwiftUI

struct WalletAppearanceSettings: View {
    @EnvironmentObject private var appearance: WalletAppearance
    @Environment(\.walletPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            WalletFormSection(title: "配色皮肤", icon: "paintpalette") {
                HStack(spacing: 14) {
                    ForEach(WalletSkin.allCases) { skin in
                        skinOption(skin)
                    }
                }
                Text("皮肤只改变配色，不会改变布局、卡片或同步设置。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            WalletFormSection(title: "显示与体验", icon: "slider.horizontal.3") {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("外观").font(.system(size: 13, weight: .medium))
                        Text("选择浅色、深色，或跟随系统。").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 10)
                    WalletChoiceBar(title: "外观", selection: $appearance.colorMode,
                        choices: WalletColorMode.allCases.map { WalletChoice(value: $0, title: $0.title) })
                }
                Divider()
                WalletSettingsToggle(title: "灵动效果", detail: "选卡和切换页面时使用轻盈过渡；系统的“减少动态效果”设置优先。", icon: "sparkles", isOn: $appearance.animationsEnabled)
                Divider()
                WalletSettingsToggle(title: "紧凑列表", detail: "缩小卡片行间距，在一屏内查看更多卡片。", icon: "list.bullet", isOn: $appearance.compactList)
                Divider()
                WalletSettingsToggle(title: "减少透明效果", detail: "使用更实的背景，让文字和内容更清晰。", icon: "square.on.square", isOn: $appearance.reduceTransparency)
            }
        }
    }

    private func skinOption(_ skin: WalletSkin) -> some View {
        let colors = WalletPalette(skin: skin, scheme: colorScheme)
        let selected = appearance.skin == skin
        return Button { appearance.skin = skin } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9).fill(LinearGradient(colors: colors.cardGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(.white.opacity(0.8)).frame(width: 60, height: 5)
                        Capsule().fill(.white.opacity(0.35)).frame(width: 100, height: 5)
                    }.padding(14)
                }
                .frame(height: 64).accessibilityHidden(true)
                HStack {
                    Text(skin.title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? colors.accent : Color.secondary).accessibilityHidden(true)
                }
            }
            .padding(12)
            .foregroundStyle(selected ? palette.accent : Color.primary)
            .background(palette.surface.opacity(selected ? 0.95 : 0.45), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? palette.accent.opacity(0.45) : palette.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
