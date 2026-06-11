import SwiftUI
import Charts

public struct StatisticsView: View {
    public var cards: [SharedCard]
    
    // 💡 额外交互状态量
    @State private var skeletonOpacity = 0.5
    @State private var selectedFeeStatus: String? = "未达标" // 💡 默认锁定“未达标”以防呆警示
    
    // 统计派生属性
    private var creditCards: [SharedCard] {
        cards.filter { $0.cardCategory != "debit" }
    }
    
    private var debitCards: [SharedCard] {
        cards.filter { $0.cardCategory == "debit" }
    }
    
    private var totalLimitByCurrency: [String: Double] {
        var dict: [String: Double] = [:]
        var processedSharedGroups = Set<String>()
        
        for card in creditCards {
            let currency = (card.type ?? "CNY").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if card.isSharedLimit {
                let cleanBank = card.bank.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                let groupKey = "\(card.country)-\(cleanBank)-\(currency)"
                if !processedSharedGroups.contains(groupKey) {
                    processedSharedGroups.insert(groupKey)
                    dict[currency, default: 0.0] += card.limit ?? 0.0
                }
            } else {
                dict[currency, default: 0.0] += card.limit ?? 0.0
            }
        }
        return dict
    }
    
    private var formattedTotalLimit: String {
        let stats = totalLimitByCurrency
        if stats.isEmpty { return "¥0" }
        
        let sortedCurrencies = stats.keys.sorted { curr1, curr2 in
            if curr1 == "CNY" { return true }
            if curr2 == "CNY" { return false }
            if curr1 == "USD" { return true }
            if curr2 == "USD" { return false }
            return curr1 < curr2
        }
        
        var parts: [String] = []
        for currency in sortedCurrencies {
            let limit = stats[currency] ?? 0.0
            let formattedVal = Int(limit).description
            switch currency {
            case "CNY":
                parts.append("¥\(formattedVal)")
            case "USD":
                parts.append("$\(formattedVal)")
            case "HKD":
                parts.append("HK$\(formattedVal)")
            case "EUR":
                parts.append("€\(formattedVal)")
            case "JPY":
                parts.append("JP¥\(formattedVal)")
            default:
                parts.append("\(formattedVal) \(currency)")
            }
        }
        return parts.joined(separator: " + ")
    }
    
    private var cardCount: Int { cards.count }
    private var creditCardCount: Int { creditCards.count }
    private var debitCardCount: Int { debitCards.count }
    
    private var bankCount: Int {
        let banks = cards.map { $0.bank.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
        return Set(banks).count
    }
    
    private var debitCountryCount: Int {
        Set(debitCards.map { $0.country }.filter { !$0.isEmpty }).count
    }
    
    private var debitBankCount: Int {
        Set(debitCards.map { $0.bank.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }).count
    }
    
    private var debitCurrencyCount: Int {
        Set(debitCards.map { ($0.type ?? "").uppercased() }.filter { !$0.isEmpty }).count
    }
    
    // 按银行统计额度结构
    public struct BankLimit: Identifiable {
        public var id: String { bankName }
        public let bankName: String
        public let limit: Double
        public let currencySymbol: String // 💡 货币符号，避免 annotation 乱标符号
        
        public init(bankName: String, limit: Double, currencySymbol: String) {
            self.bankName = bankName
            self.limit = limit
            self.currencySymbol = currencySymbol
        }
    }
    
    private var bankLimits: [BankLimit] {
        var dict: [String: Double] = [:]
        var processedSharedGroups = Set<String>()
        
        for card in creditCards {
            let cleanBank = card.bank.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            let currency = (card.type ?? "CNY").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 💡 银行额度去重与币种强绑定，区分人民币与美元授信
            let bankCurrencyKey = "\(cleanBank) (\(currency))"
            
            if card.isSharedLimit {
                let groupKey = "\(card.country)-\(cleanBank)-\(currency)"
                if !processedSharedGroups.contains(groupKey) {
                    processedSharedGroups.insert(groupKey)
                    dict[bankCurrencyKey, default: 0.0] += card.limit ?? 0.0
                }
            } else {
                dict[bankCurrencyKey, default: 0.0] += card.limit ?? 0.0
            }
        }
        
        return dict.map { key, value in
            var symbol = "¥"
            if key.contains("(USD)") {
                symbol = "$"
            } else if key.contains("(HKD)") {
                symbol = "HK$"
            } else if key.contains("(EUR)") {
                symbol = "€"
            } else if key.contains("(JPY)") {
                symbol = "JP¥"
            } else if !key.contains("(CNY)") {
                if let range = key.range(of: "\\(.*\\)", options: .regularExpression) {
                    let currencyCode = key[range].replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                    symbol = currencyCode + " "
                }
            }
            return BankLimit(bankName: key, limit: value, currencySymbol: symbol)
        }.filter { $0.limit >= 1.0 }.sorted { $0.limit > $1.limit } // 💡 严格过滤大于等于1.0额度的无意义空项
    }
    
    // 💡 Top 5 银行限额折叠与合并逻辑，合并“其他”时区分币种分别求和！并强力杜绝 limit<=0 项目以防文字重叠
    private var processedBankLimits: [BankLimit] {
        let sortedLimits = bankLimits.filter { $0.limit >= 1.0 } // 💡 严格过滤
        if sortedLimits.count <= 5 {
            return sortedLimits
        } else {
            let top5 = Array(sortedLimits.prefix(5))
            let others = sortedLimits.dropFirst(5)
            
            // 按币种对 others 进行分组求和，坚决不进行跨币种直接相加
            var currencySum: [String: Double] = [:]
            for item in others {
                let currency = item.bankName.components(separatedBy: "(").last?.replacingOccurrences(of: ")", with: "").trimmingCharacters(in: .whitespaces) ?? "CNY"
                currencySum[currency, default: 0.0] += item.limit
            }
            
            var result = top5
            for (currency, limit) in currencySum {
                if limit >= 1.0 { // 💡 严格过滤
                    var symbol = "¥"
                    if currency == "USD" { symbol = "$" }
                    else if currency == "HKD" { symbol = "HK$" }
                    else if currency == "EUR" { symbol = "€" }
                    else if currency == "JPY" { symbol = "JP¥" }
                    else if currency != "CNY" { symbol = currency + " " }
                    
                    result.append(BankLimit(bankName: "其他 (\(currency))", limit: limit, currencySymbol: symbol))
                }
            }
            return result.sorted { $0.limit > $1.limit }
        }
    }
    
    // 💡 获取特定年费达标状态下的卡片列表明细
    private func cardsWithFeeStatus(_ status: String) -> [SharedCard] {
        return creditCards.filter { card in
            switch status {
            case "已达标":
                return card.isQualified == "1"
            case "未达标":
                return card.isQualified == "2" || (card.isQualified ?? "").isEmpty
            case "终免年费":
                return card.isQualified == "3"
            default:
                return false
            }
        }
    }
    
    // 💡 最高授信发卡行及最大单卡授信额度分析
    private var maxLimitBank: String {
        bankLimits.first?.bankName ?? "暂无"
    }
    
    private var maxSingleLimitText: String {
        guard let maxCard = creditCards.max(by: { ($0.limit ?? 0.0) < ($1.limit ?? 0.0) }),
              let limit = maxCard.limit else {
            return "¥0"
        }
        let currency = (maxCard.type ?? "CNY").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var symbol = "¥"
        if currency == "USD" { symbol = "$" }
        else if currency == "HKD" { symbol = "HK$" }
        else if currency == "EUR" { symbol = "€" }
        else if currency == "JPY" { symbol = "JP¥" }
        
        return "\(symbol)\(Int(limit).description)"
    }
    
    // 💡 智能卡品牌解析：基于卡号前缀扫描 VISA、Mastercard、UnionPay、Amex、JCB 五大品牌构成
    public struct BrandStat: Identifiable {
        public var id: String { brandName }
        public let brandName: String
        public let count: Int
        public let color: Color
        public let icon: String
    }
    
    private var brandStats: [BrandStat] {
        var unionPay = 0
        var visa = 0
        var mastercard = 0
        var amex = 0
        var jcb = 0
        var others = 0
        
        for card in creditCards {
            let number = card.cardNumber.replacingOccurrences(of: " ", with: "")
            if number.hasPrefix("4") {
                visa += 1
            } else if number.hasPrefix("5") || number.hasPrefix("2") {
                mastercard += 1
            } else if number.hasPrefix("62") || number.hasPrefix("60") || number.hasPrefix("9") {
                unionPay += 1
            } else if number.hasPrefix("37") || number.hasPrefix("34") {
                amex += 1
            } else if number.hasPrefix("35") {
                jcb += 1
            } else {
                others += 1
            }
        }
        
        var list: [BrandStat] = []
        if unionPay > 0 { list.append(BrandStat(brandName: "银联", count: unionPay, color: .red, icon: "creditcard")) }
        if visa > 0 { list.append(BrandStat(brandName: "VISA", count: visa, color: .blue, icon: "creditcard.fill")) }
        if mastercard > 0 { list.append(BrandStat(brandName: "万事达", count: mastercard, color: .orange, icon: "creditcard")) }
        if amex > 0 { list.append(BrandStat(brandName: "运通", count: amex, color: .cyan, icon: "creditcard.fill")) }
        if jcb > 0 { list.append(BrandStat(brandName: "JCB", count: jcb, color: .purple, icon: "creditcard")) }
        if others > 0 { list.append(BrandStat(brandName: "其他", count: others, color: .gray, icon: "creditcard")) }
        return list
    }
    
    // 💡 还款账期旬度密度统计，提供资金流调配防呆指导
    private var dueDateDispersionText: String {
        var earlyMonth = 0 // 1~10
        var midMonth = 0   // 11~20
        var lateMonth = 0  // 21~31
        
        for card in creditCards {
            if let dueStr = card.dueDate, let dueDay = Int(dueStr) {
                if dueDay <= 10 {
                    earlyMonth += 1
                } else if dueDay <= 20 {
                    midMonth += 1
                } else {
                    lateMonth += 1
                }
            }
        }
        
        let maxCount = max(earlyMonth, max(midMonth, lateMonth))
        if maxCount == 0 { return "暂无还款账期数据" }
        if maxCount == earlyMonth {
            return "还款集中在上旬（1-10号还款压力大）"
        } else if maxCount == midMonth {
            return "还款集中在中旬（11-20号还款压力大）"
        } else {
            return "还款集中在下旬（21-31号还款压力大）"
        }
    }
    
    // 💡 年费达标率健康度警告与评级
    private var unqualifiedCardCount: Int {
        creditCards.filter { $0.isQualified == "2" || ($0.isQualified ?? "").isEmpty }.count
    }
    
    private var annualFeeHealthText: String {
        let unqualified = unqualifiedCardCount
        if unqualified == 0 {
            return "极佳 (年费零摩擦)"
        } else if unqualified <= 2 {
            return "良好 (轻微日常达标)"
        } else {
            return "警告 (有多张待达标卡片)"
        }
    }
    
    private var annualFeeHealthColor: Color {
        let unqualified = unqualifiedCardCount
        if unqualified == 0 {
            return .green
        } else if unqualified <= 2 {
            return .orange
        } else {
            return .red
        }
    }
    
    // 💡 年费达标率百分比
    private var qualifiedFeeRateText: String {
        let qualifiedCount = creditCards.filter { $0.isQualified == "1" || $0.isQualified == "3" }.count
        let total = creditCards.count
        guard total > 0 else { return "0.0%" }
        let rate = Double(qualifiedCount) / Double(total) * 100.0
        return String(format: "%.1f%%", rate)
    }
    
    // 年费状态饼图数据结构
    public struct AnnualFeeStatus: Identifiable {
        public var id: String { name }
        public let name: String
        public let count: Int
        public let color: Color
        
        public init(name: String, count: Int, color: Color) {
            self.name = name
            self.count = count
            self.color = color
        }
    }
    
    private var annualFeeStats: [AnnualFeeStatus] {
        var qualified = 0
        var unqualified = 0
        var ultimateFree = 0
        
        for card in creditCards {
            switch card.isQualified {
            case "1": qualified += 1
            case "2": unqualified += 1
            case "3": ultimateFree += 1
            default: unqualified += 1
            }
        }
        
        return [
            AnnualFeeStatus(name: "已达标", count: qualified, color: .green),
            AnnualFeeStatus(name: "未达标", count: unqualified, color: .orange),
            AnnualFeeStatus(name: "终免年费", count: ultimateFree, color: .cyan)
        ].filter { $0.count > 0 }
    }
    
    private var cardExpiryStats: DateCalculator.CardExpiryStats {
        DateCalculator.cardExpiryStats(for: cards)
    }
    
    private var cardExpiryRiskText: String {
        if cardExpiryStats.expiredCards > 0 {
            return "已过期 \(cardExpiryStats.expiredCards) 张"
        }
        if cardExpiryStats.soonExpiring > 0 {
            return "6个月内到期 \(cardExpiryStats.soonExpiring) 张"
        }
        return "有效期正常"
    }
    
    private var cardExpiryRiskColor: Color {
        if cardExpiryStats.expiredCards > 0 { return .red }
        if cardExpiryStats.soonExpiring > 0 { return .orange }
        return .green
    }
    
    // MARK: - 🧠 AI 智能财务管家 & 额度资产诊断派生字段
    
    // 辅助：根据毫秒时间戳计算与当前时间相差的天数
    private func daysBetweenToday(and timestamp: Double?) -> Int? {
        guard let date = DateCalculator.date(fromTimestamp: timestamp) else { return nil }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        return components.day
    }

    // 辅助：根据毫秒时间戳计算距今已过去的天数
    private func daysSinceTimestamp(_ timestamp: Double?) -> Int? {
        guard let date = DateCalculator.date(fromTimestamp: timestamp) else { return nil }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfTarget, to: startOfToday)
        return components.day
    }
    
    // 💡 年费流失防御盾结构体
    public struct PendingFeeCard: Identifiable {
        public var id: String { cardId }
        public let cardId: String
        public let card: SharedCard
        public let daysLeft: Int
        public let feeText: String
        
        public init(cardId: String, card: SharedCard, daysLeft: Int, feeText: String) {
            self.cardId = cardId
            self.card = card
            self.daysLeft = daysLeft
            self.feeText = feeText
        }
    }
    
    private var pendingFeeCards: [PendingFeeCard] {
        var list: [PendingFeeCard] = []
        for card in creditCards {
            let isUnqualified = card.isQualified == "2" || (card.isQualified ?? "").isEmpty
            if isUnqualified, let days = daysBetweenToday(and: card.nextAnnualFeeCollectionTime) {
                if days >= 0 && days <= 60 {
                    let currency = (card.type ?? "CNY").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    var symbol = "¥"
                    if currency == "USD" { symbol = "$" }
                    else if currency == "HKD" { symbol = "HK$" }
                    else if currency == "EUR" { symbol = "€" }
                    else if currency == "JPY" { symbol = "JP¥" }
                    let feeText = "\(symbol)\(Int(card.annualFee ?? 0.0))"
                    
                    list.append(PendingFeeCard(cardId: card.id, card: card, daysLeft: days, feeText: feeText))
                }
            }
        }
        return list.sorted { $0.daysLeft < $1.daysLeft }
    }
    
    private var totalUnqualifiedAnnualFeeText: String {
        var feeByCurrency: [String: Double] = [:]
        for card in creditCards {
            let isUnqualified = card.isQualified == "2" || (card.isQualified ?? "").isEmpty
            if isUnqualified {
                let currency = (card.type ?? "CNY").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                feeByCurrency[currency, default: 0.0] += card.annualFee ?? 0.0
            }
        }
        
        let activeFees = feeByCurrency.filter { $0.value > 0 }
        if activeFees.isEmpty { return "¥0" }
        
        let sortedCurrencies = activeFees.keys.sorted { curr1, curr2 in
            if curr1 == "CNY" { return true }
            if curr2 == "CNY" { return false }
            if curr1 == "USD" { return true }
            if curr2 == "USD" { return false }
            return curr1 < curr2
        }
        
        var parts: [String] = []
        for currency in sortedCurrencies {
            let fee = activeFees[currency] ?? 0.0
            let formattedVal = Int(fee).description
            switch currency {
            case "CNY":
                parts.append("¥\(formattedVal)")
            case "USD":
                parts.append("$\(formattedVal)")
            case "HKD":
                parts.append("HK$\(formattedVal)")
            case "EUR":
                parts.append("€\(formattedVal)")
            case "JPY":
                parts.append("JP¥\(formattedVal)")
            default:
                parts.append("\(formattedVal) \(currency)")
            }
        }
        return parts.joined(separator: " + ")
    }
    
    // 💡 提额CD冷却唤醒结构体
    public struct LimitIncreaseRecommendation: Identifiable {
        public var id: String { cardId }
        public let cardId: String
        public let card: SharedCard
        public let daysSince: Int
        
        public init(cardId: String, card: SharedCard, daysSince: Int) {
            self.cardId = cardId
            self.card = card
            self.daysSince = daysSince
        }
    }
    
    private var limitIncreaseRecommendations: [LimitIncreaseRecommendation] {
        var list: [LimitIncreaseRecommendation] = []
        for card in creditCards {
            if let days = daysSinceTimestamp(card.lastTime) {
                if days >= 180 {
                    list.append(LimitIncreaseRecommendation(cardId: card.id, card: card, daysSince: days))
                }
            }
        }
        return list.sorted { $0.daysSince > $1.daysSince }
    }
    
    // 💡 鸡肋卡精简警报结构体
    public struct MicroCardAlert: Identifiable {
        public var id: String { cardId }
        public let cardId: String
        public let card: SharedCard
        public let limitText: String
        
        public init(cardId: String, card: SharedCard, limitText: String) {
            self.cardId = cardId
            self.card = card
            self.limitText = limitText
        }
    }
    
    private var microCards: [MicroCardAlert] {
        var list: [MicroCardAlert] = []
        for card in creditCards {
            let currency = (card.type ?? "CNY").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let limit = card.limit ?? 0.0
            
            var isMicro = false
            var symbol = "¥"
            if currency == "CNY" {
                isMicro = limit < 5000.0
                symbol = "¥"
            } else if currency == "USD" {
                isMicro = limit < 800.0
                symbol = "$"
            } else if currency == "HKD" {
                isMicro = limit < 6000.0
                symbol = "HK$"
            } else if currency == "EUR" {
                isMicro = limit < 800.0
                symbol = "€"
            } else if currency == "JPY" {
                isMicro = limit < 100000.0
                symbol = "JP¥"
            } else {
                isMicro = limit < 5000.0
                symbol = currency + " "
            }
            
            if isMicro {
                list.append(MicroCardAlert(cardId: card.id, card: card, limitText: "\(symbol)\(Int(limit).description)"))
            }
        }
        return list.sorted { ($0.card.limit ?? 0.0) < ($1.card.limit ?? 0.0) }
    }
    
    public init(cards: [SharedCard]) {
        self.cards = cards
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. 顶部极简科技感卡片指标
                HStack(spacing: 16) {
                    MetricCard(
                        title: "银行卡总数",
                        value: "\(cardCount) 张",
                        icon: "creditcard.fill",
                        color: .purple,
                        subtext: "信用卡与储蓄卡合并统计"
                    )
                    
                    MetricCard(
                        title: "发卡银行",
                        value: "\(bankCount) 家",
                        icon: "building.columns.fill",
                        color: .blue,
                        subtext: "已覆盖全国主要发卡机构"
                    )
                    
                    MetricCard(
                        title: "信用授信总额",
                        value: formattedTotalLimit,
                        icon: "dollarsign.circle.fill",
                        color: .green,
                        subtext: "仅统计信用卡，已排除共享额度重复"
                    )
                }
                
                HStack(spacing: 16) {
                    MetricCard(
                        title: "信用卡",
                        value: "\(creditCardCount) 张",
                        icon: "creditcard.fill",
                        color: .cyan,
                        subtext: "参与额度、年费与免息期统计"
                    )
                    
                    MetricCard(
                        title: "储蓄卡",
                        value: "\(debitCardCount) 张",
                        icon: "wallet.pass.fill",
                        color: .teal,
                        subtext: "不参与信用额度、年费和免息期统计"
                    )
                    
                    MetricCard(
                        title: "储蓄卡覆盖",
                        value: "\(debitCountryCount) 地区 / \(debitBankCount) 行 / \(debitCurrencyCount) 币种",
                        icon: "globe.asia.australia.fill",
                        color: .indigo,
                        subtext: "按国家/地区、银行和币种去重"
                    )
                }
                
                HStack(spacing: 20) {
                    // 2. 银行信用额度分布 (条形图)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.cyan)
                            Text("银行信用额度分布")
                                .font(.system(.subheadline, design: .rounded))
                                .bold()
                                .foregroundColor(.secondary)
                            Spacer()
                            if bankLimits.count > 5 {
                                Text("其余已智能归纳折叠")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                        
                        if bankLimits.isEmpty {
                            EmptyStateView()
                        } else {
                            Chart(processedBankLimits) { item in
                                BarMark(
                                    x: .value("额度", item.limit),
                                    y: .value("银行", item.bankName)
                                )
                                .cornerRadius(5)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.85), Color.cyan.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .annotation(position: .trailing) {
                                    Text("\(item.currencySymbol)\(Int(item.limit).description)")
                                        .font(.system(size: 9, design: .rounded))
                                        .bold()
                                        .foregroundColor(.secondary)
                                }
                            }
                            .chartXAxis(.hidden) // 💡 隐藏 X 轴刻度，避免刻度数字与最底下一行重合，腾出极多高度空间
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel {
                                        if let bankName = value.as(String.self) {
                                            Text(bankName)
                                                .font(.system(size: 9, design: .rounded))
                                                .bold()
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .frame(maxWidth: 130, alignment: .trailing) // 限制最大宽度，靠右对齐
                                        }
                                    }
                                }
                            }
                            .frame(height: 300) // 💡 升高至 300，使柱子纵向均匀铺开，彻底杜绝重合
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 3. 年费状态比例图 (环形图 + 交互 Legend + 下钻 ScrollView)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.green)
                                Text("年费达标率分析")
                                    .font(.system(.subheadline, design: .rounded))
                                    .bold()
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("已选：\(selectedFeeStatus ?? "未达标")")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(4)
                        }
                        
                        if annualFeeStats.isEmpty {
                            EmptyStateView()
                        } else {
                            HStack(spacing: 12) {
                                // 左半：环形图
                                Chart(annualFeeStats) { item in
                                    SectorMark(
                                        angle: .value("数量", item.count),
                                        innerRadius: .ratio(0.65),
                                        angularInset: 2.0
                                    )
                                    .cornerRadius(4)
                                    .foregroundStyle(item.color)
                                }
                                .frame(width: 140, height: 140)
                                .chartBackground { chartProxy in
                                    GeometryReader { geometry in
                                        let anchor = chartProxy.plotAreaFrame
                                        let frame = geometry[anchor]
                                        VStack(spacing: 2) {
                                            Text("已达标率")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                            Text(qualifiedFeeRateText)
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(.primary)
                                        }
                                        .position(x: frame.midX, y: frame.midY)
                                    }
                                }
                                
                                // 右半：交互 Legend 列表
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(["已达标", "未达标", "终免年费"], id: \.self) { status in
                                        let isSelected = selectedFeeStatus == status
                                        let count = cardsWithFeeStatus(status).count
                                        let color: Color = status == "已达标" ? .green : (status == "未达标" ? .orange : .cyan)
                                        
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 6, height: 6)
                                            
                                            Text(status)
                                                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                                .foregroundColor(isSelected ? .primary : .secondary)
                                            
                                            Spacer()
                                            
                                            Text("\(count)张")
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? color.opacity(0.12) : Color.clear)
                                        .cornerRadius(6)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                                selectedFeeStatus = status
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(height: 140)
                            
                            Divider()
                                .opacity(0.3)
                            
                            // 下钻卡片明细列表
                            let subCards = cardsWithFeeStatus(selectedFeeStatus ?? "未达标")
                            if subCards.isEmpty {
                                VStack {
                                    Spacer()
                                    Text("该分类下暂无卡片数据")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    Spacer()
                                }
                                .frame(height: 120)
                            } else {
                                ScrollView {
                                    VStack(spacing: 6) {
                                        ForEach(subCards) { card in
                                            DrillDownCardRow(card: card, isUnqualified: selectedFeeStatus == "未达标")
                                        }
                                    }
                                }
                                .frame(height: 120)
                            }
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 380)
                
                // 3. 2x2 智能财务分析报告与洞察矩阵
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.blue)
                        Text("智能财务透视与资产配置")
                            .font(.system(.subheadline, design: .rounded))
                            .bold()
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 2)
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        // 卡片 1：授信集中度分析
                        InsightCard(
                            title: "授信分布集中度",
                            value: maxLimitBank,
                            description: "最高授信发卡行，最大单卡额度达 \(maxSingleLimitText)",
                            iconName: "chart.pie.fill",
                            iconColor: .orange
                        )
                        
                        // 卡片 2：还款期分布密度
                        InsightCard(
                            title: "账期与头寸管理",
                            value: "旬度高峰监测",
                            description: dueDateDispersionText,
                            iconName: "calendar.badge.clock",
                            iconColor: .purple
                        )
                        
                        // 卡片 3：发卡品牌结构
                        InsightCard(
                            title: "卡组织资产结构",
                            value: brandStats.isEmpty ? "暂无品牌数据" : brandStats.map { "\($0.brandName)\($0.count)张" }.joined(separator: " / "),
                            description: "由各国际/国内卡组织卡号前缀智能扫描判定",
                            iconName: "globe",
                            iconColor: .blue
                        )
                        
                        // 卡片 4：有效期风险
                        InsightCard(
                            title: "卡片有效期风险",
                            value: cardExpiryRiskText,
                            description: "已过期 \(cardExpiryStats.expiredCards) 张 / 6个月内 \(cardExpiryStats.soonExpiring) 张 / 正常 \(cardExpiryStats.normalCards) 张",
                            iconName: "calendar.badge.exclamationmark",
                            iconColor: cardExpiryRiskColor
                        )
                        
                        // 卡片 5：年费磨损健康度
                        InsightCard(
                            title: "年费磨损健康度",
                            value: annualFeeHealthText,
                            description: unqualifiedCardCount > 0 ? "还有 \(unqualifiedCardCount) 张信用卡待刷卡达标" : "当前所有卡片无任何年费负担，健康度极佳",
                            iconName: "shield.checkerboard",
                            iconColor: annualFeeHealthColor
                        )
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                
                // 🧠 智能财务管家 & AI 额度资产诊断 (Financial Butler Credit Insights)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.headprofile.fill")
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(.purple)
                        Text("智能财务管家 & AI 额度资产诊断")
                            .font(.system(.title3, design: .rounded))
                            .bold()
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("Financial Butler Credit Insights")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    
                    Text("基于账户内的多币种年费、提额冷却时间以及低额废卡进行硬核客观透视，助您规避资金流失、唤醒额度沉睡潜能。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        // 1. 年费流失防御盾
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: pendingFeeCards.isEmpty ? "shield.checkered" : "exclamationmark.shield.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(pendingFeeCards.isEmpty ? .green : .red)
                                Text("年费资金防沉没报告")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("预计年费刚性损失")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(totalUnqualifiedAnnualFeeText)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(pendingFeeCards.isEmpty ? .green : .red)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.02))
                            .cornerRadius(8)
                            
                            if pendingFeeCards.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.green.opacity(0.8))
                                    Text("未发现60天内年费流失风险")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("当前所有未达标卡离扣费期尚远或均已安全达标，资金通道十分安全。")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.vertical, 8)
                            } else {
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(pendingFeeCards) { item in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.card.bank)
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    Text(item.card.alias ?? "无别名")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text(item.feeText)
                                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                                        .foregroundColor(.red)
                                                    Text("剩余 \(item.daysLeft) 天扣费")
                                                        .font(.system(size: 8, weight: .semibold))
                                                        .foregroundColor(.orange)
                                                }
                                            }
                                            .padding(8)
                                            .background(Color.red.opacity(0.06))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                                .frame(maxHeight: 320) // 💡 扩展 ScrollView 可视高度到 320
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 420, alignment: .topLeading) // 💡 扩展大卡片高度到 420
                        .background(Color.primary.opacity(0.015))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                        )
                        
                        // 2. 睡眠额度唤醒舱
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("提额契机发现机制")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("提额冷却已过卡片")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("\(limitIncreaseRecommendations.count) 张")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(limitIncreaseRecommendations.isEmpty ? .secondary : .orange)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.02))
                            .cornerRadius(8)
                            
                            if limitIncreaseRecommendations.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "clock.badge.checkmark.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary.opacity(0.8))
                                    Text("暂无提额冷却期已过的卡片")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("当前账户内所有持卡均在 6 个月提额CD观察期内，请保持良好消费习惯。")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.vertical, 8)
                            } else {
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(limitIncreaseRecommendations) { item in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.card.bank)
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    Text(item.card.alias ?? "无别名")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text("推荐申请提额")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.orange)
                                                    Text("已过 \(item.daysSince) 天")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(8)
                                            .background(Color.orange.opacity(0.06))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                                .frame(maxHeight: 320) // 💡 扩展 ScrollView 可视高度到 320
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 420, alignment: .topLeading) // 💡 扩展大卡片高度到 420
                        .background(Color.primary.opacity(0.015))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                        )
                        
                        // 3. 鸡肋卡精简舱
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: microCards.isEmpty ? "shield.chevron" : "scissors")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(microCards.isEmpty ? .green : .purple)
                                Text("低额废卡精简警报")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("低额度待精简卡片")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("\(microCards.count) 张")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(microCards.isEmpty ? .green : .purple)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.02))
                            .cornerRadius(8)
                            
                            if microCards.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.green.opacity(0.8))
                                    Text("授信品质结构极其优异")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("当前名下没有任何极低授信额度的鸡肋卡，无拉低总评分隐患，极其优秀。")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.vertical, 8)
                            } else {
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(microCards) { item in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.card.bank)
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    Text(item.card.alias ?? "无别名")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text(item.limitText)
                                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                                        .foregroundColor(.purple)
                                                    Text("建议适时销卡")
                                                        .font(.system(size: 8, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(8)
                                            .background(Color.purple.opacity(0.06))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                                .frame(maxHeight: 320) // 💡 扩展 ScrollView 可视高度到 320
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 420, alignment: .topLeading) // 💡 扩展大卡片高度到 420
                        .background(Color.primary.opacity(0.015))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                        )
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                
                // 4. 原生导出 CSV
                Button(action: exportCSVReport) {
                    Label("导出 CSV 统计分析报告", systemImage: "arrow.down.doc.fill")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                        .background(Color.cyan)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .padding(20)
        }
    }
    
    // 💡 符合人类操作直觉的原生 CSV 报表导出
    private func exportCSVReport() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        savePanel.nameFieldStringValue = "银行卡统计分析报告_\(DateFormatter.iso8601String(from: Date()).prefix(10)).csv"
        
        savePanel.begin { response in
            if response == .OK, let fileURL = savePanel.url {
                var csvText = "银行卡分类统计报告\n"
                csvText += "银行卡总数,信用卡数量,储蓄卡数量,发卡银行数,综合信用额度(去重)\n"
                csvText += "\(cardCount),\(creditCardCount),\(debitCardCount),\(bankCount),\"\(formattedTotalLimit)\"\n\n"
                csvText += "储蓄卡去重覆盖\n"
                csvText += "国家/地区数,银行数,币种数\n"
                csvText += "\(debitCountryCount),\(debitBankCount),\(debitCurrencyCount)\n\n"
                
                csvText += "各银行额度去重分布\n"
                csvText += "银行,信用总额(包含币种)\n"
                for item in bankLimits {
                    csvText += "\(item.bankName),\(item.currencySymbol)\(item.limit)\n"
                }
                
                csvText += "\n年费达标率明细\n"
                csvText += "状态,卡片数量\n"
                for item in annualFeeStats {
                    csvText += "\(item.name),\(item.count)\n"
                }
                
                try? csvText.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
}

// 💡 苹果原生极简拟物科技感指标卡片
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtext: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            .background(
                Circle()
                    .fill(color.opacity(0.12))
                    .blur(radius: 6)
            )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(subtext)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.015))
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
}

// 💡 高端智能财务分析透视卡片组件
struct InsightCard: View {
    let title: String
    let value: String
    let description: String
    let iconName: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(description)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.01))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.4))
            Text("暂无卡片数据，无法生成统计图表")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// 💡 年费达标率交互下钻专用行渲染子 View，完美规避 Swift 闭包内计算超载引起的编译超时错误
struct DrillDownCardRow: View {
    let card: SharedCard
    let isUnqualified: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(card.bank)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let alias = card.alias, !alias.isEmpty {
                    Text(alias)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            
            let currency = (card.type ?? "CNY").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let symbol: String = {
                switch currency {
                case "USD": return "$"
                case "HKD": return "HK$"
                case "EUR": return "€"
                case "JPY": return "JP¥"
                default: return "¥"
                }
            }()
            
            let limitVal = Int(card.limit ?? 0.0).description
            let feeVal = Int(card.annualFee ?? 0.0).description
            
            VStack(alignment: .trailing, spacing: 1) {
                Text("额度 \(symbol)\(limitVal)")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.secondary)
                Text("年费 \(symbol)\(feeVal)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(isUnqualified ? .orange : .secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(6)
    }
}
