import SwiftUI
import UserNotifications

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
            Task {
                await CardSystemNotificationCenter.shared.refresh(cards: syncCoordinator.cards, locked: lockManager.isLocked)
            }
        }
        .onReceive(syncCoordinator.$cards) { cards in
            Task {
                await CardSystemNotificationCenter.shared.refresh(cards: cards, locked: lockManager.isLocked)
            }
        }
        .onChange(of: lockManager.isLocked) { _, isLocked in
            if !isLocked {
                Task {
                    await CardSystemNotificationCenter.shared.refresh(cards: syncCoordinator.cards, locked: false)
                }
            }
        }
        .task {
            await CardSystemNotificationCenter.shared.refresh(cards: syncCoordinator.cards, locked: lockManager.isLocked)
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

            ToolsView()
                .tabItem {
                    Label("工具", systemImage: selectedTab == .tools ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver")
                }
                .tag(AppTab.tools)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: selectedTab == .settings ? "gear.circle.fill" : "gear.circle")
                }
                .tag(AppTab.settings)
        }
        .tint(.blue)
    }
}

private enum AppTab: Hashable {
    case cards
    case tools
    case settings
}

@MainActor
private final class CardSystemNotificationCenter {
    static let shared = CardSystemNotificationCenter()

    private let notificationKey = "card_system_notification_daily_v1"
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func refresh(cards: [SharedCard], locked: Bool) async {
        guard !locked else { return }
        let summary = reminderSummary(cards: cards)
        guard summary.total > 0 else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let fingerprint = "\(today)|\(summary.repayment)|\(summary.bill)|\(summary.annual)|\(summary.expiry)"
        guard UserDefaults.standard.string(forKey: notificationKey) != fingerprint else { return }

        let content = UNMutableNotificationContent()
        content.title = "卡片提醒"
        content.body = [
            summary.repayment > 0 ? "还款 \(summary.repayment) 项" : nil,
            summary.bill > 0 ? "账单 \(summary.bill) 项" : nil,
            summary.annual > 0 ? "年费 \(summary.annual) 项" : nil,
            summary.expiry > 0 ? "有效期 \(summary.expiry) 项" : nil
        ].compactMap { $0 }.joined(separator: " / ")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "card-reminder-\(fingerprint)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
        UserDefaults.standard.set(fingerprint, forKey: notificationKey)
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    private func reminderSummary(cards: [SharedCard]) -> (repayment: Int, bill: Int, annual: Int, expiry: Int, total: Int) {
        let billingItems = DateCalculator.billingCycleReminderItems(for: cards)
        let repayment = billingItems.filter { $0.reminder.kind == .repayment }.count
        let bill = billingItems.filter { $0.reminder.kind == .bill }.count
        let annual = cards.filter { DateCalculator.annualFeeDetection(for: $0) != nil }.count
        let expiry = cards.filter { card in
            guard let status = DateCalculator.cardExpiryStatus(valid: card.valid) else { return false }
            return status == .expired || status == .soonExpiring
        }.count
        return (repayment, bill, annual, expiry, repayment + bill + annual + expiry)
    }
}
