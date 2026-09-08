import Foundation

public class DateCalculator {

    public enum AnnualFeeDetectionKind {
        case unqualified
        case warning
        case overdue
    }

    public struct AnnualFeeDetectionResult {
        public let kind: AnnualFeeDetectionKind
        public let days: Int
    }

    public enum CardExpiryStatus {
        case expired
        case soonExpiring
        case normal
    }

    public struct CardExpiryStats {
        public let expiredCards: Int
        public let soonExpiring: Int
        public let normalCards: Int
    }

    public enum BillingCycleReminderKind {
        case bill
        case repayment
    }

    public struct BillingCycleReminderResult: Identifiable {
        public let id = UUID()
        public let kind: BillingCycleReminderKind
        public let days: Int
        public let date: Date
        public let title: String
    }

    public struct DataQualityIssue: Identifiable {
        public let id = UUID()
        public let severity: String
        public let title: String
        public let detail: String
        public let cardName: String
    }

    private static let isoFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let dateTimeDisplayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    public static func timestampToTime(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000.0)
        return isoFormatter.string(from: date)
    }

    public static func timestamp(from date: Date) -> Double {
        date.timeIntervalSince1970 * 1000.0
    }

    public static func date(fromTimestamp timestamp: Double?) -> Date? {
        DataMigrationManager.date(fromTimestamp: timestamp)
    }

    public static func timestampByAddingOneYear(_ timestamp: Double?) -> Double? {
        guard let date = date(fromTimestamp: timestamp),
              let nextYearDate = Calendar.current.date(byAdding: .year, value: 1, to: date) else { return timestamp }
        return self.timestamp(from: nextYearDate)
    }

    public static func formatTimestampDate(_ timestamp: Double?) -> String {
        guard let date = date(fromTimestamp: timestamp) else { return "" }
        return isoFormatter.string(from: date)
    }

    public static func formatTimestampDateTime(_ timestamp: Double?, placeholder: String = "--") -> String {
        guard let date = date(fromTimestamp: timestamp) else { return placeholder }
        return dateTimeDisplayFormatter.string(from: date)
    }

    public static func getDaysDifference(date1Str: String, date2Str: String) -> Int {
        guard let d1 = isoFormatter.date(from: date1Str),
              let d2 = isoFormatter.date(from: date2Str) else { return 0 }
        let calendar = Calendar.current
        let d1Start = calendar.startOfDay(for: d1)
        let d2Start = calendar.startOfDay(for: d2)
        let components = calendar.dateComponents([.day], from: d1Start, to: d2Start)
        return abs(components.day ?? 0)
    }

    private static func completeDay(dayString: String, monthOffset: Int) -> Date? {
        guard let day = Int(dayString) else { return nil }
        let calendar = Calendar.current
        let today = Date()
        var components = calendar.dateComponents([.year, .month], from: today)
        if let currentMonth = components.month {
            var targetMonth = currentMonth + monthOffset
            var targetYear = components.year ?? 2026
            if targetMonth > 12 { targetMonth = 1; targetYear += 1 }
            else if targetMonth < 1 { targetMonth = 12; targetYear -= 1 }
            components.year = targetYear
            components.month = targetMonth
        }
        if let targetDate = calendar.date(from: components),
           let range = calendar.range(of: .day, in: .month, for: targetDate) {
            components.day = min(day, range.count)
        }
        return calendar.date(from: components)
    }

    public static func completeAccountBillDate(_ accountBillDate: String, dateType: String = "current") -> String {
        guard !accountBillDate.isEmpty else { return "" }
        let offset = dateType == "next" ? 1 : 0
        guard let date = completeDay(dayString: accountBillDate, monthOffset: offset) else { return "" }
        return isoFormatter.string(from: date)
    }

    public static func completeDueDate(accountBillDate: String, dueDate: String, dateType: String = "current") -> String {
        guard !accountBillDate.isEmpty, !dueDate.isEmpty else { return "" }
        let offset = dateType == "next" ? 1 : 0
        guard completeDay(dayString: accountBillDate, monthOffset: offset) != nil else { return "" }
        guard let billDayNum = Int(accountBillDate), let dueDayNum = Int(dueDate) else { return "" }
        let dueMonthOffset = dueDayNum < billDayNum ? offset + 1 : offset
        guard let dueDateObj = completeDay(dayString: dueDate, monthOffset: dueMonthOffset) else { return "" }
        return isoFormatter.string(from: dueDateObj)
    }

    public static func calculateInterestFreePeriod(
        accountBillDate: String,
        dueDate: String,
        billingDayToNextBill: Bool = true
    ) -> Int {
        guard !accountBillDate.isEmpty, !dueDate.isEmpty,
              let billDate = Int(accountBillDate), let dueDateNum = Int(dueDate) else { return 0 }
        let baseDays = dueDateNum > billDate ? dueDateNum - billDate : (31 - billDate) + dueDateNum
        var maxDays = baseDays
        if billingDayToNextBill { maxDays = baseDays + 30 }
        return min(max(maxDays, 20), 56)
    }

    public static func calculateRemainingDaysForPreviousBill(accountBillDate: String, dueDate: String) -> Int {
        guard !accountBillDate.isEmpty, !dueDate.isEmpty else { return 0 }
        let today = Date()
        let todayString = isoFormatter.string(from: today)
        let currentDueDate = completeDueDate(accountBillDate: accountBillDate, dueDate: dueDate, dateType: "current")
        if todayString > currentDueDate { return 0 }
        return getDaysDifference(date1Str: todayString, date2Str: currentDueDate)
    }

    public static func isNearAnnualFeeTimestamp(_ nextAnnualFeeDate: Double?, warningDays: Int = 60) -> Bool {
        guard let remainingDays = annualFeeRemainingDays(nextAnnualFeeDate) else { return false }
        return remainingDays <= warningDays && remainingDays >= 0
    }

    public static func annualFeeRemainingDays(_ nextAnnualFeeDate: Double?, now: Date = Date()) -> Int? {
        guard let targetDate = date(fromTimestamp: nextAnnualFeeDate) else { return nil }
        return Int(ceil(targetDate.timeIntervalSince(now) / (24 * 60 * 60)))
    }

    public static func annualFeeDetection(
        isQualified: String?,
        nextAnnualFeeDate: Double?,
        warningDays: Int = 60,
        now: Date = Date()
    ) -> AnnualFeeDetectionResult? {
        guard isQualified != "3",
              let diffDays = annualFeeRemainingDays(nextAnnualFeeDate, now: now) else { return nil }
        if isQualified == "2", diffDays <= warningDays, diffDays > 0 {
            return AnnualFeeDetectionResult(kind: .unqualified, days: diffDays)
        }
        if diffDays <= warningDays, diffDays > 0, isQualified != "2" { return AnnualFeeDetectionResult(kind: .warning, days: diffDays) }
        if diffDays <= 0, diffDays > -warningDays { return AnnualFeeDetectionResult(kind: .overdue, days: abs(diffDays)) }
        return nil
    }

    public static func annualFeeDetection(for card: SharedCard, warningDays: Int = 60, now: Date = Date()) -> AnnualFeeDetectionResult? {
        guard card.cardCategory != "debit" else { return nil }
        return annualFeeDetection(isQualified: card.isQualified, nextAnnualFeeDate: card.nextAnnualFeeCollectionTime, warningDays: warningDays, now: now)
    }

    public static func getDaysFromNow(_ timestamp: Double?) -> (days: Int, text: String) {
        guard let targetDate = date(fromTimestamp: timestamp) else { return (0, "") }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: today, to: target)
        let diffDays = components.day ?? 0
        return (abs(diffDays), diffDays >= 0 ? "还有" : "已过")
    }

    public static func formatValidDate(_ dateStr: String?) -> String {
        DataMigrationManager.convertValidToMMYY(dateStr)
    }

    public static func cardExpiryStatus(valid: String?, now: Date = Date()) -> CardExpiryStatus? {
        let normalized = DataMigrationManager.convertValidToMMYY(valid)
        guard !normalized.isEmpty else { return nil }
        let parts = normalized.split(separator: "/")
        guard parts.count == 2, let month = Int(parts[0]), let year = Int(parts[1]), (1...12).contains(month) else { return nil }
        var components = DateComponents()
        components.year = 2000 + year
        components.month = month
        components.day = 1
        guard let expiryDate = Calendar.current.date(from: components),
              let sixMonthsLater = Calendar.current.date(byAdding: .month, value: 6, to: now) else { return nil }
        if expiryDate < now { return .expired }
        if expiryDate < sixMonthsLater { return .soonExpiring }
        return .normal
    }

    public static func cardExpiryStats(for cards: [SharedCard], now: Date = Date()) -> CardExpiryStats {
        var expired = 0, soonExpiring = 0, normalCards = 0
        for card in cards {
            switch cardExpiryStatus(valid: card.valid, now: now) {
            case .expired: expired += 1
            case .soonExpiring: soonExpiring += 1
            case .normal: normalCards += 1
            case .none: continue
            }
        }
        return CardExpiryStats(expiredCards: expired, soonExpiring: soonExpiring, normalCards: normalCards)
    }

    public static func calculateInterestFreeDays(card: SharedCard, today: Date = Date()) -> Int {
        guard card.cardCategory != "debit",
              let billDayStr = card.accountBillDate,
              let billDay = Int(billDayStr),
              let dueDayStr = card.dueDate,
              let dueDay = Int(dueDayStr) else {
            return -1
        }
        
        if !(1...31).contains(billDay) || !(1...31).contains(dueDay) {
            return -1
        }
        
        let calendar = Calendar.current
        let spendDay = calendar.component(.day, from: today)
        
        // 1. 确定消费会计入哪个月的账单日
        let isNextBill = card.billingDaySpendingToNextBill ? (spendDay >= billDay) : (spendDay > billDay)
        
        guard let targetBillMonth = calendar.date(byAdding: .month, value: isNextBill ? 1 : 0, to: today) else {
            return -1
        }
        
        guard let rangeOfBillMonth = calendar.range(of: .day, in: .month, for: targetBillMonth) else {
            return -1
        }
        let lengthOfBillMonth = rangeOfBillMonth.count
        
        // 目标账单日对齐该月最大天数
        var billComponents = calendar.dateComponents([.year, .month], from: targetBillMonth)
        billComponents.day = min(billDay, lengthOfBillMonth)
        guard let targetBillDate = calendar.date(from: billComponents) else {
            return -1
        }
        
        // 2. 计算对应的还款日
        let isNextMonthDue = dueDay <= billDay
        guard let targetDueMonth = calendar.date(byAdding: .month, value: isNextMonthDue ? 1 : 0, to: targetBillDate) else {
            return -1
        }
        
        guard let rangeOfDueMonth = calendar.range(of: .day, in: .month, for: targetDueMonth) else {
            return -1
        }
        let lengthOfDueMonth = rangeOfDueMonth.count
        
        var dueComponents = calendar.dateComponents([.year, .month], from: targetDueMonth)
        dueComponents.day = min(dueDay, lengthOfDueMonth)
        guard let targetDueDate = calendar.date(from: dueComponents) else {
            return -1
        }
        
        // 3. 计算免息天数
        let startOfToday = calendar.startOfDay(for: today)
        let startOfDueDate = calendar.startOfDay(for: targetDueDate)
        let componentsDiff = calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate)
        let days = componentsDiff.day ?? 0
        return days >= 0 ? days : 0
    }

    private static func dayNumber(_ value: String?) -> Int? {
        guard let value,
              let day = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...31).contains(day) else {
            return nil
        }
        return day
    }

    private static func monthDayDate(day: Int, baseDate: Date, monthOffset: Int = 0) -> Date? {
        let calendar = Calendar.current
        guard let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: baseDate),
              let range = calendar.range(of: .day, in: .month, for: targetMonth) else {
            return nil
        }
        var components = calendar.dateComponents([.year, .month], from: targetMonth)
        components.day = min(day, range.count)
        return calendar.date(from: components)
    }

    private static func daysUntil(_ date: Date, now: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: target).day ?? 0
    }

    private static func nextBillDate(accountBillDate: String?, now: Date = Date()) -> Date? {
        guard let billDay = dayNumber(accountBillDate),
              let current = monthDayDate(day: billDay, baseDate: now) else {
            return nil
        }
        return daysUntil(current, now: now) >= 0 ? current : monthDayDate(day: billDay, baseDate: now, monthOffset: 1)
    }

    private static func dueDateForBillMonth(accountBillDate: String?, dueDate: String?, now: Date = Date(), monthOffset: Int = 0) -> Date? {
        guard let billDay = dayNumber(accountBillDate),
              let dueDay = dayNumber(dueDate) else {
            return nil
        }
        let dueMonthOffset = monthOffset + (dueDay < billDay ? 1 : 0)
        return monthDayDate(day: dueDay, baseDate: now, monthOffset: dueMonthOffset)
    }

    private static func nextDueDate(accountBillDate: String?, dueDate: String?, now: Date = Date()) -> Date? {
        guard let current = dueDateForBillMonth(accountBillDate: accountBillDate, dueDate: dueDate, now: now) else {
            return nil
        }
        return daysUntil(current, now: now) >= 0
            ? current
            : dueDateForBillMonth(accountBillDate: accountBillDate, dueDate: dueDate, now: now, monthOffset: 1)
    }

    public static func billingCycleReminders(
        for card: SharedCard,
        now: Date = Date(),
        billWarningDays: Int = 3,
        repaymentWarningDays: Int = 7
    ) -> [BillingCycleReminderResult] {
        guard card.cardCategory != "debit" else { return [] }
        var reminders: [BillingCycleReminderResult] = []

        if let billDate = nextBillDate(accountBillDate: card.accountBillDate, now: now) {
            let days = daysUntil(billDate, now: now)
            if days >= 0 && days <= billWarningDays {
                reminders.append(BillingCycleReminderResult(
                    kind: .bill,
                    days: days,
                    date: billDate,
                    title: days == 0 ? "今天是账单日" : "\(days) 天后账单日"
                ))
            }
        }

        if let repaymentDate = nextDueDate(accountBillDate: card.accountBillDate, dueDate: card.dueDate, now: now) {
            let days = daysUntil(repaymentDate, now: now)
            if days >= 0 && days <= repaymentWarningDays {
                reminders.append(BillingCycleReminderResult(
                    kind: .repayment,
                    days: days,
                    date: repaymentDate,
                    title: days == 0 ? "今天是还款日" : "\(days) 天后还款日"
                ))
            }
        }

        return reminders
    }

    public static func billingCycleReminderItems(for cards: [SharedCard], now: Date = Date()) -> [(card: SharedCard, reminder: BillingCycleReminderResult)] {
        cards.flatMap { card in
            billingCycleReminders(for: card, now: now).map { (card, $0) }
        }.sorted {
            if $0.reminder.kind != $1.reminder.kind {
                return $0.reminder.kind == .repayment
            }
            if $0.reminder.days != $1.reminder.days {
                return $0.reminder.days < $1.reminder.days
            }
            return $0.card.bank < $1.card.bank
        }
    }

    public static func analyzeDataQuality(cards: [SharedCard]) -> [DataQualityIssue] {
        var issues: [DataQualityIssue] = []
        var numberGroups: [String: [SharedCard]] = [:]

        func cardName(_ card: SharedCard) -> String {
            "\(card.bank.isEmpty ? "未知银行" : card.bank) - \((card.alias ?? "").isEmpty ? "未命名卡片" : card.alias!)"
        }

        func add(_ severity: String, _ title: String, _ detail: String, _ card: SharedCard? = nil) {
            issues.append(DataQualityIssue(severity: severity, title: title, detail: detail, cardName: card.map(cardName) ?? ""))
        }

        for card in cards {
            let number = card.cardNumber.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
            if number.isEmpty {
                add("严重", "卡号缺失", "无法用于验卡或重复检测。", card)
            } else {
                numberGroups[number, default: []].append(card)
            }

            if card.bank.isEmpty {
                add("警告", "银行缺失", "建议补全发卡银行，便于统计和同步审计。", card)
            }

            if let valid = card.valid, !valid.isEmpty, cardExpiryStatus(valid: valid) == nil {
                add("严重", "有效期格式异常", "当前有效期为“\(valid)”，建议使用 MM/YY。", card)
            }

            if card.cardCategory != "debit" {
                let billDay = dayNumber(card.accountBillDate)
                let dueDay = dayNumber(card.dueDate)
                if (card.accountBillDate ?? "").isEmpty || (card.dueDate ?? "").isEmpty {
                    add("警告", "账单/还款配置缺失", "无法计算还款提醒和免息期。", card)
                } else {
                    if billDay == nil { add("严重", "账单日非法", "账单日必须是 1-31 之间的数字。", card) }
                    if dueDay == nil { add("严重", "还款日非法", "还款日必须是 1-31 之间的数字。", card) }
                }
                if card.isQualified != "3", card.nextAnnualFeeCollectionTime == nil {
                    add("警告", "年费日期缺失", "非终免年费卡片缺少下次年费收取时间。", card)
                }
            } else if !(card.accountBillDate ?? "").isEmpty || !(card.dueDate ?? "").isEmpty || (card.annualFee ?? 0) > 0 || card.nextAnnualFeeCollectionTime != nil {
                add("提示", "储蓄卡包含信用卡字段", "储蓄卡不会参与账单、还款和年费提醒，建议清理相关字段。", card)
            }
        }

        for group in numberGroups.values where group.count > 1 {
            add("严重", "卡号重复", group.map(cardName).joined(separator: "、"))
        }

        let sharedGroups = Dictionary(grouping: cards.filter { $0.cardCategory != "debit" && $0.isSharedLimit }) {
            "\($0.country)|\($0.bank)|\($0.type ?? "")"
        }
        for group in sharedGroups.values where group.count > 1 {
            let limits = Set(group.map { $0.limit ?? 0 })
            if limits.count > 1 {
                add("警告", "共享额度不一致", group.map { "\(($0.alias ?? "").isEmpty ? "未命名卡片" : $0.alias!)：\(Int($0.limit ?? 0))" }.joined(separator: "、"))
            }
        }

        let weight = ["严重": 0, "警告": 1, "提示": 2]
        return issues.sorted { (weight[$0.severity] ?? 9) < (weight[$1.severity] ?? 9) }
    }
}
