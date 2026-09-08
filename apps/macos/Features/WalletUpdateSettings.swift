import SwiftUI

struct WalletUpdateSettings: View {
    @EnvironmentObject private var updater: AppUpdater

    var body: some View {
        WalletFormSection(title: "软件更新", icon: "arrow.down.circle") {
            LabeledContent("当前版本", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
            Text("卡包会定期检查新版本，发现更新后由你确认安装。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("检查更新…", action: updater.checkForUpdates)
                .buttonStyle(.borderedProminent)
                .disabled(!updater.canCheckForUpdates)
        }
    }
}
