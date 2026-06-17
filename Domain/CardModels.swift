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
        if let levelStr = level {
            if levelStr.contains("银联") || levelStr.lowercased().contains("unionpay") { return .unionpay }
            if levelStr.contains("Discover") || levelStr.contains("发现") { return .discover }
            if levelStr.lowercased().contains("visa") { return .visa }
            if levelStr.lowercased().contains("mastercard") { return .mastercard }
            if levelStr.lowercased().contains("jcb") { return .jcb }
            if levelStr.lowercased().contains("ae") || levelStr.contains("运通") { return .amex }
        }
        let cleanNumber = cardNumber.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        if cleanNumber.hasPrefix("4") { return .visa }
        let mcPattern = "^(5[1-5]|222[1-9]|22[3-9]\\d|2[3-6]\\d{2}|27[0-1]\\d|2720)"
        if cleanNumber.range(of: mcPattern, options: .regularExpression) != nil { return .mastercard }
        if cleanNumber.hasPrefix("34") || cleanNumber.hasPrefix("37") { return .amex }
        let dinersPattern = "^(30[0-5]|3095|36|38|39)"
        if cleanNumber.range(of: dinersPattern, options: .regularExpression) != nil { return .dinersClub }
        if cleanNumber.hasPrefix("62") { return .unionpay }
        let discoverPattern = "^(6011|622(12[6-9]|1[3-9]\\d|[2-8]\\d{2}|9[0-1]\\d|92[0-5])|64[4-9]|65)"
        if cleanNumber.range(of: discoverPattern, options: .regularExpression) != nil { return .discover }
        let jcbPattern = "^35(2[8-9]|[3-8]\\d)"
        if cleanNumber.range(of: jcbPattern, options: .regularExpression) != nil { return .jcb }
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

    public init(
        id: String = UUID().uuidString,
        mimeType: String = "image/jpeg",
        data: String,
        createdAt: Double = DataMigrationManager.currentTimestampMilliseconds(),
        source: String = "ios_upload",
        name: String = ""
    ) {
        self.id = id
        self.mimeType = mimeType
        self.data = data
        self.createdAt = createdAt
        self.source = source
        self.name = name
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

    private enum CodingKeys: String, CodingKey {
        case id, cardCategory, country, bank, cardNumber, alias, level, type
        case limit, cvv, valid, annualFee, isQualified, nextAnnualFeeCollectionTime
        case lastTime, accountBillDate, dueDate, billingDaySpendingToNextBill
        case equity, remark, lastModifyTime, isSharedLimit, cardImages
    }

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
        cardImages: [CardImageAsset] = []
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
