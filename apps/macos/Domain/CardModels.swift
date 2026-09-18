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
    
    /// Explicit Mac level hints are preserved; number fallback follows Android's display rules.
    /// This is not a complete BIN lookup or a validation of card ownership.
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

    /// 获取品牌的展示名称
    public var displayName: String {
        switch self {
        case .visa: return "维萨卡 (Visa)"
        case .mastercard: return "万事达卡 (MasterCard)"
        case .amex: return "美国运通卡 (Amex)"
        case .discover: return "发现卡 (Discover)"
        case .dinersClub: return "大莱卡 (Diners Club)"
        case .unionpay: return "银联卡 (UnionPay)"
        case .jcb: return "JCB卡"
        case .unknown: return "未知卡片"
        }
    }
}

/// 跨端同步、真正进入主数据模型的卡片实体 (对应 Web 端 SharedCard 规范)
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
        source: String = "mac_upload",
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

public struct SharedCard: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var cardCategory: String
    public var country: String
    public var bank: String
    public var cardNumber: String
    public var alias: String?
    public var level: String?
    /// 历史字段名，当前实际表示币种代码（如 CNY, USD, EUR）
    public var type: String?
    public var limit: Double?
    public var cvv: String?
    /// 有效期格式 MM/YY 字符串
    public var valid: String?
    public var annualFee: Double?
    /// 年费达标状态： "1" 已达标， "2" 未达标， "3" 终免年费
    public var isQualified: String?
    /// 下次年费收取时间：毫秒时间戳
    public var nextAnnualFeeCollectionTime: Double?
    /// 上次提额时间：毫秒时间戳
    public var lastTime: Double?
    /// 账单日： 字符串格式 (如 "10")
    public var accountBillDate: String?
    /// 还款日： 字符串格式 (如 "28")
    public var dueDate: String?
    /// 账单日消费归属规则： true 归下期， false 归当期
    public var billingDaySpendingToNextBill: Bool
    public var equity: String?
    public var remark: String?
    /// 最后修改时间：毫秒时间戳
    public var lastModifyTime: Double
    public var isSharedLimit: Bool
    public var cardImages: [CardImageAsset]
    public var extraFields: [String: CardJSONValue] = [:]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case cardCategory
        case country
        case bank
        case cardNumber
        case alias
        case level
        case type
        case limit
        case cvv
        case valid
        case annualFee
        case isQualified
        case nextAnnualFeeCollectionTime
        case lastTime
        case accountBillDate
        case dueDate
        case billingDaySpendingToNextBill
        case equity
        case remark
        case lastModifyTime
        case isSharedLimit
        case cardImages
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

    private static func decodeString(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> String? {
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            if value.rounded() == value {
                return String(Int64(value))
            }
            return String(value)
        }
        return nil
    }

    private static func normalizeCardCategory(_ value: String) -> String {
        value == "debit" ? "debit" : "credit"
    }

    private static func decodeDouble(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func decodeTimestamp(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return DataMigrationManager.timestampMilliseconds(from: value)
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return DataMigrationManager.timestampMilliseconds(from: value)
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return DataMigrationManager.timestampMilliseconds(from: value)
        }
        return nil
    }

    private static func decodeBool(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Bool? {
        if let value = try? container.decode(Bool.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? container.decode(String.self, forKey: key) {
            let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "1", "yes"].contains(lower) { return true }
            if ["false", "0", "no"].contains(lower) { return false }
        }
        return nil
    }
}

/// 上传到云端的跨端共享备份包结构
public struct SharedBackupPayload: Codable {
    public let schemaVersion: String
    public let exportedAt: String
    public let source: String
    public let cards: [SharedCard]
    public let deletedCardIds: [String]
    
    public init(cards: [SharedCard]) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        self.schemaVersion = "2.0.0"
        self.exportedAt = formatter.string(from: Date())
        self.source = "macos"
        self.cards = cards
        self.deletedCardIds = []
    }
}

/// 客户端本地专有元数据，不随 WebDAV 同步
public struct CardAppMeta: Codable, Identifiable {
    public var id: String { cardId }
    public var cardId: String
    public var createTime: String?
    public var localFlags: [String: String]?
    
    public init(cardId: String, createTime: String? = nil, localFlags: [String: String]? = nil) {
        self.cardId = cardId
        self.createTime = createTime
        self.localFlags = localFlags
    }
}

/// 分组方式选项
public enum GroupOption: String, CaseIterable, Identifiable, Sendable {
    case none = "无分组"
    case bank = "按发卡行"
    case brand = "按卡组织"
    case level = "按卡级别"
    case country = "按发卡国家"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .none: return "grid.nonsquare"
        case .bank: return "building.columns.fill"
        case .brand: return "creditcard.fill"
        case .level: return "crown.fill"
        case .country: return "globe"
        }
    }
}

/// 排序方式选项
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

    public var id: String { self.rawValue }
    
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
