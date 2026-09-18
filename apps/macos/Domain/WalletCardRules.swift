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
}
