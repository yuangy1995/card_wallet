import Foundation
import UserNotifications

@MainActor
final class CardSystemNotificationCenter {
    static let shared = CardSystemNotificationCenter()

    private let center = UNUserNotificationCenter.current()
    private let defaultsKey = "card_system_notification_daily_v1"
    private static let scheduledPrefix = "card_scheduled_"
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

        await replaceScheduledNotifications(cards: cards)
        if pendingRefresh != nil { return }
        guard !locked else { return }

        let billingCount = DateCalculator.billingCycleReminderItems(for: cards).count
        let annualCount = cards.filter { DateCalculator.annualFeeDetection(for: $0) != nil }.count
        let expiryCount = cards.filter { card in
            guard let status = DateCalculator.cardExpiryStatus(valid: card.valid) else { return false }
            return status == .expired || status == .soonExpiring
        }.count
        let total = billingCount + annualCount + expiryCount
        guard total > 0 else { return }

        let todayKey = DateCalculator.formatDate(Date())
        let fingerprint = "\(todayKey)|\(billingCount)|\(annualCount)|\(expiryCount)"
        guard UserDefaults.standard.string(forKey: defaultsKey) != fingerprint else { return }
        var parts: [String] = []
        if billingCount > 0 { parts.append("还款/账单 \(billingCount) 项") }
        if annualCount > 0 { parts.append("年费 \(annualCount) 项") }
        if expiryCount > 0 { parts.append("有效期 \(expiryCount) 项") }

        let content = UNMutableNotificationContent()
        content.title = "银行卡提醒"
        content.body = "检测到\(parts.joined(separator: "、"))，请打开应用查看。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "card_daily_summary_\(todayKey)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            UserDefaults.standard.set(fingerprint, forKey: defaultsKey)
        } catch {
            print("发送系统通知失败: \(error.localizedDescription)")
        }
    }

    private func replaceScheduledNotifications(cards: [SharedCard]) async {
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending.map(\.identifier).filter { $0.hasPrefix(Self.scheduledPrefix) }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }

        let now = Date()
        let plans = await buildPlansOffMain(cards: cards, now: now)
            .filter { $0.fireDate.timeIntervalSince(now) > 30 }
            .sorted { $0.fireDate < $1.fireDate }

        // 控制排程数量，优先保证最近一年的最早提醒。
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
                try await center.add(request)
            } catch {
                print("排程系统通知失败: \(error.localizedDescription)")
            }
        }
    }

    private func buildPlansOffMain(cards: [SharedCard], now: Date) async -> [PlannedNotification] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: Self.buildPlans(cards: cards, now: now))
            }
        }
    }

    nonisolated private static func buildPlans(cards: [SharedCard], now: Date) -> [PlannedNotification] {
        var plans: [PlannedNotification] = []
        let calendar = Calendar.current

        for card in cards where card.cardCategory != "debit" {
            if let billDay = Self.dayNumber(card.accountBillDate) {
                for monthOffset in 0..<13 {
                    guard let target = Self.monthlyDate(day: billDay, monthOffset: monthOffset, from: now),
                          let fireDate = calendar.date(byAdding: .day, value: -DateCalculator.billWarningDays, to: target) else { continue }
                    plans.append(
                        Self.plan(
                            card: card,
                            kind: "bill",
                            target: target,
                            fireDate: Self.notificationTime(fireDate),
                            title: "信用卡账单日提醒",
                            body: "\(DateCalculator.billWarningDays) 天后是账单日，请留意本期账单。"
                        )
                    )
                }
            }

            if let dueDay = Self.dayNumber(card.dueDate) {
                for monthOffset in 0..<13 {
                    guard let target = Self.monthlyDate(day: dueDay, monthOffset: monthOffset, from: now),
                          let fireDate = calendar.date(byAdding: .day, value: -DateCalculator.repaymentWarningDays, to: target) else { continue }
                    plans.append(
                        Self.plan(
                            card: card,
                            kind: "repayment",
                            target: target,
                            fireDate: Self.notificationTime(fireDate),
                            title: "信用卡还款提醒",
                            body: "\(DateCalculator.repaymentWarningDays) 天后是还款日，请及时核对并安排还款。"
                        )
                    )
                }
            }

            if card.isQualified != "3",
               let annualTarget = DateCalculator.date(fromTimestamp: card.nextAnnualFeeCollectionTime),
               let fireDate = calendar.date(byAdding: .day, value: -60, to: annualTarget) {
                plans.append(
                    Self.plan(
                        card: card,
                        kind: "annual",
                        target: annualTarget,
                        fireDate: Self.notificationTime(fireDate),
                        title: "信用卡年费提醒",
                        body: "距离下次年费收取约 60 天，请确认本周期达标情况。"
                    )
                )
            }

            if let expiryTarget = Self.expiryDate(card.valid),
               let fireDate = calendar.date(byAdding: .month, value: -6, to: expiryTarget) {
                plans.append(
                    Self.plan(
                        card: card,
                        kind: "expiry",
                        target: expiryTarget,
                        fireDate: Self.notificationTime(fireDate),
                        title: "银行卡有效期提醒",
                        body: "卡片将在约 6 个月后到期，请提前联系发卡行换卡。"
                    )
                )
            }
        }
        return plans
    }

    nonisolated private static func plan(
        card: SharedCard,
        kind: String,
        target: Date,
        fireDate: Date,
        title: String,
        body: String
    ) -> PlannedNotification {
        let dateKey = ISO8601DateFormatter().string(from: target).prefix(10)
        return PlannedNotification(
            identifier: "card_scheduled_\(kind)_\(card.id)_\(dateKey)",
            fireDate: fireDate,
            title: title,
            body: body,
            cardID: card.id
        )
    }

    nonisolated private static func monthlyDate(day: Int, monthOffset: Int, from now: Date) -> Date? {
        let calendar = Calendar.current
        guard let month = calendar.date(byAdding: .month, value: monthOffset, to: now),
              let range = calendar.range(of: .day, in: .month, for: month) else { return nil }
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = min(day, range.count)
        components.hour = 9
        return calendar.date(from: components)
    }

    nonisolated private static func notificationTime(_ date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? date
    }

    nonisolated private static func expiryDate(_ value: String?) -> Date? {
        let parts = (value ?? "").split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let year = Int(parts[1]),
              (1...12).contains(month) else { return nil }
        return Calendar.current.date(from: DateComponents(year: 2000 + year, month: month, day: 1, hour: 9))
    }

    nonisolated private static func dayNumber(_ value: String?) -> Int? {
        guard let value,
              let day = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...31).contains(day) else { return nil }
        return day
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }
}

