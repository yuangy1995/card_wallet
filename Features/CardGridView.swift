import SwiftUI
import AppKit

/// 模拟实体卡金色金属安全芯片的 3D 立体组件
fileprivate struct CardChipView: View {
    var body: some View {
        ZStack {
            // 芯片金属基底（拉丝金渐变）
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.82, blue: 0.5),
                            Color(red: 1.0, green: 0.95, blue: 0.72),
                            Color(red: 0.78, green: 0.62, blue: 0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.black.opacity(0.15), lineWidth: 0.8)
                )
            
            // 芯片触点金属丝分割线
            GeometryReader { geo in
                Path { path in
                    // 横向分割线
                    path.move(to: CGPoint(x: 0, y: geo.size.height * 0.5))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.5))
                    
                    // 纵向三段线
                    path.move(to: CGPoint(x: geo.size.width * 0.32, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.32, y: geo.size.height))
                    
                    path.move(to: CGPoint(x: geo.size.width * 0.68, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.68, y: geo.size.height))
                }
                .stroke(Color.black.opacity(0.18), lineWidth: 0.8)
            }
            .frame(width: 32, height: 24)
            
            // 中部核心触点微孔
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.black.opacity(0.12))
                .frame(width: 6, height: 5)
        }
        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.8)
    }
}

/// 极具科技感的银行卡磁贴组件 (1:1.586 黄金比例)
public struct CreditCardView: View {
    public let card: SharedCard
    
    // 显示/隐藏敏感数据控制
    @State private var isShowingNumber = false
    @State private var isShowingCVV = false
    @State private var remainingShowSeconds = 5.0
    
    @State private var isHovered = false
    
    public var onEdit: () -> Void
    public var onViewDetails: () -> Void
    public var onDelete: () -> Void
    public var onUpdateStatus: (String) -> Void
    
    private var brand: CardBrand {
        return CardBrand.detect(from: card.cardNumber, level: card.level)
    }
    
    private var isDebitCard: Bool {
        card.cardCategory == "debit"
    }
    
    public init(
        card: SharedCard,
        onEdit: @escaping () -> Void,
        onViewDetails: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onUpdateStatus: @escaping (String) -> Void
    ) {
        self.card = card
        self.onEdit = onEdit
        self.onViewDetails = onViewDetails
        self.onDelete = onDelete
        self.onUpdateStatus = onUpdateStatus
    }
    
    public var body: some View {
        ZStack {
            // 1. 卡片高级微渐变底色
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: getBrandGradient(brand),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 2. 覆盖一层对角拉丝光泽，增加质感
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.clear, Color.black.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
            
            // 3. 极富未来科技感的几何镭射防伪波纹线
            Canvas { context, size in
                context.stroke(
                    Path { path in
                        // 第一条大正弦波线
                        path.move(to: CGPoint(x: 0, y: size.height * 0.75))
                        path.addCurve(
                            to: CGPoint(x: size.width, y: size.height * 0.25),
                            control1: CGPoint(x: size.width * 0.35, y: size.height * 0.95),
                            control2: CGPoint(x: size.width * 0.65, y: size.height * 0.05)
                        )
                        // 第二条紧挨着的平行波线
                        path.move(to: CGPoint(x: 0, y: size.height * 0.83))
                        path.addCurve(
                            to: CGPoint(x: size.width, y: size.height * 0.33),
                            control1: CGPoint(x: size.width * 0.35, y: size.height * 1.03),
                            control2: CGPoint(x: size.width * 0.65, y: size.height * 0.13)
                        )
                    },
                    with: .linearGradient(
                        Gradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.02), Color.clear]),
                        startPoint: CGPoint(x: 0, y: size.height * 0.5),
                        endPoint: CGPoint(x: size.width, y: size.height * 0.5)
                    ),
                    lineWidth: 1.0
                )
            }
            .allowsHitTesting(false)
            
            // 4. 双重精致描边，营造微弱的发光切边质感
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.05), Color.black.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
                .shadow(color: getShadowColor(brand).opacity(isHovered ? 0.45 : 0.18), radius: isHovered ? 12 : 6, x: 0, y: 4)
            
            // 5. 内容布局
            VStack(alignment: .leading, spacing: 0) {
                // 顶部：银行名 & 半透明磨砂底片包裹的卡标
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.bank)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 1, x: 0, y: 1)
                        if let alias = card.alias, !alias.isEmpty {
                            Text(alias)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.65))
                                .shadow(color: Color.black.opacity(0.25), radius: 0.5, x: 0, y: 0.5)
                        }
                    }
                    Spacer()
                    
                    Button(action: onViewDetails) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .help("查看详情")
                    .padding(.trailing, 4)

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 44, height: 26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                        
                        CardBrandIcon(brand: brand)
                            .scaleEffect(0.82)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                
                Spacer()
                
                // 中部偏上：金属安全芯片与无线闪付标（极富金融卡片质感）
                HStack(spacing: 8) {
                    CardChipView()
                    
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                
                Spacer()
                
                // 中部：卡号（支持一键防窥切换）
                HStack(spacing: 8) {
                    Text(getFormattedCardNumber())
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.65), radius: 1, x: 0, y: 1.2)
                        .tracking(1.2)
                    
                    Button {
                        toggleNumberVisibility()
                    } label: {
                        Image(systemName: isShowingNumber ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    
                    // 5秒自动遮罩的极简倒计时圆环
                    if isShowingNumber {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
                                .frame(width: 12, height: 12)
                            Circle()
                                .trim(from: 0, to: CGFloat(remainingShowSeconds / 5.0))
                                .stroke(Color.cyan, lineWidth: 1.2)
                                .frame(width: 12, height: 12)
                                .rotationEffect(.degrees(-90))
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // 底部：有效期、CVV 还有年费/限额状态
                HStack(alignment: .bottom) {
                    // 有效期与 CVV
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VALID THRU")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        Text(card.valid ?? "00/00")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 0.5, x: 0, y: 0.5)
                        
                        HStack(spacing: 4) {
                            Text("CVV:")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                            Text(isShowingCVV ? (card.cvv ?? "•••") : "•••")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.35), radius: 0.5, x: 0, y: 0.5)
                            
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
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleCVVVisibility()
                        }
                    }
                    
                    Spacer()
                    
                    // 信用卡展示额度与免息期，储蓄卡展示币种
                    VStack(alignment: .trailing, spacing: 4) {
                        let limitType = isDebitCard ? "币种" : (card.isSharedLimit ? "共享额度" : "独立额度")
                        Text(limitType)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        
                        let symbol = getCurrencySymbol(card.type ?? "CNY")
                        Text(isDebitCard ? (card.type ?? "CNY") : "\(symbol)\(Int(card.limit ?? 0).description)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 0.5, x: 0, y: 0.5)
                        
                        if !isDebitCard {
                            // 免息天数显示
                            let days = DateCalculator.calculateInterestFreePeriod(
                                accountBillDate: card.accountBillDate ?? "",
                                dueDate: card.dueDate ?? "",
                                billingDayToNextBill: card.billingDaySpendingToNextBill
                            )
                            Text("免息期: \(days)天")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.15))
                                .cornerRadius(4)
                        }
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
            if !isDebitCard {
                Section(header: Text("年费达标快捷标记")) {
                    Button { onUpdateStatus("1") } label: {
                        Label("确认本周期已达标", systemImage: "checkmark.circle.fill")
                    }
                    Button { onUpdateStatus("2") } label: {
                        Label("未达标", systemImage: "exclamationmark.circle.fill")
                    }
                    Button { onUpdateStatus("3") } label: {
                        Label("终免年费", systemImage: "infinity.circle.fill")
                    }
                }
                
                Divider()
            }
            
            Button(action: onViewDetails) {
                Label("查看详情", systemImage: "info.circle")
            }
            
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

struct CardDetailView: View {
    let card: SharedCard
    var onEdit: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showFullCardNumber = false
    @State private var showCVV = false
    @State private var selectedImageIndex = 0
    
    private var brand: CardBrand {
        CardBrand.detect(from: card.cardNumber, level: card.level)
    }
    
    private var isDebitCard: Bool {
        card.cardCategory == "debit"
    }
    
    private var cardCategoryText: String {
        isDebitCard ? "储蓄卡" : "信用卡"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    
                    if !card.cardImages.isEmpty {
                        mediaSection
                    }
                    
                    CardDetailSection(title: "核心信息", systemImage: "creditcard.fill") {
                        CardDetailInfoRow(title: "卡类别", value: cardCategoryText)
                        CardDetailInfoRow(title: "国家/地区", value: cleanValue(card.country))
                        CardDetailInfoRow(title: "发卡银行", value: cleanValue(card.bank))
                        CardDetailInfoRow(title: "卡片别名", value: cleanValue(card.alias))
                        CardDetailInfoRow(title: "卡片等级", value: cleanValue(card.level))
                        CardDetailInfoRow(title: "卡组织", value: brand.displayName)
                        CardDetailInfoRow(title: "有效期", value: cleanValue(card.valid))
                        sensitiveRow(
                            title: "卡号",
                            value: formattedCardNumber(masked: !showFullCardNumber),
                            isVisible: showFullCardNumber,
                            action: { showFullCardNumber.toggle() }
                        )
                        sensitiveRow(
                            title: "CVV 安全码",
                            value: showCVV ? cleanValue(card.cvv) : "•••",
                            isVisible: showCVV,
                            action: { showCVV.toggle() }
                        )
                    }
                    
                    if !isDebitCard {
                        CardDetailSection(title: "额度与年费", systemImage: "banknote.fill") {
                            CardDetailInfoRow(title: "币种", value: cleanValue(card.type))
                            CardDetailInfoRow(title: "额度", value: amountText(card.limit, currency: card.type))
                            CardDetailInfoRow(title: "额度类型", value: card.isSharedLimit ? "共享额度" : "独立额度")
                            CardDetailInfoRow(title: "年费", value: amountText(card.annualFee, currency: card.type))
                            CardDetailInfoRow(title: "年费减免政策", value: annualFeeStatusText(card.isQualified))
                            CardDetailInfoRow(title: "下次年费收取", value: timestampDateText(card.nextAnnualFeeCollectionTime))
                            CardDetailInfoRow(title: "上次提额时间", value: timestampDateText(card.lastTime))
                        }
                    }
                    
                    CardDetailSection(title: isDebitCard ? "权益与备注" : "账单与权益", systemImage: "calendar.badge.clock") {
                        if !isDebitCard {
                            CardDetailInfoRow(title: "账单日", value: dayText(card.accountBillDate))
                            CardDetailInfoRow(title: "还款日", value: dayText(card.dueDate))
                            CardDetailInfoRow(title: "账单日消费归属", value: card.billingDaySpendingToNextBill ? "下期账单" : "当期账单")
                            CardDetailInfoRow(title: "最长免息期", value: interestFreePeriodText)
                        } else {
                            CardDetailInfoRow(title: "币种", value: cleanValue(card.type))
                        }
                        CardDetailInfoRow(title: "最后修改时间", value: DateCalculator.formatTimestampDateTime(card.lastModifyTime))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("权益")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(cleanValue(card.equity))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("备注")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(cleanValue(card.remark))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(24)
            }
            .navigationTitle("\(cardCategoryText)详情")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onEdit()
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .keyboardShortcut("e", modifiers: [.command])
                }
            }
        }
        .frame(minWidth: 680, minHeight: 720)
    }
    
    private var headerCard: some View {
        ZStack(alignment: .topTrailing) {
            // 1. 卡片高级微渐变底色
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: getBrandGradient(brand),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 2. 覆盖一层精致的对角拉丝反光效果，增加金属光亮质感
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.clear, Color.black.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
            
            // 3. 极富未来科技感的几何镭射防伪波纹线
            Canvas { context, size in
                context.stroke(
                    Path { path in
                        // 第一条大正弦波线
                        path.move(to: CGPoint(x: 0, y: size.height * 0.72))
                        path.addCurve(
                            to: CGPoint(x: size.width, y: size.height * 0.22),
                            control1: CGPoint(x: size.width * 0.35, y: size.height * 0.92),
                            control2: CGPoint(x: size.width * 0.65, y: size.height * 0.02)
                        )
                        // 第二条紧挨着的平行波线
                        path.move(to: CGPoint(x: 0, y: size.height * 0.8))
                        path.addCurve(
                            to: CGPoint(x: size.width, y: size.height * 0.3),
                            control1: CGPoint(x: size.width * 0.35, y: size.height * 1.0),
                            control2: CGPoint(x: size.width * 0.65, y: size.height * 0.1)
                        )
                    },
                    with: .linearGradient(
                        Gradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.02), Color.clear]),
                        startPoint: CGPoint(x: 0, y: size.height * 0.5),
                        endPoint: CGPoint(x: size.width, y: size.height * 0.5)
                    ),
                    lineWidth: 1.2
                )
            }
            .allowsHitTesting(false)
            
            // 4. 双重精致描边
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.32), Color.white.opacity(0.05), Color.black.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
            
            // 5. 信息布局
            VStack(alignment: .leading, spacing: 0) {
                // 顶部：发卡行名字，别名，卡组织 Logo
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.bank)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 1, x: 0, y: 1)
                        
                        if let alias = card.alias, !alias.isEmpty {
                            Text(alias)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                                .shadow(color: Color.black.opacity(0.25), radius: 0.5, x: 0, y: 0.5)
                        }
                    }
                    
                    Spacer()
                    
                    // 用精致的半透明白色圆角底板包裹卡组织 Logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 52, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                            )
                        
                        CardBrandIcon(brand: brand)
                            .scaleEffect(0.95)
                    }
                }
                .padding(.top, 22)
                .padding(.horizontal, 22)
                
                Spacer()
                
                // 中部：金色立体安全芯片与闪付波纹
                HStack(spacing: 8) {
                    CardChipView()
                        .scaleEffect(1.1)
                    
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 6)
                
                Spacer()
                
                // 卡号
                Text(formattedCardNumber(masked: !showFullCardNumber))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.65), radius: 1, x: 0, y: 1.2)
                    .lineLimit(1)
                    .padding(.horizontal, 22)
                
                Spacer()
                
                // 底部：有效期与额度信息
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VALID THRU")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        let validText = card.valid ?? ""
                        Text(validText.isEmpty ? "--/--" : validText)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 0.5, x: 0, y: 0.5)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(isDebitCard ? "币种" : (card.isSharedLimit ? "共享额度" : "独立额度"))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        Text(isDebitCard ? (card.type ?? "CNY").uppercased() : amountText(card.limit, currency: card.type))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 0.5, x: 0, y: 0.5)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
        }
        .frame(height: 250)
    }
    
    private var mediaSection: some View {
        CardDetailSection(title: "卡片媒体文件", systemImage: "photo.on.rectangle.angled") {
            let images = card.cardImages
            let currentIndex = min(selectedImageIndex, max(images.count - 1, 0))
            let asset = images[currentIndex]

            Text("共 \(images.count) 张图片 · 附件总大小 \(formatFileSize(images.reduce(0) { $0 + imageByteSize($1) }))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            ZStack(alignment: .topTrailing) {
                if let image = nsImage(from: asset) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 320)
                        .overlay(Text("无法预览").foregroundStyle(.secondary))
                }
                
                Text("\(currentIndex + 1)/\(images.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(10)
            }
            
            HStack {
                Button {
                    selectedImageIndex = max(0, currentIndex - 1)
                } label: {
                    Label("上一张", systemImage: "chevron.left")
                }
                .disabled(images.count <= 1 || currentIndex == 0)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(asset.name.isEmpty ? "图片 \(currentIndex + 1)" : asset.name)
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("上传时间 \(formatImageUploadTime(asset.createdAt)) · 文件大小 \(formatFileSize(imageByteSize(asset)))")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    selectedImageIndex = min(images.count - 1, currentIndex + 1)
                } label: {
                    Label("下一张", systemImage: "chevron.right")
                }
                .disabled(images.count <= 1 || currentIndex >= images.count - 1)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(images.indices, id: \.self) { index in
                        VStack(spacing: 3) {
                            Button {
                                selectedImageIndex = index
                            } label: {
                                if let thumbnail = nsImage(from: images[index]) {
                                    Image(nsImage: thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 88, height: 58)
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                } else {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.primary.opacity(0.08))
                                        .frame(width: 88, height: 58)
                                        .overlay(Image(systemName: "photo"))
                                }
                            }
                            .buttonStyle(.plain)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(selectedImageIndex == index ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            Text(formatFileSize(imageByteSize(images[index])))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func imageByteSize(_ asset: CardImageAsset) -> Int64 {
        let base64 = asset.data.components(separatedBy: "base64,").last ?? asset.data
        return Int64(Data(base64Encoded: base64, options: .ignoreUnknownCharacters)?.count ?? 0)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }

    private func formatImageUploadTime(_ timestamp: Double) -> String {
        guard timestamp > 0 else { return "未知" }
        let seconds = timestamp < 1_000_000_000_000 ? timestamp : timestamp / 1000
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: seconds))
    }
    
    private var interestFreePeriodText: String {
        guard let billDay = card.accountBillDate, !billDay.isEmpty,
              let dueDay = card.dueDate, !dueDay.isEmpty else {
            return "未配置"
        }
        let days = DateCalculator.calculateInterestFreePeriod(
            accountBillDate: billDay,
            dueDate: dueDay,
            billingDayToNextBill: card.billingDaySpendingToNextBill
        )
        return "\(days) 天"
    }
    
    private func sensitiveRow(title: String, value: String, isVisible: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: action) {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
            }
            .buttonStyle(.borderless)
            .help(isVisible ? "隐藏" : "显示")
        }
        .padding(.vertical, 4)
    }
    
    private func cleanValue(_ value: String?) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未配置" : trimmed
    }
    
    private func amountText(_ value: Double?, currency: String?) -> String {
        guard let value else { return "未配置" }
        let formattedValue = value.rounded(.towardZero) == value ? String(Int(value)) : String(format: "%.2f", value)
        let currencyCode = cleanValue(currency)
        if currencyCode == "未配置" {
            return formattedValue
        }
        return "\(currencyCode) \(getCurrencySymbol(currencyCode))\(formattedValue)"
    }
    
    private func dayText(_ value: String?) -> String {
        let cleaned = cleanValue(value)
        return cleaned == "未配置" ? cleaned : "每月 \(cleaned) 号"
    }
    
    private func timestampDateText(_ timestamp: Double?) -> String {
        let dateText = DateCalculator.formatTimestampDate(timestamp)
        guard !dateText.isEmpty else { return "未配置" }
        let delta = DateCalculator.getDaysFromNow(timestamp)
        guard !delta.text.isEmpty else { return dateText }
        return "\(dateText)（\(delta.text) \(delta.days) 天）"
    }
    
    private func annualFeeStatusText(_ value: String?) -> String {
        switch value {
        case "1": return "已达标"
        case "2": return "未达标"
        case "3": return "终免年费"
        default: return "未配置"
        }
    }
    
    private func formattedCardNumber(masked: Bool) -> String {
        let cleanNumber = card.cardNumber.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        if masked {
            return "••••  ••••  ••••  \(cleanNumber.suffix(4))"
        }
        
        var result = ""
        for (index, char) in cleanNumber.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += "  "
            }
            result.append(char)
        }
        return result
    }
    
    private func nsImage(from asset: CardImageAsset) -> NSImage? {
        let base64 = asset.data.components(separatedBy: "base64,").last ?? asset.data
        guard let data = Data(base64Encoded: base64) else { return nil }
        return NSImage(data: data)
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
    
    private func getCurrencySymbol(_ type: String) -> String {
        switch type {
        case "CNY": return "¥"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "HKD": return "HK$"
        default: return ""
        }
    }
}

private struct CardDetailSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content
    
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.cyan)
                Text(title)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

private struct CardDetailInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

/// 用于表示分组银行卡的内部中转结构体
public struct CardGroup: Identifiable {
    public let id = UUID()
    public let name: String
    public let iconName: String
    public let cards: [SharedCard]
    public let totalLimit: Double
}

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
    @Environment(\.colorScheme) private var colorScheme
    
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
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 1. 左侧动态霓虹指示条 (代替传统箭头，全新的指示反馈)
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: isCollapsed 
                                ? [Color.gray.opacity(0.35), Color.gray.opacity(0.55)] 
                                : [Color.cyan, Color.blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: isCollapsed ? 14 : 18)
                    .shadow(color: isCollapsed ? Color.clear : Color.cyan.opacity(0.5), radius: isCollapsed ? 0 : 4)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isCollapsed)
                
                // 2. 扁平分组图标
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isCollapsed ? .secondary : .cyan)
                    .frame(width: 20, height: 20)
                
                // 3. 类别名称 (极简高阶字体)
                Text(name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black.opacity(0.85))
                
                // 4. 精致的 Cards 计数标签 (扁平极简 Outline)
                Text("\(cardCount) Cards")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(4)
                
                Spacer()
                
                // 5. 信用卡授信数额块 (极简扁平无边框)
                HStack(spacing: 4) {
                    Image(systemName: "banknote")
                        .font(.system(size: 10))
                        .foregroundColor(.green.opacity(0.8))
                    Text("信用额度 ¥\(Int(totalLimit).description)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.08))
                .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onHover { hover in
                isHovered = hover
            }
            
            // 6. 底层装饰微光分隔线 (只在展开状态下呈现，优雅顺滑)
            if !isCollapsed {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                    .transition(.scale(scale: 0.95, anchor: .leading).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.02) : Color.clear)
        )
        .padding(.horizontal, 12)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

/// 银行卡包主视图 (支持多维分组与组合排序，以及分组折叠)
public struct CardGridView: View {
    public var cards: [SharedCard]
    public var groupBy: GroupOption
    public var sortBy: SortOption
    
    public var onEdit: (SharedCard) -> Void
    public var onViewDetails: (SharedCard) -> Void
    public var onDelete: (SharedCard) -> Void
    public var onUpdateStatus: (SharedCard, String) -> Void
    
    // 💡 用于追踪各个分组当前是否已折叠收起的集合
    @State private var collapsedGroups: Set<String> = []
    
    // 💡 性能优化：缓存分组和排序后的结果，避免每次渲染 body 时都在主线程重复进行高开销的日期和分组计算
    @State private var processedGroups: [CardGroup] = []
    
    // 双栏网格自适应配置
    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 450), spacing: 20)
    ]
    
    public init(
        cards: [SharedCard],
        groupBy: GroupOption = .none,
        sortBy: SortOption = .limitDesc,
        onEdit: @escaping (SharedCard) -> Void,
        onViewDetails: @escaping (SharedCard) -> Void,
        onDelete: @escaping (SharedCard) -> Void,
        onUpdateStatus: @escaping (SharedCard, String) -> Void
    ) {
        self.cards = cards
        self.groupBy = groupBy
        self.sortBy = sortBy
        self.onEdit = onEdit
        self.onViewDetails = onViewDetails
        self.onDelete = onDelete
        self.onUpdateStatus = onUpdateStatus
        
        // 💡 首次构建时进行单次预处理计算，防止第一帧出现白屏或闪烁
        let initialGroups = CardGridView.calculateGroups(cards: cards, groupBy: groupBy, sortBy: sortBy)
        self._processedGroups = State(initialValue: initialGroups)
    }
    
    private func performGroupingAndSorting() {
        processedGroups = CardGridView.calculateGroups(cards: cards, groupBy: groupBy, sortBy: sortBy)
    }
    
    /// 静态辅助方法：只在核心依赖发生变化时运行，对数据进行重组和排序
    private static func calculateGroups(cards: [SharedCard], groupBy: GroupOption, sortBy: SortOption) -> [CardGroup] {
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
        let groups = rawGroups.map { name, groupCards -> CardGroup in
            let sorted = groupCards.sorted { c1, c2 in
                switch sortBy {
                case .limitDesc:
                    return (c1.cardCategory == "debit" ? 0 : (c1.limit ?? 0)) > (c2.cardCategory == "debit" ? 0 : (c2.limit ?? 0))
                case .limitAsc:
                    return (c1.cardCategory == "debit" ? 0 : (c1.limit ?? 0)) < (c2.cardCategory == "debit" ? 0 : (c2.limit ?? 0))
                case .daysDesc:
                    let days1 = c1.cardCategory == "debit" ? -1 : DateCalculator.calculateInterestFreePeriod(
                        accountBillDate: c1.accountBillDate ?? "",
                        dueDate: c1.dueDate ?? "",
                        billingDayToNextBill: c1.billingDaySpendingToNextBill
                    )
                    let days2 = c2.cardCategory == "debit" ? -1 : DateCalculator.calculateInterestFreePeriod(
                        accountBillDate: c2.accountBillDate ?? "",
                        dueDate: c2.dueDate ?? "",
                        billingDayToNextBill: c2.billingDaySpendingToNextBill
                    )
                    return days1 > days2
                case .daysAsc:
                    let days1 = c1.cardCategory == "debit" ? Int.max : DateCalculator.calculateInterestFreePeriod(
                        accountBillDate: c1.accountBillDate ?? "",
                        dueDate: c1.dueDate ?? "",
                        billingDayToNextBill: c1.billingDaySpendingToNextBill
                    )
                    let days2 = c2.cardCategory == "debit" ? Int.max : DateCalculator.calculateInterestFreePeriod(
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
                    guard card.cardCategory != "debit" else { continue }
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
        return groups.sorted { g1, g2 in
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
                    ForEach(processedGroups.first?.cards ?? []) { card in
                        CreditCardView(
                            card: card,
                            onEdit: { onEdit(card) },
                            onViewDetails: { onViewDetails(card) },
                            onDelete: { onDelete(card) },
                            onUpdateStatus: { status in onUpdateStatus(card, status) }
                        )
                    }
                }
                .padding(20)
            } else {
                // 有分组状态下：使用 VStack 排布，提供一流的交互式透底质感，并确保完美无抖动且极其平滑的收折体验
                VStack(spacing: 16) {
                    // 💡 一键展开/收起控制按钮栏（有超过1个分组时自动浮现，保持界面灵活性）
                    if processedGroups.count > 1 {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    collapsedGroups.removeAll()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.down.circle")
                                    Text("一键展开")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cyan.opacity(0.08))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    let allNames = processedGroups.map { $0.name }
                                    collapsedGroups = Set(allNames)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.up.circle")
                                    Text("一键收起")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, -4)
                    }
                    
                    ForEach(processedGroups) { group in
                        let isCollapsed = collapsedGroups.contains(group.name)
                        
                        VStack(spacing: 0) {
                            GroupSectionHeader(
                                name: group.name,
                                iconName: group.iconName,
                                cardCount: group.cards.count,
                                totalLimit: group.totalLimit,
                                isCollapsed: isCollapsed,
                                onTap: {
                                    // 💡 施加极富平滑性且完全无抖动的标准折拢渐变动画
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isCollapsed {
                                            collapsedGroups.remove(group.name)
                                        } else {
                                            collapsedGroups.insert(group.name)
                                        }
                                    }
                                }
                            )
                            
                            if !isCollapsed {
                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(group.cards) { card in
                                        CreditCardView(
                                            card: card,
                                            onEdit: { onEdit(card) },
                                            onViewDetails: { onViewDetails(card) },
                                            onDelete: { onDelete(card) },
                                            onUpdateStatus: { status in onUpdateStatus(card, status) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                // 💡 渐透淡入淡出转场，防止卡片瞬间消失（闪烁），保证极其丝滑平顺的视觉过渡
                                .transition(.opacity)
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .onAppear {
            performGroupingAndSorting()
        }
        .onChange(of: cards) { _, _ in
            performGroupingAndSorting()
        }
        .onChange(of: groupBy) { _, _ in
            performGroupingAndSorting()
        }
        .onChange(of: sortBy) { _, _ in
            performGroupingAndSorting()
        }
    }
}
