import Foundation

/// Contract v1: currency-separated credit pools and Gregorian civil-day calculations.
public enum WalletCardRules {
    public struct CreditPool: Hashable, Sendable {
        public let country: String
        public let bank: String
        public let currency: String
    }

    public static func currency(_ card: SharedCard) -> String {
        (card.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    public static func pool(_ card: SharedCard) -> CreditPool {
        CreditPool(country: card.country.trimmingCharacters(in: .whitespacesAndNewlines),
                   bank: BankNameNormalizer.normalizedKey(card.bank), currency: currency(card))
    }

    private static func cents(_ value: Double?) -> Decimal {
        guard let value, value.isFinite, value >= 0 else { return 0 }
        var amount = Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? 0
        amount *= 100
        var result = Decimal()
        NSDecimalRound(&result, &amount, 0, .plain)
        return result
    }

    public static func creditLimits(_ cards: [SharedCard]) -> [String: Double] {
        var shared: [CreditPool: Decimal] = [:]
        var totals: [String: Decimal] = [:]
        for card in cards where card.cardCategory != "debit" {
            let key = pool(card), amount = cents(card.limit)
            if card.isSharedLimit && !key.bank.isEmpty {
                shared[key] = max(shared[key] ?? 0, amount)
            } else {
                totals[key.currency, default: 0] += amount
            }
        }
        for (key, amount) in shared { totals[key.currency, default: 0] += amount }
        return totals.mapValues { NSDecimalNumber(decimal: $0 / 100).doubleValue }
    }

    /// Remaining interest-free days for a purchase today; invalid/debit cards return -1.
    public static func interestFreeDays(_ card: SharedCard, today: Date = Date(), timeZone: TimeZone = .current) -> Int {
        guard card.cardCategory != "debit",
              let bill = Int((card.accountBillDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)),
              let due = Int((card.dueDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...31).contains(bill), (1...31).contains(due) else { return -1 }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let day = cal.startOfDay(for: today)
        guard let month = cal.date(from: cal.dateComponents([.year, .month], from: day)),
              let range = cal.range(of: .day, in: .month, for: month) else { return -1 }
        let actualBill = min(bill, range.count), spend = cal.component(.day, from: day)
        let next = card.billingDaySpendingToNextBill ? spend >= actualBill : spend > actualBill
        guard let billMonth = cal.date(byAdding: .month, value: next ? 1 : 0, to: month),
              let dueMonth = cal.date(byAdding: .month, value: due <= bill ? 1 : 0, to: billMonth),
              let dueRange = cal.range(of: .day, in: .month, for: dueMonth),
              let target = cal.date(byAdding: .day, value: min(due, dueRange.count) - 1, to: dueMonth) else { return -1 }
        return max(0, cal.dateComponents([.day], from: day, to: target).day ?? 0)
    }

    public static func settingAnnualStatus(_ status: String, for card: SharedCard, now: Date = Date()) -> SharedCard {
        guard card.cardCategory != "debit" else { return card }
        if status == "1", card.isQualified == "1", DateCalculator.annualFeeDetection(for: card, now: now) == nil { return card }
        var result = card
        result.isQualified = status
        if status == "1" { result.nextAnnualFeeCollectionTime = DateCalculator.timestampByAddingOneYear(card.nextAnnualFeeCollectionTime) }
        if status == "3" { result.nextAnnualFeeCollectionTime = nil }
        result.lastModifyTime = now.timeIntervalSince1970 * 1000
        return result
    }

    /// Display fields only: never index CVV, image data, passwords or sync credentials.
    public static func searchText(_ card: SharedCard) -> String {
        let category = card.cardCategory == "debit" ? "储蓄卡 儲蓄卡 debit" : "信用卡 credit"
        var fields: [String] = [card.bank, card.cardNumber, card.country, category]
        fields.append(card.alias ?? "")
        fields.append(card.level ?? "")
        fields.append(card.type ?? "")
        fields.append(card.equity ?? "")
        fields.append(card.remark ?? "")
        fields.append(String(card.limit ?? 0))
        fields.append(CardBrand.detect(from: card.cardNumber, level: card.level).displayName)
        return fields.joined(separator: "\n").lowercased()
    }

    public static func matches(_ card: SharedCard, query: String, index: String? = nil) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.isEmpty { return true }
        let compact = text.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression)
        guard !compact.isEmpty else { return false }
        let isNumber = compact.unicodeScalars.allSatisfy { (48...57).contains($0.value) }
        let number = card.cardNumber.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression)
        return (index ?? searchText(card)).contains(text) || (isNumber && number.contains(compact))
    }

    public static func sorted(_ cards: [SharedCard], key: String, today: Date = Date(), timeZone: TimeZone = .current) -> [SharedCard] {
        let rows = cards.map { card in
            (card: card, days: key.hasPrefix("interest-") ? interestFreeDays(card, today: today, timeZone: timeZone) : 0)
        }
        return rows.sorted { a, b in
            switch key {
            case "limit-asc", "limit-desc":
                let left = a.card.cardCategory == "debit" ? 0 : max(0, a.card.limit ?? 0)
                let right = b.card.cardCategory == "debit" ? 0 : max(0, b.card.limit ?? 0)
                if left != right { return key == "limit-asc" ? left < right : left > right }
            case "interest-asc", "interest-desc":
                if a.days < 0 && b.days >= 0 { return false }
                if a.days >= 0 && b.days < 0 { return true }
                if a.days != b.days { return key == "interest-asc" ? a.days < b.days : a.days > b.days }
            case "modifyTime":
                if a.card.lastModifyTime != b.card.lastModifyTime { return a.card.lastModifyTime > b.card.lastModifyTime }
            default:
                for (left, right) in [(a.card.country, b.card.country), (a.card.bank, b.card.bank), (a.card.alias ?? "", b.card.alias ?? "")] {
                    if left != right { return left < right }
                }
            }
            return a.card.id < b.card.id
        }.map { $0.card }
    }
}
