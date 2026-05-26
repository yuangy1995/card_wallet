import SwiftUI

/// 极具科技感的信用卡磁贴组件 (1:1.586 黄金比例)
public struct CreditCardView: View {
    public let card: SharedCard
    
    // 显示/隐藏敏感数据控制
    @State private var isShowingNumber = false
    @State private var isShowingCVV = false
    @State private var remainingShowSeconds = 5.0
    
    @State private var isHovered = false
    
    public var onEdit: () -> Void
    public var onDelete: () -> Void
    public var onUpdateStatus: (String) -> Void
    
    private var brand: CardBrand {
        return CardBrand.detect(from: card.cardNumber, level: card.level)
    }
    
    public init(
        card: SharedCard,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onUpdateStatus: @escaping (String) -> Void
    ) {
        self.card = card
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onUpdateStatus = onUpdateStatus
    }
    
    public var body: some View {
        ZStack {
            // 1. 卡片科技暗色拉丝渐变底图
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: getBrandGradient(brand),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // 极细的霓虹边缘描边
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: getShadowColor(brand).opacity(isHovered ? 0.5 : 0.2), radius: isHovered ? 12 : 6, x: 0, y: 4)
            
            // 2. 卡片内容布局
            VStack(alignment: .leading, spacing: 0) {
                // 顶部：银行名 & 原生代码手绘矢量卡标
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.bank)
                            .font(.system(.headline, design: .rounded))
                            .bold()
                            .foregroundColor(.white)
                        if let alias = card.alias, !alias.isEmpty {
                            Text(alias)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    Spacer()
                    CardBrandIcon(brand: brand)
                        .scaleEffect(0.9)
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                
                Spacer()
                
                // 中部：卡号（支持一键防窥切换）
                HStack(spacing: 8) {
                    Text(getFormattedCardNumber())
                        .font(.system(.title3, design: .monospaced))
                        .bold()
                        .foregroundColor(.white)
                        .tracking(1.5)
                    
                    Button {
                        toggleNumberVisibility()
                    } label: {
                        Image(systemName: isShowingNumber ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    
                    // 5秒自动遮罩的极简倒计时圆环
                    if isShowingNumber {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                                .frame(width: 14, height: 14)
                            Circle()
                                .trim(from: 0, to: CGFloat(remainingShowSeconds / 5.0))
                                .stroke(Color.cyan, lineWidth: 1.5)
                                .frame(width: 14, height: 14)
                                .rotationEffect(.degrees(-90))
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // 底部：有效期、CVV 还有年费状态
                HStack(alignment: .bottom) {
                    // 有效期与 CVV
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VALID THRU")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                        Text(card.valid ?? "00/00")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Text("CVV:")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.5))
                            Text(isShowingCVV ? (card.cvv ?? "•••") : "•••")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                            
                            if isShowingCVV {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
                                        .frame(width: 9, height: 9)
                                    Circle()
                                        .trim(from: 0, to: CGFloat(remainingShowSeconds / 5.0))
                                        .stroke(Color.cyan, lineWidth: 1.2)
                                        .frame(width: 9, height: 9)
                                        .rotationEffect(.degrees(-90))
                                }
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleCVVVisibility()
                        }
                    }
                    
                    Spacer()
                    
                    // 免息期或额度展示
                    VStack(alignment: .trailing, spacing: 4) {
                        let limitType = card.isSharedLimit ? "共享额度" : "独立额度"
                        Text(limitType)
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                        
                        // 币种加额度
                        let symbol = getCurrencySymbol(card.type ?? "CNY")
                        Text("\(symbol)\(Int(card.limit ?? 0).description)")
                            .font(.system(.body, design: .rounded))
                            .bold()
                            .foregroundColor(.white)
                        
                        // 免息天数显示
                        let days = DateCalculator.calculateInterestFreePeriod(
                            accountBillDate: card.accountBillDate ?? "",
                            dueDate: card.dueDate ?? "",
                            billingDayToNextBill: card.billingDaySpendingToNextBill
                        )
                        Text("免息期: \(days)天")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                .padding(.bottom, 16)
                .padding(.horizontal, 16)
            }
        }
        // 1:1.586 实体卡黄金比例约束
        .aspectRatio(1.586, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .rotation3DEffect(
            .degrees(isHovered ? 2 : 0),
            axis: (x: -1, y: 1, z: 0)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovered)
        .onHover { hover in
            isHovered = hover
            if hover {
                AutoLockManager.shared.resetActivity()
            }
        }
        // macOS 原生右键上下文快捷菜单，符合人类直观习惯
        .contextMenu {
            Section(header: Text("年费达标快捷标记")) {
                Button { onUpdateStatus("1") } label: {
                    Label("已达标", systemImage: "checkmark.circle.fill")
                }
                Button { onUpdateStatus("2") } label: {
                    Label("未达标", systemImage: "exclamationmark.circle.fill")
                }
                Button { onUpdateStatus("3") } label: {
                    Label("终身免年费", systemImage: "infinity.circle.fill")
                }
            }
            
            Divider()
            
            Button(action: onEdit) {
                Label("编辑卡片 (⌘E)", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("删除此卡 (⌘Delete)", systemImage: "trash")
            }
        }
    }
    
    // 格式化卡号为4位一组显示
    private func getFormattedCardNumber() -> String {
        let number = card.cardNumber.replacingOccurrences(of: " ", with: "")
        if !isShowingNumber {
            // 默认遮罩显示尾数
            let last4 = String(number.suffix(4))
            return "••••  ••••  ••••  \(last4)"
        }
        
        var result = ""
        for (index, char) in number.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += "  "
            }
            result.append(char)
        }
        return result
    }
    
    private func toggleNumberVisibility() {
        isShowingNumber.toggle()
        if isShowingNumber {
            startCountdown()
        }
    }
    
    private func toggleCVVVisibility() {
        isShowingCVV.toggle()
        if isShowingCVV {
            startCountdown()
        }
    }
    
    private func startCountdown() {
        remainingShowSeconds = 5.0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !isShowingNumber && !isShowingCVV {
                timer.invalidate()
                return
            }
            remainingShowSeconds -= 0.1
            if remainingShowSeconds <= 0 {
                isShowingNumber = false
                isShowingCVV = false
                timer.invalidate()
            }
        }
    }
    
    private func getBrandGradient(_ brand: CardBrand) -> [Color] {
        switch brand {
        case .visa:
            return [Color(red: 0.05, green: 0.15, blue: 0.4), Color(red: 0.1, green: 0.3, blue: 0.7)]
        case .mastercard:
            return [Color(red: 0.25, green: 0.05, blue: 0.1), Color(red: 0.45, green: 0.15, blue: 0.2)]
        case .amex:
            return [Color(red: 0.05, green: 0.2, blue: 0.3), Color(red: 0.1, green: 0.4, blue: 0.5)]
        case .dinersClub:
            return [Color(red: 0.1, green: 0.05, blue: 0.3), Color(red: 0.3, green: 0.1, blue: 0.55)]
        case .discover:
            return [Color(red: 0.35, green: 0.15, blue: 0.05), Color(red: 0.5, green: 0.3, blue: 0.1)]
        case .unionpay:
            return [Color(red: 0.05, green: 0.25, blue: 0.2), Color(red: 0.1, green: 0.45, blue: 0.35)]
        case .jcb:
            return [Color(red: 0.1, green: 0.1, blue: 0.25), Color(red: 0.2, green: 0.2, blue: 0.4)]
        case .unknown:
            return [Color(red: 0.15, green: 0.15, blue: 0.15), Color(red: 0.25, green: 0.25, blue: 0.25)]
        }
    }
    
    private func getShadowColor(_ brand: CardBrand) -> Color {
        switch brand {
        case .visa: return .blue
        case .mastercard: return .red
        case .amex: return .cyan
        case .dinersClub: return .purple
        case .discover: return .orange
        case .unionpay: return .green
        case .jcb: return .blue
        case .unknown: return .gray
        }
    }
    
    private func getCurrencySymbol(_ type: String) -> String {
        switch type {
        case "CNY": return "¥"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "HKD": return "HK$"
        default: return "$"
        }
    }
}

/// 用于表示分组信用卡的内部中转结构体
public struct CardGroup: Identifiable {
    public let id = UUID()
    public let name: String
    public let iconName: String
    public let cards: [SharedCard]
    public let totalLimit: Double
}

/// 高质感毛玻璃吸顶 Section Header (集成折叠箭头与 Hover 高亮)
/// 高阶悬浮毛玻璃圆角胶囊 Section Header (缩进排布、半透明霓虹描边、绿色授信胶囊及高保真立体 Hover 效果)
public struct GroupSectionHeader: View {
    public let name: String
    public let iconName: String
    public let cardCount: Int
    public let totalLimit: Double
    
    // 💡 新增折叠机制属性
    public let isCollapsed: Bool
    public let onTap: () -> Void
    
    // 💡 悬浮状态管理
    @State private var isHovered = false
    
    public init(
        name: String, 
        iconName: String, 
        cardCount: Int, 
        totalLimit: Double,
        isCollapsed: Bool,
        onTap: @escaping () -> Void
    ) {
        self.name = name
        self.iconName = iconName
        self.cardCount = cardCount
        self.totalLimit = totalLimit
        self.isCollapsed = isCollapsed
        self.onTap = onTap
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // 1. 灵动旋转小折叠箭头 (物理阻尼 Spring 动画)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary.opacity(0.8))
                .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isCollapsed)
            
            // 2. 渐透圆角分组类别图标
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.cyan)
                .frame(width: 24, height: 24)
                .background(Color.cyan.opacity(0.12))
                .cornerRadius(6)
            
            // 3. 类别名称
            Text(name)
                .font(.system(.body, design: .rounded))
                .bold()
                .foregroundColor(.primary)
            
            // 4. 精致的卡片张数小胶囊药丸
            Text("\(cardCount) 张")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 2.5)
                .background(Color.cyan.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.15), lineWidth: 0.7)
                )
            
            Spacer()
            
            // 5. 高拟物“本组授信”绿色呼吸胶囊 (彻底告别原本僵硬单调的灰色字)
            HStack(spacing: 4) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green.opacity(0.8))
                Text("本组授信")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("¥\(Int(totalLimit).description)")
                    .font(.system(.caption, design: .monospaced))
                    .bold()
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // 💡 左右缩进 12px 悬空卡片化，彻底脱离死板的贴边大长条表格形态
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(isHovered ? 0.03 : 0.015))
        )
        .background(.ultraThinMaterial) // 💡 透底毛玻璃材质，吸顶滚动时遮罩折射，极其奢华
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1) // 💡 极细霓虹微光描边，悬浮必备
        )
        // 💡 立体 Hover 悬浮抬升效果
        .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.006 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hover in
            isHovered = hover
        }
    }
}

/// 信用卡包主视图 (支持多维分组与组合排序，以及分组折叠)
public struct CardGridView: View {
    public var cards: [SharedCard]
    public var groupBy: GroupOption
    public var sortBy: SortOption
    
    public var onEdit: (SharedCard) -> Void
    public var onDelete: (SharedCard) -> Void
    public var onUpdateStatus: (SharedCard, String) -> Void
    
    // 💡 用于追踪各个分组当前是否已折叠收起的集合
    @State private var collapsedGroups: Set<String> = []
    
    // 双栏网格自适应配置
    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 450), spacing: 20)
    ]
    
    public init(
        cards: [SharedCard],
        groupBy: GroupOption = .none,
        sortBy: SortOption = .limitDesc,
        onEdit: @escaping (SharedCard) -> Void,
        onDelete: @escaping (SharedCard) -> Void,
        onUpdateStatus: @escaping (SharedCard, String) -> Void
    ) {
        self.cards = cards
        self.groupBy = groupBy
        self.sortBy = sortBy
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onUpdateStatus = onUpdateStatus
    }
    
    /// 根据分组和排序条件，对数据进行重组的计算属性
    private var groupedAndSortedCards: [CardGroup] {
        // 1. 数据分组
        let rawGroups: [String: [SharedCard]]
        let iconName: String
        
        switch groupBy {
        case .none:
            rawGroups = ["所有卡片": cards]
            iconName = "grid.nonsquare"
        case .bank:
            rawGroups = Dictionary(grouping: cards) { $0.bank }
            iconName = "building.columns.fill"
        case .brand:
            rawGroups = Dictionary(grouping: cards) { card in
                CardBrand.detect(from: card.cardNumber, level: card.level).displayName
            }
            iconName = "creditcard.fill"
        case .level:
            rawGroups = Dictionary(grouping: cards) { $0.level ?? "其他级别" }
            iconName = "crown.fill"
        case .country:
            rawGroups = Dictionary(grouping: cards) { $0.country.isEmpty ? "其他国家/地区" : $0.country }
            iconName = "globe"
        }
        
        // 2. 组内排序
        return rawGroups.map { name, groupCards in
            let sorted = groupCards.sorted { c1, c2 in
                switch sortBy {
                case .limitDesc:
                    return (c1.limit ?? 0) > (c2.limit ?? 0)
                case .limitAsc:
                    return (c1.limit ?? 0) < (c2.limit ?? 0)
                case .daysDesc:
                    let days1 = DateCalculator.calculateInterestFreePeriod(
                        accountBillDate: c1.accountBillDate ?? "",
                        dueDate: c1.dueDate ?? "",
                        billingDayToNextBill: c1.billingDaySpendingToNextBill
                    )
                    let days2 = DateCalculator.calculateInterestFreePeriod(
                        accountBillDate: c2.accountBillDate ?? "",
                        dueDate: c2.dueDate ?? "",
                        billingDayToNextBill: c2.billingDaySpendingToNextBill
                    )
                    return days1 > days2
                case .daysAsc:
                    let days1 = DateCalculator.calculateInterestFreePeriod(
                        accountBillDate: c1.accountBillDate ?? "",
                        dueDate: c1.dueDate ?? "",
                        billingDayToNextBill: c1.billingDaySpendingToNextBill
                    )
                    let days2 = DateCalculator.calculateInterestFreePeriod(
                        accountBillDate: c2.accountBillDate ?? "",
                        dueDate: c2.dueDate ?? "",
                        billingDayToNextBill: c2.billingDaySpendingToNextBill
                    )
                    return days1 < days2
                case .lastModify:
                    if let comparison = DataMigrationManager.compareLastModifyTime(local: c1.lastModifyTime, backup: c2.lastModifyTime) {
                        return comparison == .orderedDescending
                    }
                    return c1.id < c2.id
                }
            }
            
            let totalLimit: Double = {
                var sum = 0.0
                var processedSharedGroups = Set<String>()
                
                for card in sorted {
                    let currency = (card.type ?? "CNY").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanBank = card.bank.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                    
                    if card.isSharedLimit {
                        // 💡 共享额度在组内进行 银行-国家-币种 维度的强去重，仅计算一次最大授信
                        let groupKey = "\(card.country)-\(cleanBank)-\(currency)"
                        if !processedSharedGroups.contains(groupKey) {
                            processedSharedGroups.insert(groupKey)
                            sum += card.limit ?? 0.0
                        }
                    } else {
                        // 💡 独立授信卡片，直接累加
                        sum += card.limit ?? 0.0
                    }
                }
                return sum
            }()
            return CardGroup(name: name, iconName: iconName, cards: sorted, totalLimit: totalLimit)
        }
        // 3. 组外排序：非 none 模式下，按卡片张数降序，相同按组名升序
        .sorted { g1, g2 in
            if groupBy == .none { return true }
            if g1.cards.count != g2.cards.count {
                return g1.cards.count > g2.cards.count
            }
            return g1.name.localizedCompare(g2.name) == .orderedAscending
        }
    }
    
    public var body: some View {
        ScrollView {
            if groupBy == .none {
                // 无分组状态下：直接网格平铺以保持极其纯粹高效率的主视图
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(groupedAndSortedCards.first?.cards ?? []) { card in
                        CreditCardView(
                            card: card,
                            onEdit: { onEdit(card) },
                            onDelete: { onDelete(card) },
                            onUpdateStatus: { status in onUpdateStatus(card, status) }
                        )
                    }
                }
                .padding(20)
            } else {
                // 有分组状态下：使用 LazyVStack 吸顶 Section Headers，提供一流的交互式透底质感
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedAndSortedCards) { group in
                        let isCollapsed = collapsedGroups.contains(group.name)
                        
                        Section(header: GroupSectionHeader(
                            name: group.name,
                            iconName: group.iconName,
                            cardCount: group.cards.count,
                            totalLimit: group.totalLimit,
                            isCollapsed: isCollapsed,
                            onTap: {
                                // 💡 施加极富苹果动感阻尼的 Spring 弹簧重排折拢动画
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if isCollapsed {
                                        collapsedGroups.remove(group.name)
                                    } else {
                                        collapsedGroups.insert(group.name)
                                    }
                                }
                            }
                        )) {
                            if !isCollapsed {
                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(group.cards) { card in
                                        CreditCardView(
                                            card: card,
                                            onEdit: { onEdit(card) },
                                            onDelete: { onDelete(card) },
                                            onUpdateStatus: { status in onUpdateStatus(card, status) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                // 💡 折拢收纳时的顶部渐透和弹性缩放排布过渡，极其高级
                                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }
}
