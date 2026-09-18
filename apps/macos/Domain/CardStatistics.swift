import Foundation

struct CardStatistics {
    struct BankLimit: Identifiable {
        var id: String { bank + "|" + currency }
        let bank: String
        let currency: String
        let amount: Double
    }
    struct DatedCard: Identifiable {
        var id: String { card.id }
        let card: SharedCard
        let days: Int
    }

    let cards: [SharedCard]
    let creditCards: [SharedCard]
    let debitCards: [SharedCard]
    let totalLimits: [String: Double]
    let bankLimits: [BankLimit]
    let pendingFees: [DatedCard]
    let oldLimitUpdates: [DatedCard]
    let lowLimitCards: [SharedCard]
    let annualFees: [String: Double]
    let generatedAt: Date

    init(cards: [SharedCard], now: Date = Date()) {
        self.cards = cards
        generatedAt = now
        creditCards = cards.filter { $0.cardCategory != "debit" }
        debitCards = cards.filter { $0.cardCategory == "debit" }
        totalLimits = CardCatalog.creditLimits(cards: cards)
        let banks: [String: [SharedCard]] = Dictionary(grouping: cards) { BankNameNormalizer.normalizedKey($0.bank) }
        var bankAmounts: [BankLimit] = []
        for bankCards in banks.values {
            let name = BankNameNormalizer.groupDisplayName(bankCards.map(\.bank))
            for (currency, amount) in CardCatalog.creditLimits(cards: bankCards) where amount > 0 {
                bankAmounts.append(BankLimit(bank: name, currency: currency, amount: amount))
            }
        }
        bankLimits = bankAmounts.sorted { left, right in
            left.amount == right.amount ? left.id < right.id : left.amount > right.amount
        }

        func dayDifference(_ timestamp: Double?, toToday: Bool) -> Int? {
            guard let date = timestamp.flatMap({ DataMigrationManager.date(fromTimestamp: $0) }) else { return nil }
            let calendar = Calendar.current
            let current = calendar.startOfDay(for: now), target = calendar.startOfDay(for: date)
            return calendar.dateComponents([.day], from: toToday ? target : current, to: toToday ? current : target).day
        }
        pendingFees = creditCards.compactMap { card in
            guard Self.feeStatus(card) == "2", let days = dayDifference(card.nextAnnualFeeCollectionTime, toToday: false), (0...60).contains(days) else { return nil }
            return DatedCard(card: card, days: days)
        }.sorted { $0.days < $1.days }
        oldLimitUpdates = creditCards.compactMap { card in
            guard let days = dayDifference(card.lastTime, toToday: true), days >= 180 else { return nil }
            return DatedCard(card: card, days: days)
        }.sorted { $0.days > $1.days }
        let thresholds: [String: Double] = ["CNY": 5000, "USD": 800, "HKD": 6000, "EUR": 800, "JPY": 100000]
        lowLimitCards = creditCards.filter { card in
            guard let limit = card.limit else { return false }
            return limit < (thresholds[Self.currency(card)] ?? 5000)
        }.sorted { ($0.limit ?? 0) < ($1.limit ?? 0) }
        annualFees = creditCards.filter { Self.feeStatus($0) == "2" }.reduce(into: [:]) { result, card in
            result[Self.currency(card), default: 0] += card.annualFee ?? 0
        }
    }

    var bankCount: Int { Set(cards.map { BankNameNormalizer.normalizedKey($0.bank) }).count }
    var currencies: [String] { totalLimits.keys.sorted { $0 == $1 ? false : $0 == "CNY" ? true : $1 == "CNY" ? false : $0 < $1 } }
    var debitCountries: Int { Set(debitCards.map(\.country).filter { !$0.isEmpty }).count }
    var debitBanks: Int { Set(debitCards.map { BankNameNormalizer.normalizedKey($0.bank) }).count }
    var debitCurrencies: Int { Set(debitCards.compactMap { $0.type?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }.filter { !$0.isEmpty }).count }
    var dueDates: Set<String> { Set(creditCards.compactMap(\.dueDate).filter { !$0.isEmpty }) }
    func cards(withFeeStatus status: String) -> [SharedCard] { creditCards.filter { Self.feeStatus($0) == status } }
    static func feeStatus(_ card: SharedCard) -> String { card.isQualified == "1" ? "1" : card.isQualified == "3" ? "3" : "2" }
    static func currency(_ card: SharedCard) -> String { CardMetrics.currency(card) }

    static func csvRow(_ fields: [String]) -> String {
        fields.map { field in
            let safe = ["=", "+", "-", "@"].contains(String(field.prefix(1))) ? "'" + field : field
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }.joined(separator: ",") + "\n"
    }
}
