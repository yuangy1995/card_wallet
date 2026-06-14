import SwiftUI

@main
struct CreditCardIOSApp: App {
    @StateObject private var syncCoordinator = SyncCoordinator.shared
    @StateObject private var lockManager = AutoLockManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(syncCoordinator)
                .environmentObject(lockManager)
                .onAppear {
                    syncCoordinator.bootstrap()
                }
        }
    }
}
