import Foundation

enum CardCategoryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "全部"
    case credit = "信用卡"
    case debit = "储蓄卡"
    var id: String { rawValue }
}

struct CardCatalogItem: Identifiable, Sendable {
    var id: String { card.id }
    let card: SharedCard
    let brand: CardBrand
    let interestFreeDays: Int?
    let needsAnnualReview: Bool
    let searchText: String

    init(card: SharedCard) {
        self.card = card
        brand = CardBrand.detect(from: card.cardNumber, level: card.level)
        if card.cardCategory != "debit", let bill = Int(card.accountBillDate ?? ""), let due = Int(card.dueDate ?? ""), (1...31).contains(bill), (1...31).contains(due) {
            interestFreeDays = DateCalculator.calculateInterestFreePeriod(accountBillDate: String(bill), dueDate: String(due), billingDayToNextBill: card.billingDaySpendingToNextBill)
        } else {
            interestFreeDays = nil
        }
        needsAnnualReview = DateCalculator.annualFeeDetection(for: card) != nil
        searchText = CardSearch.index(card)
    }
}

struct CardCatalogQuery: Equatable, Sendable {
    var search = ""
    var bank = ""
    var category: CardCategoryFilter = .all
    var group: GroupOption = .none
    var sort: SortOption = .limitDesc
    var favoritesOnly = false
    var favoriteIDs: Set<String> = []
}

struct CardCatalogGroup: Identifiable, Sendable {
    let id: String
    let title: String
    let items: [CardCatalogItem]
    let limits: [String: Double]
}

enum CardCatalog {
    static func groups(items: [CardCatalogItem], query: CardCatalogQuery) -> [CardCatalogGroup] {
        let search = query.search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = items.filter { item in
            let categoryMatches = query.category == .all || (query.category == .debit) == (item.card.cardCategory == "debit")
            let bankMatches = query.bank.isEmpty || BankNameNormalizer.namesReferToSameBank(query.bank, item.card.bank)
            return categoryMatches && bankMatches && (!query.favoritesOnly || query.favoriteIDs.contains(item.id)) && CardSearch.matches(index: item.searchText, query: search)
        }
        let sorted = filtered.sorted { a, b in
            CardSearch.precedes(a.card, b.card, mode: query.sort.contractKey,
                leftDays: a.interestFreeDays ?? -1, rightDays: b.interestFreeDays ?? -1)
        }
        let grouped = Dictionary(grouping: sorted) { item in
            switch query.group {
            case .none: return ""
            case .bank: return BankNameNormalizer.normalizedKey(item.card.bank)
            case .brand: return NSLocalizedString(item.brand.displayName, comment: "")
            case .country: return item.card.country.isEmpty ? String(localized: "其他国家或地区") : item.card.country
            case .level: return item.card.level?.isEmpty == false ? item.card.level! : String(localized: "未填写等级")
            }
        }
        return grouped.map { CardCatalogGroup(id: $0.key, title: query.group == .bank ? BankNameNormalizer.groupDisplayName($0.value.map { $0.card.bank }) : $0.key, items: $0.value, limits: creditLimits(cards: $0.value.map(\.card))) }
            .sorted { $0.items.count != $1.items.count ? $0.items.count > $1.items.count : $0.id < $1.id }
    }

    /// 共享额度取同银行、地区和币种的最大值，与卡片排列顺序无关。
    static func creditLimits(cards: [SharedCard]) -> [String: Double] {
        CardMetrics.creditLimits(cards: cards)
    }
}
