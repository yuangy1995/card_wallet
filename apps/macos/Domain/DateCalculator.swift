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

    public static let billWarningDays = 3
    public static let repaymentWarningDays = 7
    
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
    
    /// 将时间戳转换为 YYYY-MM-DD 格式字符串
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
              let nextYearDate = Calendar.current.date(byAdding: .year, value: 1, to: date) else {
            return timestamp
        }
        return self.timestamp(from: nextYearDate)
    }

    public static func formatTimestampDate(_ timestamp: Double?) -> String {
        guard let date = date(fromTimestamp: timestamp) else { return "" }
        return isoFormatter.string(from: date)
    }

    public static func formatDate(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    public static func formatTimestampDateTime(_ timestamp: Double?, placeholder: String = "--") -> String {
        guard let date = date(fromTimestamp: timestamp) else { return placeholder }
        return dateTimeDisplayFormatter.string(from: date)
    }
    
    /// 计算两个日期字符串之间的天数差
    public static func getDaysDifference(date1Str: String, date2Str: String) -> Int {
        guard let d1 = isoFormatter.date(from: date1Str),
              let d2 = isoFormatter.date(from: date2Str) else {
            return 0
        }
        let calendar = Calendar.current
        let d1Start = calendar.startOfDay(for: d1)
        let d2Start = calendar.startOfDay(for: d2)
        
        let components = calendar.dateComponents([.day], from: d1Start, to: d2Start)
        return abs(components.day ?? 0)
    }
    
    /// 补全账单日或还款日：将 "10" 号加上偏移月补全为真实的 YYYY-MM-DD
    /// - Parameters:
    ///   - dayString: 账单日/还款日数字字符串 (如 "10")
    ///   - monthOffset: 月份偏移量 (0 代表本月，1 代表下月，-1 代表上月)
    /// - Returns: 规整的真实 Date
    private static func completeDay(dayString: String, monthOffset: Int) -> Date? {
        guard let day = Int(dayString) else { return nil }
        
        let calendar = Calendar.current
        let today = Date()
        var components = calendar.dateComponents([.year, .month], from: today)
        
        if let currentMonth = components.month {
            var targetMonth = currentMonth + monthOffset
            var targetYear = components.year ?? 2026
            
            if targetMonth > 12 {
                targetMonth = 1
                targetYear += 1
            } else if targetMonth < 1 {
                targetMonth = 12
                targetYear -= 1
            }
            
            components.year = targetYear
            components.month = targetMonth
        }
        
        // 获取目标年月的最大天数（例如处理 2 月只有 28 或 29 天的情况，防溢出越界）
        if let targetDate = calendar.date(from: components),
           let range = calendar.range(of: .day, in: .month, for: targetDate) {
            let maxDay = range.count
            components.day = min(day, maxDay)
        }
        
        return calendar.date(from: components)
    }
    
    /// 账单日补全（返回 YYYY-MM-DD 字符串）
    public static func completeAccountBillDate(_ accountBillDate: String, dateType: String = "current") -> String {
        guard !accountBillDate.isEmpty else { return "" }
        let offset = dateType == "next" ? 1 : 0
        guard let date = completeDay(dayString: accountBillDate, monthOffset: offset) else { return "" }
        return isoFormatter.string(from: date)
    }
    
    /// 还款日补全（返回 YYYY-MM-DD 字符串）
    public static func completeDueDate(accountBillDate: String, dueDate: String, dateType: String = "current") -> String {
        guard !accountBillDate.isEmpty, !dueDate.isEmpty else { return "" }
        
        let offset = dateType == "next" ? 1 : 0
        guard completeDay(dayString: accountBillDate, monthOffset: offset) != nil else { return "" }
        
        guard let billDayNum = Int(accountBillDate), let dueDayNum = Int(dueDate) else { return "" }
        
        // 还款日数字如果小于账单日数字，说明还款日在账单日跨月的下一月
        let dueMonthOffset = dueDayNum < billDayNum ? offset + 1 : offset
        guard let dueDateObj = completeDay(dayString: dueDate, monthOffset: dueMonthOffset) else { return "" }
        
        return isoFormatter.string(from: dueDateObj)
    }
    
    /// 计算最长免息期天数 (100% 完美对齐并同步 Web 端/移动端 CardUtils.calculateInterestFreePeriod 算法)
    public static func calculateInterestFreePeriod(
        accountBillDate: String,
        dueDate: String,
        billingDayToNextBill: Bool = true
    ) -> Int {
        guard !accountBillDate.isEmpty, !dueDate.isEmpty else { return 0 }
        
        guard let billDate = Int(accountBillDate),
              let dueDateNum = Int(dueDate) else {
            return 0
        }
        
        // 基础免息期计算：从账单日次日到还款日
        var baseDays = 0
        if dueDateNum > billDate {
            baseDays = dueDateNum - billDate
        } else {
            // 跨月情况：账单日到月底 + 还款日
            let daysInMonth = 31 // 简化处理，使用最大天数
            baseDays = (daysInMonth - billDate) + dueDateNum
        }
        
        // 根据账单日消费配置调整
        var maxDays = baseDays
        if billingDayToNextBill {
            // 如果账单日消费计入下期，最长免息期包含整个账单周期
            maxDays = baseDays + 30 // 一般为50-56天
        }
        
        // 限制在合理范围内
        maxDays = min(max(maxDays, 20), 56)
        
        return maxDays
    }

    /// 按“今天消费”计算当前可用免息天数，用于优惠用卡实时推荐。
    public static func calculateInterestFreeDays(card: SharedCard, today: Date = Date()) -> Int {
        WalletCardRules.interestFreeDays(card, today: today)
    }
    
    /// 计算上期账单还款剩余天数 (对应 Web 端 calculateRemainingDaysForPreviousBill)
    public static func calculateRemainingDaysForPreviousBill(accountBillDate: String, dueDate: String) -> Int {
        guard !accountBillDate.isEmpty, !dueDate.isEmpty else { return 0 }
        
        let today = Date()
        let todayString = isoFormatter.string(from: today)
        let currentDueDate = completeDueDate(accountBillDate: accountBillDate, dueDate: dueDate, dateType: "current")
        
        if todayString > currentDueDate {
            return 0
        }
        return getDaysDifference(date1Str: todayString, date2Str: currentDueDate)
    }
    
    /// 检查是否接近年费收取时间（60天内）
    public static func isNearAnnualFeeDate(_ nextAnnualFeeDate: String?, warningDays: Int = 60) -> Bool {
        guard let feeDateStr = nextAnnualFeeDate, !feeDateStr.isEmpty else { return false }
        
        let today = Date()
        let todayStr = isoFormatter.string(from: today)
        
        guard let d1 = isoFormatter.date(from: todayStr),
              let d2 = isoFormatter.date(from: feeDateStr) else {
            return false
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: d1, to: d2)
        let remainingDays = components.day ?? 0
        
        return remainingDays <= warningDays && remainingDays >= 0
    }

    /// 检查是否接近年费收取时间（60天内）
    public static func isNearAnnualFeeTimestamp(_ nextAnnualFeeDate: Double?, warningDays: Int = 60) -> Bool {
        guard let remainingDays = annualFeeRemainingDays(nextAnnualFeeDate) else { return false }
        return remainingDays <= warningDays && remainingDays >= 0
    }
    
    /// 按 Web 端 Math.ceil((扣费日 - 当前时间) / 1天) 的方式计算年费剩余天数
    public static func annualFeeRemainingDays(_ nextAnnualFeeDate: Double?, now: Date = Date()) -> Int? {
        guard let targetDate = date(fromTimestamp: nextAnnualFeeDate) else { return nil }
        return Int(ceil(targetDate.timeIntervalSince(now) / (24 * 60 * 60)))
    }
    
    /// Web 端年费检测逻辑：未达标未来卡、60天内临近卡、近60天已过期卡
    public static func annualFeeDetection(
        isQualified: String?,
        nextAnnualFeeDate: Double?,
        warningDays: Int = 60,
        now: Date = Date()
    ) -> AnnualFeeDetectionResult? {
        guard isQualified != "3",
              let diffDays = annualFeeRemainingDays(nextAnnualFeeDate, now: now) else {
            return nil
        }
        
        if isQualified == "2", diffDays <= warningDays, diffDays > 0 {
            return AnnualFeeDetectionResult(kind: .unqualified, days: diffDays)
        }
        
        if diffDays <= warningDays, diffDays > 0, isQualified != "2" {
            return AnnualFeeDetectionResult(kind: .warning, days: diffDays)
        }
        
        if diffDays <= 0, diffDays > -warningDays {
            return AnnualFeeDetectionResult(kind: .overdue, days: abs(diffDays))
        }
        
        return nil
    }
    
    public static func annualFeeDetection(
        for card: SharedCard,
        warningDays: Int = 60,
        now: Date = Date()
    ) -> AnnualFeeDetectionResult? {
        guard card.cardCategory != "debit" else { return nil }
        return annualFeeDetection(
            isQualified: card.isQualified,
            nextAnnualFeeDate: card.nextAnnualFeeCollectionTime,
            warningDays: warningDays,
            now: now
        )
    }
    
    /// 计算给定日期距今的天数，并返回天数和状态词
    public static func getDaysFromNow(_ dateStr: String?) -> (days: Int, text: String) {
        guard let targetStr = dateStr, !targetStr.isEmpty else { return (0, "") }
        
        let today = Date()
        let todayStr = isoFormatter.string(from: today)
        
        guard let d1 = isoFormatter.date(from: todayStr),
              let d2 = isoFormatter.date(from: targetStr) else {
            return (0, "")
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: d1, to: d2)
        let diffDays = components.day ?? 0
        
        return (abs(diffDays), diffDays >= 0 ? "还有" : "已过")
    }

    /// 计算给定时间戳距今的天数，并返回天数和状态词
    public static func getDaysFromNow(_ timestamp: Double?) -> (days: Int, text: String) {
        guard let targetDate = date(fromTimestamp: timestamp) else { return (0, "") }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: today, to: target)
        let diffDays = components.day ?? 0

        return (abs(diffDays), diffDays >= 0 ? "还有" : "已过")
    }
    
    /// 有效期格式 MM/YY 转换
    public static func formatValidDate(_ dateStr: String?) -> String {
        return DataMigrationManager.convertValidToMMYY(dateStr)
    }
    
    /// Web 端卡片有效期检测逻辑：MM/YY 按该月第一天作为到期日期，6个月内视为即将到期
    public static func cardExpiryStatus(valid: String?, now: Date = Date()) -> CardExpiryStatus? {
        let normalized = DataMigrationManager.convertValidToMMYY(valid)
        guard !normalized.isEmpty else { return nil }
        
        let parts = normalized.split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let year = Int(parts[1]),
              (1...12).contains(month) else {
            return nil
        }
        
        var components = DateComponents()
        components.year = 2000 + year
        components.month = month
        components.day = 1
        
        guard let expiryDate = Calendar.current.date(from: components),
              let sixMonthsLater = Calendar.current.date(byAdding: .month, value: 6, to: now) else {
            return nil
        }
        
        if expiryDate < now {
            return .expired
        }
        if expiryDate < sixMonthsLater {
            return .soonExpiring
        }
        return .normal
    }
    
    public static func cardExpiryStats(for cards: [SharedCard], now: Date = Date()) -> CardExpiryStats {
        var expiredCards = 0
        var soonExpiring = 0
        var normalCards = 0
        
        for card in cards {
            switch cardExpiryStatus(valid: card.valid, now: now) {
            case .expired:
                expiredCards += 1
            case .soonExpiring:
                soonExpiring += 1
            case .normal:
                normalCards += 1
            case .none:
                continue
            }
        }
        
        return CardExpiryStats(
            expiredCards: expiredCards,
            soonExpiring: soonExpiring,
            normalCards: normalCards
        )
    }

    public static func billingCycleReminders(
        for card: SharedCard,
        now: Date = Date(),
        billWarningDays: Int = DateCalculator.billWarningDays,
        repaymentWarningDays: Int = DateCalculator.repaymentWarningDays
    ) -> [BillingCycleReminderResult] {
        guard card.cardCategory != "debit" else { return [] }

        var reminders: [BillingCycleReminderResult] = []

        if let billDate = nextBillDate(accountBillDate: card.accountBillDate, now: now),
           let days = daysUntil(billDate, now: now),
           days >= 0,
           days <= billWarningDays {
            reminders.append(
                BillingCycleReminderResult(
                    kind: .bill,
                    days: days,
                    date: billDate,
                    title: days == 0 ? "今天是账单日" : "\(days) 天后账单日"
                )
            )
        }

        if let dueDate = nextDueDate(accountBillDate: card.accountBillDate, dueDate: card.dueDate, now: now),
           let days = daysUntil(dueDate, now: now),
           days >= 0,
           days <= repaymentWarningDays {
            reminders.append(
                BillingCycleReminderResult(
                    kind: .repayment,
                    days: days,
                    date: dueDate,
                    title: days == 0 ? "今天是还款日" : "\(days) 天后还款日"
                )
            )
        }

        return reminders
    }

    public static func billingCycleReminderItems(
        for cards: [SharedCard],
        now: Date = Date()
    ) -> [(card: SharedCard, reminder: BillingCycleReminderResult)] {
        cards.flatMap { card in
            billingCycleReminders(for: card, now: now).map { reminder in
                (card: card, reminder: reminder)
            }
        }
        .sorted { lhs, rhs in
            let lhsPriority = lhs.reminder.kind == .repayment ? 0 : 1
            let rhsPriority = rhs.reminder.kind == .repayment ? 0 : 1
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.reminder.days != rhs.reminder.days { return lhs.reminder.days < rhs.reminder.days }
            return lhs.card.bank < rhs.card.bank
        }
    }

    public static func analyzeDataQuality(cards: [SharedCard]) -> [DataQualityIssue] {
        var issues: [DataQualityIssue] = []
        var numberGroups: [String: [SharedCard]] = [:]

        func trimmed(_ value: String?) -> String {
            (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func cardName(_ card: SharedCard) -> String {
            let bank = trimmed(card.bank).isEmpty ? "未知银行" : card.bank
            let alias = trimmed(card.alias).isEmpty ? "未命名卡片" : trimmed(card.alias)
            return "\(bank) - \(alias)"
        }

        func add(_ severity: String, _ title: String, _ detail: String, card: SharedCard? = nil) {
            issues.append(
                DataQualityIssue(
                    severity: severity,
                    title: title,
                    detail: detail,
                    cardName: card.map(cardName) ?? ""
                )
            )
        }

        for card in cards {
            let cleanNumber = String(card.cardNumber.filter { $0.isNumber })
            if cleanNumber.isEmpty {
                add("严重", "卡号缺失", "无法用于验卡或重复检测。", card: card)
            } else {
                numberGroups[cleanNumber, default: []].append(card)
            }

            if trimmed(card.bank).isEmpty {
                add("警告", "银行缺失", "建议补全发卡银行，便于统计和同步审计。", card: card)
            }

            if !trimmed(card.valid).isEmpty, cardExpiryStatus(valid: card.valid) == nil {
                add("严重", "有效期格式异常", "当前有效期为“\(card.valid ?? "")”，建议使用 MM/YY。", card: card)
            }

            if card.cardCategory != "debit" {
                let billDay = dayNumber(card.accountBillDate)
                let dueDay = dayNumber(card.dueDate)
                if trimmed(card.accountBillDate).isEmpty || trimmed(card.dueDate).isEmpty {
                    add("警告", "账单/还款配置缺失", "无法计算还款提醒和免息期。", card: card)
                } else {
                    if billDay == nil {
                        add("严重", "账单日非法", "账单日必须是 1-31 之间的数字。", card: card)
                    }
                    if dueDay == nil {
                        add("严重", "还款日非法", "还款日必须是 1-31 之间的数字。", card: card)
                    }
                }
                if card.isQualified != "3", card.nextAnnualFeeCollectionTime == nil {
                    add("警告", "年费日期缺失", "非终免年费卡片缺少下次年费收取时间。", card: card)
                }
            } else if !trimmed(card.accountBillDate).isEmpty ||
                        !trimmed(card.dueDate).isEmpty ||
                        (card.annualFee ?? 0) > 0 ||
                        card.nextAnnualFeeCollectionTime != nil {
                add("提示", "储蓄卡包含信用卡字段", "储蓄卡不会参与账单、还款和年费提醒，建议清理相关字段。", card: card)
            }
        }

        for group in numberGroups.values where group.count > 1 {
            add("严重", "卡号重复", group.map(cardName).joined(separator: "、"))
        }

        let sharedGroups = Dictionary(grouping: cards.filter { $0.cardCategory != "debit" && $0.isSharedLimit }) { card in
            "\(card.country)|\(card.bank)|\(card.type ?? "")"
        }

        for group in sharedGroups.values where group.count > 1 {
            let limits = Set(group.map { $0.limit ?? 0 })
            if limits.count > 1 {
                add(
                    "警告",
                    "共享额度不一致",
                    group.map { card in
                        "\(trimmed(card.alias).isEmpty ? "未命名卡片" : trimmed(card.alias))：\(card.limit ?? 0)"
                    }.joined(separator: "、")
                )
            }
        }

        let weight = ["严重": 0, "警告": 1, "提示": 2]
        return issues.sorted { (weight[$0.severity] ?? 9) < (weight[$1.severity] ?? 9) }
    }

    private static func dayNumber(_ value: String?) -> Int? {
        guard let day = Int((value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...31).contains(day) else {
            return nil
        }
        return day
    }

    private static func monthDayDate(day: Int, baseDate: Date, monthOffset: Int = 0) -> Date? {
        let calendar = Calendar.current
        let baseStart = calendar.startOfDay(for: baseDate)
        guard let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: baseStart) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month], from: targetMonth)
        guard let firstDay = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else {
            return nil
        }

        components.day = min(day, dayRange.count)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    private static func daysUntil(_ date: Date, now: Date) -> Int? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: target).day
    }

    private static func nextBillDate(accountBillDate: String?, now: Date) -> Date? {
        guard let day = dayNumber(accountBillDate),
              let current = monthDayDate(day: day, baseDate: now) else {
            return nil
        }
        return current >= Calendar.current.startOfDay(for: now) ? current : monthDayDate(day: day, baseDate: now, monthOffset: 1)
    }

    private static func dueDateForBillMonth(
        accountBillDate: String?,
        dueDate: String?,
        now: Date,
        monthOffset: Int = 0
    ) -> Date? {
        guard let billDay = dayNumber(accountBillDate),
              let dueDay = dayNumber(dueDate) else {
            return nil
        }
        let dueMonthOffset = monthOffset + (dueDay < billDay ? 1 : 0)
        return monthDayDate(day: dueDay, baseDate: now, monthOffset: dueMonthOffset)
    }

    private static func nextDueDate(accountBillDate: String?, dueDate: String?, now: Date) -> Date? {
        guard let current = dueDateForBillMonth(accountBillDate: accountBillDate, dueDate: dueDate, now: now) else {
            return nil
        }
        return current >= Calendar.current.startOfDay(for: now)
            ? current
            : dueDateForBillMonth(accountBillDate: accountBillDate, dueDate: dueDate, now: now, monthOffset: 1)
    }
}
