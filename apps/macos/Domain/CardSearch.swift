import Foundation

/// Only searchable presentation fields enter the index; never CVV, images or synchronization secrets.
public enum CardSearch {
    public static func index(_ card: SharedCard) -> String {
        let amount = (card.limit?.isFinite == true) ? NSDecimalNumber(value: card.limit!).stringValue : ""
        let category = card.cardCategory == "debit" ? "储蓄卡 儲蓄卡 debit" : "信用卡 credit"
        var fields: [String] = [card.bank, BankNameNormalizer.normalizedKey(card.bank), card.alias ?? "", card.cardNumber]
        fields.append(String(card.cardNumber.filter { $0 >= "0" && $0 <= "9" }))
        fields.append(contentsOf: [card.level ?? "", card.type ?? "", card.country])
        fields.append(contentsOf: [card.equity ?? "", card.remark ?? "", amount, category])
        fields.append(CardBrand.detect(from: card.cardNumber, level: card.level).displayName)
        return fields.joined(separator: "\u{001f}").lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    public static func matches(index: String, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale(identifier: "en_US_POSIX"))
        if query.isEmpty { return true }
        if index.contains(query) { return true }
        let compact = query.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression)
        return !compact.isEmpty && compact.utf8.allSatisfy { (48...57).contains($0) } && index.contains(compact)
    }

    public static func matches(_ card: SharedCard, query: String) -> Bool { matches(index: index(card), query: query) }

    public static func precedes(_ a: SharedCard, _ b: SharedCard, mode: String, leftDays: Int = -1, rightDays: Int = -1) -> Bool {
        func limit(_ card: SharedCard) -> Double {
            guard card.cardCategory != "debit", let value = card.limit, value.isFinite else { return 0 }
            return max(0, value)
        }
        switch mode {
        case "limit-asc", "limit-desc":
            let left = limit(a), right = limit(b)
            if left != right { return mode == "limit-asc" ? left < right : left > right }
        case "interest-asc", "interest-desc":
            if (leftDays < 0) != (rightDays < 0) { return rightDays < 0 }
            if leftDays != rightDays { return mode == "interest-asc" ? leftDays < rightDays : leftDays > rightDays }
        case "modified-desc":
            if a.lastModifyTime != b.lastModifyTime { return a.lastModifyTime > b.lastModifyTime }
        case "bank-asc":
            let left = BankNameNormalizer.normalizedKey(a.bank), right = BankNameNormalizer.normalizedKey(b.bank)
            if left != right { return left < right }
        default: break
        }
        return a.id < b.id
    }

    public static func sorted(_ cards: [SharedCard], mode: String, today: Date = Date()) -> [SharedCard] {
        let days = mode.hasPrefix("interest-") ? Dictionary(cards.map { ($0.id, DateCalculator.calculateInterestFreeDays(card: $0, today: today)) }, uniquingKeysWith: { first, _ in first }) : [:]
        return cards.sorted { precedes($0, $1, mode: mode, leftDays: days[$0.id] ?? -1, rightDays: days[$1.id] ?? -1) }
    }
}

extension SortOption {
    var contractKey: String {
        switch self {
        case .limitAsc: return "limit-asc"
        case .limitDesc: return "limit-desc"
        case .daysAsc: return "interest-asc"
        case .daysDesc: return "interest-desc"
        case .lastModify: return "modified-desc"
        }
    }
}
