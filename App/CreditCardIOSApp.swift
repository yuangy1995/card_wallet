import SwiftUI

@main
struct CreditCardIOSApp: App {
    @StateObject private var syncCoordinator = SyncCoordinator.shared
    @StateObject private var lockManager = AutoLockManager.shared
    @AppStorage("app_appearance") private var appAppearance: String = "light"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(syncCoordinator)
                .environmentObject(lockManager)
                .onAppear {
                    syncCoordinator.bootstrap()
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
