import Foundation

/// 7大银行卡组织品牌枚举
public enum CardBrand: String, Codable, CaseIterable, Sendable {
    case visa
    case mastercard
    case amex
    case discover
    case dinersClub
    case unionpay
    case jcb
    case unknown

    /// 根据卡号实时侦测卡组织品牌的高精度正则算法
    public static func detect(from cardNumber: String, level: String? = nil) -> CardBrand {
        if let level {
            let value = level.lowercased()
            let words = Set(value.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
            var hints = Set<CardBrand>()
            if value.contains("银联") || value.contains("銀聯") || words.contains("unionpay") { hints.insert(.unionpay) }
            if words.contains("discover") || value.contains("发现") || value.contains("發現") { hints.insert(.discover) }
            if words.contains("visa") { hints.insert(.visa) }
            if words.contains("mastercard") || value.contains("万事达") || value.contains("萬事達") { hints.insert(.mastercard) }
            if words.contains("jcb") { hints.insert(.jcb) }
            if !words.isDisjoint(with: ["amex", "ae"]) || value.contains("american express") || value.contains("运通") || value.contains("運通") { hints.insert(.amex) }
            if words.contains("diners") || value.contains("大莱") || value.contains("大萊") { hints.insert(.dinersClub) }
            if hints.count == 1, let hint = hints.first { return hint }
        }
        let digits = cardNumber.filter { $0 >= "0" && $0 <= "9" }
        guard let two = Int(digits.prefix(2)), let three = Int(digits.prefix(3)),
              let four = Int(digits.prefix(4)), digits.count >= 4 else { return .unknown }
        let count = digits.count
        if count == 15 && [34, 37].contains(two) { return .amex }
        if count == 16 && ((51...55).contains(two) || (2221...2720).contains(four)) { return .mastercard }
        if (16...19).contains(count) && (3528...3589).contains(four) { return .jcb }
        if (16...19).contains(count) && (four == 6011 || two == 65 || (644...649).contains(three)) { return .discover }
        if [13, 16, 19].contains(count) && digits.hasPrefix("4") { return .visa }
        // 62 is shared acceptance space, not evidence of Discover co-branding.
        if (16...19).contains(count) && [62, 81].contains(two) { return .unionpay }
        if count == 14 && ((300...305).contains(three) || [36, 38, 39].contains(two)) { return .dinersClub }
        return .unknown
    }

    public var displayName: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "MasterCard"
        case .amex: return "Amex"
        case .discover: return "Discover"
        case .dinersClub: return "Diners Club"
        case .unionpay: return "银联"
        case .jcb: return "JCB"
        case .unknown: return "未知"
        }
    }
}

/// 卡片图片附件
public struct CardImageAsset: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var mimeType: String
    public var data: String
    public var createdAt: Double
    public var source: String
    public var name: String
    public var extraFields: [String: CardJSONValue] = [:]

    public init(
        id: String = UUID().uuidString,
        mimeType: String = "image/jpeg",
        data: String,
        createdAt: Double = DataMigrationManager.currentTimestampMilliseconds(),
        source: String = "ios_upload",
        name: String = "",
        extraFields: [String: CardJSONValue] = [:]
    ) {
        self.id = id
        self.mimeType = mimeType
        self.data = data
        self.createdAt = createdAt
        self.source = source
        self.name = name
        self.extraFields = extraFields
    }
    private enum CodingKeys: String, CodingKey, CaseIterable { case id, mimeType, data, createdAt, source, name }
    static let knownFieldNames = Set(CodingKeys.allCases.map(\.rawValue))
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType) ?? "image/jpeg"
        data = try container.decode(String.self, forKey: .data)
        createdAt = try container.decodeIfPresent(Double.self, forKey: .createdAt) ?? 0
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "manual"
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        extraFields = try CardFutureFields.decode(from: decoder, known: Self.knownFieldNames)
    }
    public func encode(to encoder: Encoder) throws {
        try CardFutureFields.encode(extraFields, to: encoder, known: Self.knownFieldNames)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(data, forKey: .data)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(source, forKey: .source)
        try container.encode(name, forKey: .name)
    }

}

/// 跨端同步主数据模型（与 Web 端 SharedCard 规范对齐）
public struct SharedCard: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var cardCategory: String
    public var country: String
    public var bank: String
    public var cardNumber: String
    public var alias: String?
    public var level: String?
    public var type: String?
    public var limit: Double?
    public var cvv: String?
    public var valid: String?
    public var annualFee: Double?
    public var isQualified: String?
    public var nextAnnualFeeCollectionTime: Double?
    public var lastTime: Double?
    public var accountBillDate: String?
    public var dueDate: String?
    public var billingDaySpendingToNextBill: Bool
    public var equity: String?
    public var remark: String?
    public var lastModifyTime: Double
    public var isSharedLimit: Bool
    public var cardImages: [CardImageAsset]
    public var extraFields: [String: CardJSONValue] = [:]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, cardCategory, country, bank, cardNumber, alias, level, type
        case limit, cvv, valid, annualFee, isQualified, nextAnnualFeeCollectionTime
        case lastTime, accountBillDate, dueDate, billingDaySpendingToNextBill
        case equity, remark, lastModifyTime, isSharedLimit, cardImages
    }

    static let knownFieldNames = Set(CodingKeys.allCases.map(\.rawValue))

    public init(
        id: String = UUID().uuidString,
        cardCategory: String = "credit",
        country: String,
        bank: String,
        cardNumber: String,
        alias: String? = nil,
        level: String? = nil,
        type: String? = "",
        limit: Double? = 0,
        cvv: String? = nil,
        valid: String? = nil,
        annualFee: Double? = 0,
        isQualified: String? = "2",
        nextAnnualFeeCollectionTime: Double? = nil,
        lastTime: Double? = nil,
        accountBillDate: String? = nil,
        dueDate: String? = nil,
        billingDaySpendingToNextBill: Bool = true,
        equity: String? = nil,
        remark: String? = nil,
        lastModifyTime: Double = DataMigrationManager.currentTimestampMilliseconds(),
        isSharedLimit: Bool = true,
        cardImages: [CardImageAsset] = [],
        extraFields: [String: CardJSONValue] = [:]
    ) {
        self.id = id
        self.cardCategory = Self.normalizeCardCategory(cardCategory)
        self.country = country
        self.bank = bank
        self.cardNumber = cardNumber
        self.alias = alias
        self.level = level
        self.type = type
        self.limit = limit
        self.cvv = cvv
        self.valid = valid
        self.annualFee = annualFee
        self.isQualified = isQualified
        self.nextAnnualFeeCollectionTime = nextAnnualFeeCollectionTime
        self.lastTime = lastTime
        self.accountBillDate = accountBillDate
        self.dueDate = dueDate
        self.billingDaySpendingToNextBill = billingDaySpendingToNextBill
        self.equity = equity
        self.remark = remark
        self.lastModifyTime = lastModifyTime
        self.isSharedLimit = isSharedLimit
        self.cardImages = cardImages
        self.extraFields = extraFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = Self.decodeString(container, forKey: .id) ?? UUID().uuidString
        self.cardCategory = Self.normalizeCardCategory(Self.decodeString(container, forKey: .cardCategory) ?? "credit")
        self.country = Self.decodeString(container, forKey: .country) ?? "中国"
        self.bank = Self.decodeString(container, forKey: .bank) ?? "未知银行"
        self.cardNumber = Self.decodeString(container, forKey: .cardNumber) ?? ""
        self.alias = Self.decodeString(container, forKey: .alias)
        self.level = Self.decodeString(container, forKey: .level)
        self.type = Self.decodeString(container, forKey: .type) ?? ""
        self.limit = Self.decodeDouble(container, forKey: .limit)
        self.cvv = Self.decodeString(container, forKey: .cvv)
        self.valid = Self.decodeString(container, forKey: .valid)
        self.annualFee = Self.decodeDouble(container, forKey: .annualFee)
        self.isQualified = Self.decodeString(container, forKey: .isQualified) ?? "2"
        self.nextAnnualFeeCollectionTime = Self.decodeTimestamp(container, forKey: .nextAnnualFeeCollectionTime)
        self.lastTime = Self.decodeTimestamp(container, forKey: .lastTime)
        self.accountBillDate = Self.decodeString(container, forKey: .accountBillDate)
        self.dueDate = Self.decodeString(container, forKey: .dueDate)
        self.billingDaySpendingToNextBill = Self.decodeBool(container, forKey: .billingDaySpendingToNextBill) ?? true
        self.equity = Self.decodeString(container, forKey: .equity)
        self.remark = Self.decodeString(container, forKey: .remark)
        self.lastModifyTime = Self.decodeTimestamp(container, forKey: .lastModifyTime) ?? DataMigrationManager.currentTimestampMilliseconds()
        self.isSharedLimit = Self.decodeBool(container, forKey: .isSharedLimit) ?? true
        self.cardImages = (try? container.decode([CardImageAsset].self, forKey: .cardImages)) ?? []
        self.extraFields = try CardFutureFields.decode(from: decoder, known: Self.knownFieldNames)
    }

    public func encode(to encoder: Encoder) throws {
        try CardFutureFields.encode(extraFields, to: encoder, known: Self.knownFieldNames)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(Self.normalizeCardCategory(cardCategory), forKey: .cardCategory)
        try container.encode(country, forKey: .country)
        try container.encode(bank, forKey: .bank)
        try container.encode(cardNumber, forKey: .cardNumber)
        try container.encodeIfPresent(alias, forKey: .alias)
        try container.encodeIfPresent(level, forKey: .level)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(limit, forKey: .limit)
        try container.encodeIfPresent(cvv, forKey: .cvv)
        try container.encodeIfPresent(valid, forKey: .valid)
        try container.encodeIfPresent(annualFee, forKey: .annualFee)
        try container.encodeIfPresent(isQualified, forKey: .isQualified)
        try container.encodeIfPresent(nextAnnualFeeCollectionTime, forKey: .nextAnnualFeeCollectionTime)
        try container.encodeIfPresent(lastTime, forKey: .lastTime)
        try container.encodeIfPresent(accountBillDate, forKey: .accountBillDate)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(billingDaySpendingToNextBill, forKey: .billingDaySpendingToNextBill)
        try container.encodeIfPresent(equity, forKey: .equity)
        try container.encodeIfPresent(remark, forKey: .remark)
        try container.encode(lastModifyTime, forKey: .lastModifyTime)
        try container.encode(isSharedLimit, forKey: .isSharedLimit)
        try container.encode(cardImages, forKey: .cardImages)
    }


    private static func normalizeCardCategory(_ value: String) -> String {
        value == "debit" ? "debit" : "credit"
    }

    private static func decodeString(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> String? {
        if let v = try? container.decode(String.self, forKey: key) { return v }
        if let v = try? container.decode(Int.self, forKey: key) { return String(v) }
        if let v = try? container.decode(Double.self, forKey: key) {
            return v.rounded() == v ? String(Int64(v)) : String(v)
        }
        return nil
    }

    private static func decodeDouble(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let v = try? container.decode(Double.self, forKey: key) { return v }
        if let v = try? container.decode(Int.self, forKey: key) { return Double(v) }
        if let v = try? container.decode(String.self, forKey: key) { return Double(v.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    private static func decodeTimestamp(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let v = try? container.decode(Double.self, forKey: key) { return DataMigrationManager.timestampMilliseconds(from: v) }
        if let v = try? container.decode(Int.self, forKey: key) { return DataMigrationManager.timestampMilliseconds(from: v) }
        if let v = try? container.decode(String.self, forKey: key) { return DataMigrationManager.timestampMilliseconds(from: v) }
        return nil
    }

    private static func decodeBool(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Bool? {
        if let v = try? container.decode(Bool.self, forKey: key) { return v }
        if let v = try? container.decode(Int.self, forKey: key) { return v != 0 }
        if let v = try? container.decode(String.self, forKey: key) {
            let lower = v.trimmingCharacters(in: .whitespaces).lowercased()
            if ["true","1","yes"].contains(lower) { return true }
            if ["false","0","no"].contains(lower) { return false }
        }
        return nil
    }
}

/// 分组方式
public enum GroupOption: String, CaseIterable, Identifiable, Sendable {
    case none = "无分组"
    case bank = "按发卡行"
    case brand = "按卡组织"
    case level = "按卡级别"
    case country = "按发卡国家"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .none: return "square.grid.2x2"
        case .bank: return "building.columns.fill"
        case .brand: return "creditcard.fill"
        case .level: return "crown.fill"
        case .country: return "globe"
        }
    }
}

/// 排序方式
public enum SortOption: String, CaseIterable, Identifiable, Sendable {
    case limitDesc = "额度从高到低"
    case limitAsc = "额度从低到高"
    case daysDesc = "免息期从长到短"
    case daysAsc = "免息期从短到长"
    case lastModify = "最近修改时间"

    public var contractKey: String {
        switch self {
        case .limitDesc: return "limit-desc"
        case .limitAsc: return "limit-asc"
        case .daysDesc: return "interest-desc"
        case .daysAsc: return "interest-asc"
        case .lastModify: return "modifyTime"
        }
    }

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .limitDesc: return "arrow.up.circle.fill"
        case .limitAsc: return "arrow.down.circle.fill"
        case .daysDesc: return "clock.fill"
        case .daysAsc: return "clock"
        case .lastModify: return "calendar.badge.clock"
        }
    }
}


/// Opaque future fields round-trip without becoming editable UI or changing SyncV4.
public enum CardJSONValue: Codable, Hashable, Sendable {
    case null, bool(Bool), string(String), number(Decimal), array([CardJSONValue]), object([String: CardJSONValue])
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode(Decimal.self) { self = .number(v) }
        else if let v = try? value.decode([CardJSONValue].self) { self = .array(v) }
        else { self = .object(try value.decode([String: CardJSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

struct CardJSONKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

enum CardFutureFields {
    static let transient: Set<String> = ["showCardNumber", "showCVV", "countryRowSpan", "showCountry", "bankRowSpan", "showBank", "limitRowSpan", "showLimit", "lastTimeRowSpan", "showLastTime", "cardId", "uuid", "legacyId", "annualFeeDate", "extraFields", "constructor", "prototype"]
    static func allowed(_ key: String) -> Bool { !key.hasPrefix("_") && !transient.contains(key) }
    static func decode(from decoder: Decoder, known: Set<String>) throws -> [String: CardJSONValue] {
        let container = try decoder.container(keyedBy: CardJSONKey.self)
        var fields: [String: CardJSONValue] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) && allowed(key.stringValue) {
            fields[key.stringValue] = try container.decode(CardJSONValue.self, forKey: key)
        }
        return fields
    }
    static func fromJSONObject(_ object: [String: Any], known: Set<String>) -> [String: CardJSONValue] {
        let fields = object.filter { !known.contains($0.key) && allowed($0.key) }
        guard JSONSerialization.isValidJSONObject(fields),
              let data = try? JSONSerialization.data(withJSONObject: fields),
              let decoded = try? JSONDecoder().decode([String: CardJSONValue].self, from: data) else { return [:] }
        return decoded
    }
    static func encode(_ fields: [String: CardJSONValue], to encoder: Encoder, known: Set<String>) throws {
        var container = encoder.container(keyedBy: CardJSONKey.self)
        for (name, value) in fields where !known.contains(name) && allowed(name) {
            try container.encode(value, forKey: CardJSONKey(name))
        }
    }
}
