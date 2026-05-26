import Foundation

/// 7大银行卡种品牌枚举
public enum CardBrand: String, Codable, CaseIterable {
    case visa
    case mastercard
    case amex
    case discover
    case dinersClub
    case unionpay
    case jcb
    case unknown
    
    /// 根据卡号实时侦测卡种品牌的高精度正则算法 (增加卡片级别智能纠偏)
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
            if levelStr.lowercased().contains("mastercard") {
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
public struct SharedCard: Codable, Identifiable, Hashable {
    public var id: String
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
    /// 年费达标状态： "1" 已达标， "2" 未达标， "3" 终身免年费
    public var isQualified: String?
    /// 下次年费收取时间： YYYY-MM-DD 字符串
    public var nextAnnualFeeCollectionTime: String?
    /// 上次提额时间： YYYY-MM-DD 字符串
    public var lastTime: String?
    /// 账单日： 字符串格式 (如 "10")
    public var accountBillDate: String?
    /// 还款日： 字符串格式 (如 "28")
    public var dueDate: String?
    /// 账单日消费归属规则： true 归下期， false 归当期
    public var billingDaySpendingToNextBill: Bool
    public var equity: String?
    public var remark: String?
    public var lastModifyTime: String
    public var isSharedLimit: Bool
    
    public init(
        id: String = UUID().uuidString,
        country: String,
        bank: String,
        cardNumber: String,
        alias: String? = nil,
        level: String? = nil,
        type: String? = "CNY",
        limit: Double? = 0,
        cvv: String? = nil,
        valid: String? = nil,
        annualFee: Double? = 0,
        isQualified: String? = "2",
        nextAnnualFeeCollectionTime: String? = nil,
        lastTime: String? = nil,
        accountBillDate: String? = nil,
        dueDate: String? = nil,
        billingDaySpendingToNextBill: Bool = true,
        equity: String? = nil,
        remark: String? = nil,
        lastModifyTime: String = "",
        isSharedLimit: Bool = true
    ) {
        self.id = id
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
public enum GroupOption: String, CaseIterable, Identifiable {
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
public enum SortOption: String, CaseIterable, Identifiable {
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
