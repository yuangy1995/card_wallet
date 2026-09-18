import Foundation

enum CardEditing {
    static func applySubmission(_ submitted: SharedCard, previous: SharedCard?, to cards: [SharedCard], now: Date = Date()) -> [SharedCard] {
        var result = cards
        var card = submitted
        if let previous {
            guard let index = result.firstIndex(where: { $0.id == card.id }) else { return result }
            if previous.isQualified != "1" && card.isQualified == "1" {
                card.nextAnnualFeeCollectionTime = DateCalculator.timestampByAddingOneYear(card.nextAnnualFeeCollectionTime)
            }
            if previous.bank != card.bank {
                for position in result.indices where result[position].id != card.id && BankNameNormalizer.namesReferToSameBank(result[position].bank, previous.bank) {
                    result[position].bank = card.bank
                    result[position].lastModifyTime = DateCalculator.timestamp(from: now)
                }
            }
            result[index] = card
        } else {
            result.append(card)
        }
        if card.cardCategory != "debit" && card.isSharedLimit {
            for index in result.indices where result[index].id != card.id && result[index].cardCategory != "debit" && result[index].isSharedLimit {
                if result[index].country == card.country,
                   CardStatistics.currency(result[index]) == CardStatistics.currency(card),
                   BankNameNormalizer.namesReferToSameBank(result[index].bank, card.bank) {
                    result[index].limit = card.limit
                    result[index].lastModifyTime = DateCalculator.timestamp(from: now)
                }
            }
        }
        return result
    }

    static func settingAnnualStatus(_ status: String, for card: SharedCard, now: Date = Date()) -> SharedCard {
        WalletCardRules.settingAnnualStatus(status, for: card, now: now)
    }
}
