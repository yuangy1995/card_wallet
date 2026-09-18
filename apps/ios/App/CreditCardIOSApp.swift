import SwiftUI

@main
struct CreditCardIOSApp: App {
    @StateObject private var syncCoordinator = SyncCoordinator.shared
    @StateObject private var lockManager = AutoLockManager.shared
    @AppStorage("app_appearance") private var appAppearance: String = "light"

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.environment["WALLET_TEST_HOST"] == "1" { Color.clear }
                else { RootView() }
            }
                .environmentObject(syncCoordinator)
                .environmentObject(lockManager)
                .onAppear {
                    if ProcessInfo.processInfo.environment["WALLET_TEST_HOST"] != "1" { syncCoordinator.bootstrap() }
                }
                .preferredColorScheme(appColorScheme)
        }
    }

    private var appColorScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
