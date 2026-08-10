import Foundation

/// 7大银行卡组织品牌枚举
public enum CardBrand: String, Codable, CaseIterable {
    case visa
    case mastercard
    case amex
    case discover
    case dinersClub
    case unionpay
    case jcb
    case unknown
    
    /// 根据卡号实时侦测卡组织品牌的高精度正则算法 (增加卡片级别智能纠偏)
    public static func detect(from cardNumber: String, level: String? = nil) -> CardBrand {
        // 💡 优先通过卡片等级（level）进行明确的卡组织强制映射，解决 Discover 与银联的双边通道号段重合误判
        if let levelStr = level {
            if levelStr.contains("银联") || levelStr.lowercased().contains("unionpay") {
                return .unionpay
            }
            if levelStr.contains("Discover") || levelStr.contains("发现") {
                return .discover
            }
            if levelStr.lowercased().contains("visa") {
                return .visa
            }
            if levelStr.lowercased().contains("mastercard") || levelStr.contains("万事达") {
                return .mastercard
            }
            if levelStr.lowercased().contains("jcb") {
                return .jcb
            }
            if levelStr.lowercased().contains("ae") || levelStr.contains("运通") {
                return .amex
            }
        }
        
        let cleanNumber = cardNumber.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        
        // 1. Visa: 4 开头，长度 13-19 位
        if cleanNumber.hasPrefix("4") { return .visa }
        
        // 2. MasterCard: 51-55 或 2221-2720 开头，长度 16 位
        let mcPattern = "^(5[1-5]|222[1-9]|22[3-9]\\d|2[3-6]\\d{2}|27[0-1]\\d|2720)"
        if cleanNumber.range(of: mcPattern, options: .regularExpression) != nil { return .mastercard }
        
        // 3. American Express (Amex): 34 或 37 开头，长度 15 位
        if cleanNumber.hasPrefix("34") || cleanNumber.hasPrefix("37") { return .amex }
        
        // 4. Diners Club (大莱卡): 300-305, 3095, 36, 38-39 开头
        let dinersPattern = "^(30[0-5]|3095|36|38|39)"
        if cleanNumber.range(of: dinersPattern, options: .regularExpression) != nil { return .dinersClub }
        
        // 5. Discover (发现卡): 6011, 622126-622925, 644-649, 65 开头
        let discoverPattern = "^(6011|622(12[6-9]|1[3-9]\\d|[2-8]\\d{2}|9[0-1]\\d|92[0-5])|64[4-9]|65)"
        if cleanNumber.range(of: discoverPattern, options: .regularExpression) != nil { return .discover }
        
        // 6. JCB: 3528-3589 开头
        let jcbPattern = "^35(2[8-9]|[3-8]\\d)"
        if cleanNumber.range(of: jcbPattern, options: .regularExpression) != nil { return .jcb }
        
        // 7. UnionPay (银联): 62 开头
        if cleanNumber.hasPrefix("62") { return .unionpay }
        
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

    public init(
        id: String = UUID().uuidString,
        mimeType: String = "image/jpeg",
        data: String,
        createdAt: Double = DataMigrationManager.currentTimestampMilliseconds(),
        source: String = "mac_upload",
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

    private enum CodingKeys: String, CodingKey {
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

    public func encode(to encoder: Encoder) throws {
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
