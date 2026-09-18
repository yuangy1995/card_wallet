import SwiftUI
import UIKit
import UserNotifications

struct RootView: View {
    @EnvironmentObject private var lockManager: AutoLockManager
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @State private var selectedTab: AppTab = .cards

    var body: some View {
        ZStack {
            if !lockManager.isLocked { mainTabView }
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
            syncCoordinator.setSuspended(isLocked: isLocked)
            if !isLocked {
                Task {
                    await CardSystemNotificationCenter.shared.refresh(cards: syncCoordinator.cards, locked: false)
                }
            }
        }
        .task {
            syncCoordinator.setSuspended(isLocked: lockManager.isLocked)
            await CardSystemNotificationCenter.shared.refresh(cards: syncCoordinator.cards, locked: lockManager.isLocked)
        }
        .background {
            WindowTapObserver {
                lockManager.userInteracted()
            }
        }
        .alert(
            "当前将使用移动数据进行同步",
            isPresented: Binding(
                get: { syncCoordinator.needsCellularSyncConfirmation },
                set: { if !$0 { syncCoordinator.cancelCellularSyncConfirmation() } }
            )
        ) {
            Button("取消", role: .cancel) {
                syncCoordinator.cancelCellularSyncConfirmation()
            }
            Button("继续") {
                syncCoordinator.confirmCellularSync()
            }
        } message: {
            Text("同步可能会产生流量费用，请确保流量充足！")
        }
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

private struct WindowTapObserver: UIViewRepresentable {
    let onTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        context.coordinator.onTap = onTap
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        DispatchQueue.main.async {
            context.coordinator.attach(to: uiView.window)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: () -> Void
        private weak var window: UIWindow?
        private weak var recognizer: UITapGestureRecognizer?

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        func attach(to window: UIWindow?) {
            guard let window, self.window !== window else { return }
            detach()

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            self.window = window
            self.recognizer = recognizer
        }

        func detach() {
            if let recognizer, let window {
                window.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            window = nil
        }

        @objc private func handleTap() {
            onTap()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

@MainActor
private final class CardSystemNotificationCenter {
    static let shared = CardSystemNotificationCenter()

    private let center = UNUserNotificationCenter.current()
    private let notificationKey = "card_system_notification_daily_v1"
    private let scheduledPrefix = "card_scheduled_"
    private var pendingRefresh: (cards: [SharedCard], locked: Bool)?
    private var isRefreshing = false

    private struct PlannedNotification {
        let identifier: String
        let fireDate: Date
        let title: String
        let body: String
        let cardID: String
    }

    private init() {}

    func refresh(cards: [SharedCard], locked: Bool) async {
        pendingRefresh = (cards, locked)
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }
        while let request = pendingRefresh {
            pendingRefresh = nil
            await performRefresh(cards: request.cards, locked: request.locked)
        }
    }

    private func performRefresh(cards: [SharedCard], locked: Bool) async {
        if cards.isEmpty {
            await replaceScheduledNotifications(cards: [])
            return
        }
        guard await requestAuthorizationIfNeeded() else { return }

        // 日历通知由系统持久化；排程完成后，即使应用进入后台或被终止也可投递。
        await replaceScheduledNotifications(cards: cards)
        if pendingRefresh != nil { return }
        guard !locked else { return }

        let summary = reminderSummary(cards: cards)
        guard summary.total > 0 else { return }

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
        do {
            try await enqueue(request)
            UserDefaults.standard.set(fingerprint, forKey: notificationKey)
        } catch {
            print("发送系统通知失败: \(error.localizedDescription)")
        }
    }

    private func replaceScheduledNotifications(cards: [SharedCard]) async {
        let identifiers: [String] = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
        let staleIDs = identifiers.filter { $0.hasPrefix(scheduledPrefix) }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }

        let now = Date()
        let plans = buildPlans(cards: cards, now: now)
            .filter { $0.fireDate.timeIntervalSince(now) > 30 }
            .sorted { $0.fireDate < $1.fireDate }

        // iOS 对单个应用的待处理本地通知数量有限，优先保留最近的 60 条。
        for plan in plans.prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            content.userInfo = ["cardID": plan.cardID]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: plan.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
            do {
                try await enqueue(request)
            } catch {
                print("排程系统通知失败: \(error.localizedDescription)")
            }
        }
    }

    private func buildPlans(cards: [SharedCard], now: Date) -> [PlannedNotification] {
        var plans: [PlannedNotification] = []
        let calendar = Calendar.current
        let billWarningDays = 3
        let repaymentWarningDays = 7

        for card in cards where card.cardCategory != "debit" {
            if let billDay = dayNumber(card.accountBillDate) {
                for monthOffset in 0..<13 {
                    guard let target = monthlyDate(day: billDay, monthOffset: monthOffset, from: now),
                          let fireDate = calendar.date(byAdding: .day, value: -billWarningDays, to: target) else { continue }
                    plans.append(
                        plan(
                            card: card,
                            kind: "bill",
                            target: target,
                            fireDate: notificationTime(fireDate),
                            title: "信用卡账单日提醒",
                            body: "\(billWarningDays) 天后是账单日，请留意本期账单。"
                        )
                    )
                }
            }

            if let dueDay = dayNumber(card.dueDate) {
                for monthOffset in 0..<13 {
                    guard let target = monthlyDate(day: dueDay, monthOffset: monthOffset, from: now),
                          let fireDate = calendar.date(byAdding: .day, value: -repaymentWarningDays, to: target) else { continue }
                    plans.append(
                        plan(
                            card: card,
                            kind: "repayment",
                            target: target,
                            fireDate: notificationTime(fireDate),
                            title: "信用卡还款提醒",
                            body: "\(repaymentWarningDays) 天后是还款日，请及时核对并安排还款。"
                        )
                    )
                }
            }

            if card.isQualified != "3",
               let annualTarget = DateCalculator.date(fromTimestamp: card.nextAnnualFeeCollectionTime),
               let fireDate = calendar.date(byAdding: .day, value: -60, to: annualTarget) {
                plans.append(
                    plan(
                        card: card,
                        kind: "annual",
                        target: annualTarget,
                        fireDate: notificationTime(fireDate),
                        title: "信用卡年费提醒",
                        body: "距离下次年费收取约 60 天，请确认本周期达标情况。"
                    )
                )
            }

            if let expiryTarget = expiryDate(card.valid),
               let fireDate = calendar.date(byAdding: .month, value: -6, to: expiryTarget) {
                plans.append(
                    plan(
                        card: card,
                        kind: "expiry",
                        target: expiryTarget,
                        fireDate: notificationTime(fireDate),
                        title: "银行卡有效期提醒",
                        body: "卡片将在约 6 个月后到期，请提前联系发卡行换卡。"
                    )
                )
            }
        }
        return plans
    }

    private func plan(
        card: SharedCard,
        kind: String,
        target: Date,
        fireDate: Date,
        title: String,
        body: String
    ) -> PlannedNotification {
        let dateKey = ISO8601DateFormatter().string(from: target).prefix(10)
        return PlannedNotification(
            identifier: "\(scheduledPrefix)\(kind)_\(card.id)_\(dateKey)",
            fireDate: fireDate,
            title: title,
            body: body,
            cardID: card.id
        )
    }

    private func monthlyDate(day: Int, monthOffset: Int, from now: Date) -> Date? {
        let calendar = Calendar.current
        guard let month = calendar.date(byAdding: .month, value: monthOffset, to: now),
              let range = calendar.range(of: .day, in: .month, for: month) else { return nil }
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = min(day, range.count)
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components)
    }

    private func notificationTime(_ date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? date
    }

    private func expiryDate(_ value: String?) -> Date? {
        let normalized = DataMigrationManager.convertValidToMMYY(value)
        let parts = normalized.split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let year = Int(parts[1]),
              (1...12).contains(month) else { return nil }
        return Calendar.current.date(from: DateComponents(year: 2000 + year, month: month, day: 1, hour: 9))
    }

    private func dayNumber(_ value: String?) -> Int? {
        guard let value,
              let day = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...31).contains(day) else { return nil }
        return day
    }

    // The callback API keeps the non-Sendable notification center on the main actor.
    // Only the continuation/result crosses the system callback queue.
    private func enqueue(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let status: Int = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus.rawValue)
            }
        }
        guard let authorization = UNAuthorizationStatus(rawValue: status) else { return false }
        switch authorization {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound, .badge]) { allowed, _ in
                    continuation.resume(returning: allowed)
                }
            }
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
