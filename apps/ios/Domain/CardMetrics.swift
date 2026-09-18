import Foundation

/// Business rules v1; fixture contract lives in contracts/card-wallet. No exchange-rate conversion.
public enum CardMetrics {
    public struct PoolKey: Hashable, Sendable {
        public let country: String
        public let bank: String
        public let currency: String
    }

    public static func currency(_ card: SharedCard) -> String {
        (card.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    public static func poolKey(_ card: SharedCard) -> PoolKey {
        PoolKey(country: card.country.trimmingCharacters(in: .whitespacesAndNewlines),
                bank: BankNameNormalizer.normalizedKey(card.bank), currency: currency(card))
    }

    private static func money(_ value: Double?) -> Decimal {
        guard let value, value.isFinite, value >= 0,
              var decimal = Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) else { return 0 }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &decimal, 2, .plain)
        return rounded
    }

    public static func creditLimits(cards: [SharedCard]) -> [String: Double] {
        var sums: [String: Decimal] = [:]
        var pools: [PoolKey: Decimal] = [:]
        for card in cards where card.cardCategory != "debit" {
            let amount = money(card.limit)
            if card.isSharedLimit {
                let key = poolKey(card)
                pools[key] = max(pools[key] ?? 0, amount)
            } else {
                sums[currency(card), default: 0] += amount
            }
        }
        for (key, amount) in pools { sums[key.currency, default: 0] += amount }
        return sums.mapValues { NSDecimalNumber(decimal: $0).doubleValue }
    }
}
