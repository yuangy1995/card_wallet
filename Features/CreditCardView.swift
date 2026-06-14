import SwiftUI

/// 液态玻璃风格银行卡组件（1:1.586 黄金比例，iOS 26 原生 glassEffect）
struct CreditCardView: View {
    let card: SharedCard
    var onTap: (() -> Void)?

    @State private var isShowingNumber = false
    @State private var isShowingCVV = false
    @State private var remainingShowSeconds = 5.0
    @State private var countdownTimer: Timer?
    @State private var isPressed = false

    private var brand: CardBrand {
        CardBrand.detect(from: card.cardNumber, level: card.level)
    }

    private var isDebitCard: Bool { card.cardCategory == "debit" }

    private var brandGradient: [Color] {
        switch brand {
        case .visa:
            return [Color(hex: "#1A1F71"), Color(hex: "#2B3DA0"), Color(hex: "#0D1156")]
        case .mastercard:
            return [Color(hex: "#1A1A2E"), Color(hex: "#16213E"), Color(hex: "#0F3460")]
        case .amex:
            return [Color(hex: "#00416A"), Color(hex: "#007BC1"), Color(hex: "#003554")]
        case .unionpay:
            return [Color(hex: "#8B0000"), Color(hex: "#CC0000"), Color(hex: "#5C0000")]
        case .discover:
            return [Color(hex: "#8B3A00"), Color(hex: "#CC5500"), Color(hex: "#5C2400")]
        case .dinersClub:
            return [Color(hex: "#1A1A1A"), Color(hex: "#2D2D2D"), Color(hex: "#0D0D0D")]
        case .jcb:
            return [Color(hex: "#002266"), Color(hex: "#003399"), Color(hex: "#001A4D")]
        case .unknown:
            return [Color(hex: "#1C1C3A"), Color(hex: "#2A2A4A"), Color(hex: "#0E0E25")]
        }
    }

    private var glowColor: Color {
        switch brand {
        case .visa:       return Color(hex: "#4060FF")
        case .mastercard: return Color(hex: "#FF6B6B")
        case .amex:       return Color(hex: "#00BFFF")
        case .unionpay:   return Color(hex: "#FF4444")
        case .discover:   return Color(hex: "#FF8800")
        case .dinersClub: return Color.white
        case .jcb:        return Color(hex: "#4488FF")
        case .unknown:    return Color.cyan
        }
    }

    var body: some View {
        let cardWidth = UIScreen.main.bounds.width - 40
        let cardHeight = cardWidth / 1.586

        ZStack {
            // 1. 渐变底层
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: brandGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 2. 液态玻璃高光层
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 3. 芯片装饰图案
            VStack {
                HStack {
                    Spacer()
                    chipDecoration
                        .padding(.top, 18)
                        .padding(.trailing, 18)
                }
                Spacer()
            }

            // 4. 底部装饰流光横条
            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, glowColor.opacity(0.15), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.5)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
            }

            // 5. 卡片内容
            VStack(alignment: .leading, spacing: 0) {
                // 顶部：银行 + 品牌图标
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.bank)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if let alias = card.alias, !alias.isEmpty {
                            Text(alias)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        // 卡类型徽章
                        Text(isDebitCard ? "储蓄卡" : "信用卡")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(isDebitCard ? Color(hex: "#FFD700") : Color.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(isDebitCard ? Color(hex: "#FFD700").opacity(0.2) : Color.cyan.opacity(0.2))
                            )
                    }
                    Spacer()
                    CardBrandIcon(brand: brand, size: 32)
                }
                .padding(.top, 18)
                .padding(.horizontal, 20)

                Spacer()

                // 中部：卡号
                HStack(alignment: .center, spacing: 10) {
                    Text(formattedCardNumber())
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Button {
                        toggleNumberVisibility()
                    } label: {
                        Image(systemName: isShowingNumber ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)

                    if isShowingNumber {
                        countdownRing
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // 底部：有效期 + CVV + 年费状态
                HStack(alignment: .bottom) {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("VALID THRU")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1.5)
                            Text(card.valid ?? "--/--")
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("CVV")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1.5)
                            Button {
                                withAnimation(.spring(duration: 0.2)) { isShowingCVV.toggle() }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(isShowingCVV ? (card.cvv ?? "•••") : "•••")
                                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                                        .foregroundColor(.white)
                                    Image(systemName: isShowingCVV ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    // 年费状态指示
                    annualFeeStatusBadge

                    // 额度显示
                    if let limit = card.limit, limit > 0, !isDebitCard {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("额度")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1.5)
                            Text(formatLimit(limit))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            // 6. 霓虹描边
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [glowColor.opacity(0.6), Color.white.opacity(0.2), glowColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: glowColor.opacity(0.35), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(duration: 0.25, bounce: 0.3), value: isPressed)
        .onTapGesture {
            onTap?()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    // MARK: - 子视图

    private var chipDecoration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FFD700").opacity(0.9), Color(hex: "#B8860B").opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 24)
            // 芯片触点线条
            VStack(spacing: 3) {
                ForEach(0..<3) { _ in
                    Rectangle()
                        .fill(Color(hex: "#B8860B").opacity(0.6))
                        .frame(width: 20, height: 0.8)
                }
            }
        }
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                .frame(width: 16, height: 16)
            Circle()
                .trim(from: 0, to: CGFloat(remainingShowSeconds / 5.0))
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(-90))
        }
    }

    private var annualFeeStatusBadge: some View {
        Group {
            if let result = DateCalculator.annualFeeDetection(for: card) {
                let (color, icon): (Color, String) = {
                    switch result.kind {
                    case .unqualified: return (.orange, "exclamationmark.circle.fill")
                    case .warning:     return (.yellow, "clock.badge.exclamationmark.fill")
                    case .overdue:     return (.red, "xmark.circle.fill")
                    }
                }()
                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(color)
                    Text("\(result.days)天")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(color)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Capsule().fill(color.opacity(0.2)))
            }
        }
    }

    // MARK: - Helpers

    private func formattedCardNumber() -> String {
        let clean = card.cardNumber.replacingOccurrences(of: " ", with: "")
        if !isShowingNumber {
            if clean.count >= 16 {
                let last4 = String(clean.suffix(4))
                return "•••• •••• •••• \(last4)"
            } else if clean.count >= 4 {
                let last4 = String(clean.suffix(4))
                return String(repeating: "• ", count: clean.count - 4) + last4
            }
            return String(repeating: "•", count: max(clean.count, 16))
        }
        var result = ""
        for (index, char) in clean.enumerated() {
            if index > 0 && index % 4 == 0 { result += " " }
            result.append(char)
        }
        return result
    }

    private func formatLimit(_ limit: Double) -> String {
        let currency = (card.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !currency.isEmpty else {
            return limit >= 10000 ? "\(Int(limit / 10000))万" : "\(Int(limit))"
        }
        let symbol: String
        switch currency {
        case "CNY", "CNH": symbol = "¥"
        case "USD": symbol = "$"
        case "HKD": symbol = "HK$"
        case "EUR": symbol = "€"
        case "JPY": symbol = "JP¥"
        case "GBP": symbol = "£"
        default: symbol = currency + " "
        }
        if limit >= 10000 {
            return "\(symbol)\(Int(limit / 10000))万"
        }
        return "\(symbol)\(Int(limit))"
    }

    private func toggleNumberVisibility() {
        countdownTimer?.invalidate()
        isShowingNumber.toggle()
        if isShowingNumber {
            remainingShowSeconds = 5.0
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    remainingShowSeconds -= 0.1
                    if remainingShowSeconds <= 0 {
                        countdownTimer?.invalidate()
                        withAnimation { isShowingNumber = false }
                    }
                }
            }
        }
    }
}

// MARK: - 迷你卡片（列表行用）
struct CreditCardMiniView: View {
    let card: SharedCard

    private var brand: CardBrand {
        CardBrand.detect(from: card.cardNumber, level: card.level)
    }

    var body: some View {
        HStack(spacing: 14) {
            // 左侧小卡面色块
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: brandGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 34)
                .overlay(
                    CardBrandIcon(brand: brand, size: 20)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                )
                .shadow(color: glowColor.opacity(0.3), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(card.bank)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    if let alias = card.alias, !alias.isEmpty {
                        Text(alias)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    // 末四位
                    Text("•••• \(String(card.cardNumber.filter { $0.isNumber }.suffix(4)))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    if let limit = card.limit, limit > 0, card.cardCategory != "debit" {
                        Text(formatLimit(limit))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()

            // 年费预警指示
            if let result = DateCalculator.annualFeeDetection(for: card) {
                Image(systemName: result.kind == .overdue ? "xmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(result.kind == .overdue ? .red : .orange)
                    .font(.system(size: 14))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.vertical, 6)
    }

    private var brandGradient: [Color] {
        switch brand {
        case .visa:       return [Color(hex: "#1A1F71"), Color(hex: "#2B3DA0")]
        case .mastercard: return [Color(hex: "#1A1A2E"), Color(hex: "#16213E")]
        case .amex:       return [Color(hex: "#00416A"), Color(hex: "#007BC1")]
        case .unionpay:   return [Color(hex: "#8B0000"), Color(hex: "#CC0000")]
        case .discover:   return [Color(hex: "#8B3A00"), Color(hex: "#CC5500")]
        case .dinersClub: return [Color(hex: "#1A1A1A"), Color(hex: "#2D2D2D")]
        case .jcb:        return [Color(hex: "#002266"), Color(hex: "#003399")]
        case .unknown:    return [Color(hex: "#1C1C3A"), Color(hex: "#2A2A4A")]
        }
    }

    private var glowColor: Color {
        switch brand {
        case .visa:       return Color(hex: "#4060FF")
        case .mastercard: return Color(hex: "#FF6B6B")
        case .amex:       return Color(hex: "#00BFFF")
        case .unionpay:   return Color(hex: "#FF4444")
        case .discover:   return Color(hex: "#FF8800")
        case .dinersClub: return Color.white
        case .jcb:        return Color(hex: "#4488FF")
        case .unknown:    return Color.cyan
        }
    }

    private func formatLimit(_ limit: Double) -> String {
        let symbol = currencySymbol(for: card.type ?? "")
        if limit >= 10000 { return "\(symbol)\(Int(limit / 10000))万" }
        return "\(symbol)\(Int(limit))"
    }

    private func currencySymbol(for currency: String) -> String {
        let normalizedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCurrency.isEmpty else { return "" }
        switch normalizedCurrency {
        case "CNY", "CNH": return "¥"
        case "USD": return "$"
        case "HKD": return "HK$"
        case "EUR": return "€"
        case "JPY": return "JP¥"
        case "GBP": return "£"
        default: return normalizedCurrency + " "
        }
    }
}
