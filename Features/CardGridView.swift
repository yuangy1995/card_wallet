import SwiftUI
import AppKit

/// 极具科技感的信用卡磁贴组件 (1:1.586 黄金比例)
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
                    Button(action: onViewDetails) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("查看详情")
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
                    Label("终免年费", systemImage: "infinity.circle.fill")
                }
            }
            
            Divider()
            
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    
                    if !card.cardImages.isEmpty {
                        mediaSection
                    }
                    
                    CardDetailSection(title: "核心信息", systemImage: "creditcard.fill") {
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
                    
                    CardDetailSection(title: "额度与年费", systemImage: "banknote.fill") {
                        CardDetailInfoRow(title: "币种", value: cleanValue(card.type))
                        CardDetailInfoRow(title: "额度", value: amountText(card.limit, currency: card.type))
                        CardDetailInfoRow(title: "额度类型", value: card.isSharedLimit ? "共享额度" : "独立额度")
                        CardDetailInfoRow(title: "年费", value: amountText(card.annualFee, currency: card.type))
                        CardDetailInfoRow(title: "年费减免政策", value: annualFeeStatusText(card.isQualified))
                        CardDetailInfoRow(title: "下次年费收取", value: timestampDateText(card.nextAnnualFeeCollectionTime))
                        CardDetailInfoRow(title: "上次提额时间", value: timestampDateText(card.lastTime))
                    }
                    
                    CardDetailSection(title: "账单与权益", systemImage: "calendar.badge.clock") {
                        CardDetailInfoRow(title: "账单日", value: dayText(card.accountBillDate))
                        CardDetailInfoRow(title: "还款日", value: dayText(card.dueDate))
                        CardDetailInfoRow(title: "账单日消费归属", value: card.billingDaySpendingToNextBill ? "下期账单" : "当期账单")
                        CardDetailInfoRow(title: "最长免息期", value: interestFreePeriodText)
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
            .navigationTitle("信用卡详情")
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
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: getBrandGradient(brand),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.bank)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(cleanValue(card.alias))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    CardBrandIcon(brand: brand)
                        .scaleEffect(1.1)
                }
                
                Spacer()
                
                Text(formattedCardNumber(masked: !showFullCardNumber))
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("VALID THRU")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                        Text(cleanValue(card.valid))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(card.isSharedLimit ? "共享额度" : "独立额度")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                        Text(amountText(card.limit, currency: card.type))
                            .font(.system(.title3, design: .rounded))
                            .bold()
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(22)
        }
        .frame(height: 250)
    }
    
    private var mediaSection: some View {
        CardDetailSection(title: "卡片媒体文件", systemImage: "photo.on.rectangle.angled") {
            let images = card.cardImages
            let currentIndex = min(selectedImageIndex, max(images.count - 1, 0))
            let asset = images[currentIndex]
            
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
                
                Text(asset.name.isEmpty ? "图片 \(currentIndex + 1)" : asset.name)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
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
                    }
                }
                .padding(.vertical, 4)
            }
        }
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

/// 用于表示分组信用卡的内部中转结构体
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
                
                // 5. 授信数额块 (极简扁平无边框)
                HStack(spacing: 4) {
                    Image(systemName: "banknote")
                        .font(.system(size: 10))
                        .foregroundColor(.green.opacity(0.8))
                    Text("¥\(Int(totalLimit).description)")
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

/// 信用卡包主视图 (支持多维分组与组合排序，以及分组折叠)
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
                    ForEach(groupedAndSortedCards) { group in
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
    }
}
