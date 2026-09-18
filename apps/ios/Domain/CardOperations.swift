import Foundation

public struct CardBatchUpdate {
    public var status: String?
    public var annualFee: Double?
    public var nextAnnualFeeDate: Double?
    public var valid: String?
    public var cardCategory: String?
    public init(status: String? = nil, annualFee: Double? = nil, nextAnnualFeeDate: Double? = nil, valid: String? = nil, cardCategory: String? = nil) {
        self.status = status; self.annualFee = annualFee; self.nextAnnualFeeDate = nextAnnualFeeDate
        self.valid = valid; self.cardCategory = cardCategory
    }
}

public enum CardOperations {
    public static func annualStatus(_ status: String, card: SharedCard, now: Date = Date()) -> SharedCard {
        guard card.cardCategory != "debit", ["1", "2", "3"].contains(status) else { return card }
        if status == "1", card.isQualified == "1", DateCalculator.annualFeeDetection(for: card, now: now) == nil { return card }
        var result = card
        result.isQualified = status
        if status == "1" { result.nextAnnualFeeCollectionTime = DateCalculator.timestampByAddingOneYear(card.nextAnnualFeeCollectionTime) }
        if status == "3" { result.nextAnnualFeeCollectionTime = nil }
        if result != card { result.lastModifyTime = now.timeIntervalSince1970 * 1000 }
        return result
    }

    /// Explicit next-date editing wins over the convenience one-year advance. Debit values are retained, not erased.
    public static func batch(_ cards: [SharedCard], ids: Set<String>, update: CardBatchUpdate, now: Date = Date()) -> [SharedCard] {
        cards.map { card in
            guard ids.contains(card.id) else { return card }
            var result = card
            if let category = update.cardCategory { result.cardCategory = category == "debit" ? "debit" : "credit" }
            if result.cardCategory != "debit" {
                if let status = update.status, ["1", "2", "3"].contains(status) {
                    if status == "1" && update.nextAnnualFeeDate == nil { result = annualStatus(status, card: result, now: now) }
                    else { result.isQualified = status }
                }
                if let fee = update.annualFee, fee.isFinite && fee >= 0 { result.annualFee = fee }
                if result.isQualified == "3" { result.nextAnnualFeeCollectionTime = nil }
                else if let date = update.nextAnnualFeeDate { result.nextAnnualFeeCollectionTime = date }
            }
            if let valid = update.valid { result.valid = valid }
            if result != card { result.lastModifyTime = now.timeIntervalSince1970 * 1000 }
            return result
        }
    }
}
