import SwiftUI

struct RootView: View {
    @EnvironmentObject private var lockManager: AutoLockManager
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @State private var selectedTab: AppTab = .cards

    var body: some View {
        ZStack {
            mainTabView
                .disabled(lockManager.isLocked)

            if lockManager.isLocked {
                LockScreenView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: lockManager.isLocked)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            lockManager.appWillResignActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            lockManager.appDidBecomeActive()
        }
        .onTapGesture { lockManager.userInteracted() }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("卡包", systemImage: selectedTab == .cards ? "wallet.bifold.fill" : "wallet.bifold")
                }
                .tag(AppTab.cards)

            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: selectedTab == .statistics ? "chart.bar.fill" : "chart.bar")
                }
                .tag(AppTab.statistics)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: selectedTab == .settings ? "gear.circle.fill" : "gear.circle")
                }
                .tag(AppTab.settings)
        }
        .tint(.cyan)
    }
}

private enum AppTab: Hashable {
    case cards
    case statistics
    case settings
}
