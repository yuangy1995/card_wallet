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
        if isQualified == "2", diffDays > 0 { return AnnualFeeDetectionResult(kind: .unqualified, days: diffDays) }
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
}
