import SwiftUI

@main
struct CreditCardApp: App {
    @StateObject private var appearance = WalletAppearance()
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || ProcessInfo.processInfo.environment["WALLET_TEST_HOST"] == "1"
    }

    init() {
        // 单元测试宿主不读取卡包、钥匙串或启动云同步。
        guard !Self.isRunningTests else { return }
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown]) { event in
            AutoLockManager.shared.resetActivity()
            return event
        }
    }
    
    var body: some Scene {
        Window("卡包", id: "wallet") {
            Group {
                if Self.isRunningTests {
                    Color.clear
                } else {
                    GeometryReader { geometry in
                        ContentView()
                            .environment(\.walletSheetSize, WalletSheetLayout.size(in: geometry.size))
                            .modifier(WalletThemeModifier())
                    }
                }
            }
            .environmentObject(appearance)
            .preferredColorScheme(appearance.colorMode.colorScheme)
            .frame(minWidth: 980, minHeight: 660)
            .toolbarBackground(.hidden, for: .windowToolbar)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1160, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加卡片") { NotificationCenter.default.post(name: .walletNewCard, object: nil) }
                    .keyboardShortcut("n", modifiers: .command)
                Button("编辑所选卡片") { NotificationCenter.default.post(name: .walletEditCard, object: nil) }
                    .keyboardShortcut("e", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("设置…") { NotificationCenter.default.post(name: .walletSettings, object: nil) }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .textEditing) {
                Button("查找卡片") { NotificationCenter.default.post(name: .walletFindCard, object: nil) }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let walletNewCard = Notification.Name("wallet.new-card")
    static let walletEditCard = Notification.Name("wallet.edit-card")
    static let walletFindCard = Notification.Name("wallet.find-card")
    static let walletSettings = Notification.Name("wallet.settings")
}
