import SwiftUI

/// 各卡组织的矢量品牌图标（纯 SwiftUI Canvas 绘制，无外部资源依赖，不带外包裹背景框，透明背景）
struct CardBrandIcon: View {
    let brand: CardBrand
    var size: CGFloat = 38
    var isForCardFace: Bool = false // 若为 true，则在深色渐变卡面背景上强制选用白色/浅色高反差字样，保障可读性

    var body: some View {
        Group {
            switch brand {
            case .visa:     VisaIcon(size: size, isForCardFace: isForCardFace)
            case .mastercard: MastercardIcon(size: size)
            case .amex:     AmexIcon(size: size, isForCardFace: isForCardFace)
            case .unionpay: UnionPayIcon(size: size)
            case .discover: DiscoverIcon(size: size, isForCardFace: isForCardFace)
            case .dinersClub: DinersClubIcon(size: size, isForCardFace: isForCardFace)
            case .jcb:      JCBIcon(size: size, isForCardFace: isForCardFace)
            case .unknown:  UnknownCardIcon(size: size, isForCardFace: isForCardFace)
            }
        }
        .frame(width: size * 1.65, height: size)
    }
}

// MARK: - Visa
private struct VisaIcon: View {
    let size: CGFloat
    let isForCardFace: Bool
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Text("VISA")
            .font(.system(size: size * 0.55, weight: .black, design: .serif))
            .foregroundColor(isForCardFace ? .white : (colorScheme == .dark ? .white : Color(hex: "#1A1F71")))
            .italic()
            .frame(width: size * 1.65, height: size)
    }
}

// MARK: - Mastercard
private struct MastercardIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#EB001B"))
                .frame(width: size * 0.72, height: size * 0.72)
                .offset(x: -size * 0.18)
            Circle()
                .fill(Color(hex: "#F79E1B"))
                .frame(width: size * 0.72, height: size * 0.72)
                .offset(x: size * 0.18)
            Circle()
                .fill(Color(hex: "#FF5F00"))
                .frame(width: size * 0.3, height: size * 0.72)
                .clipped()
        }
        .frame(width: size * 1.65, height: size)
    }
}

// MARK: - Amex
private struct AmexIcon: View {
    let size: CGFloat
    let isForCardFace: Bool
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let activeColor = isForCardFace ? Color.white : (colorScheme == .dark ? .white : Color(hex: "#007BC1"))
        VStack(spacing: 0) {
            Text("AMERICAN")
                .font(.system(size: size * 0.22, weight: .black))
                .foregroundColor(activeColor.opacity(0.8))
                .tracking(1.5)
            Text("EXPRESS")
                .font(.system(size: size * 0.26, weight: .black))
                .foregroundColor(activeColor)
                .tracking(2)
        }
        .frame(width: size * 1.65, height: size)
    }
}

// MARK: - UnionPay
private struct UnionPayIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            // 三色斜条背景层（直立圆角拼合后，通过 ProjectionTransform 投射斜切为完美的平行四边形）
            HStack(spacing: 0) {
                Color(hex: "#D0121A")
                    .frame(width: size * 0.52)
                Color(hex: "#005B9E")
                    .frame(width: size * 0.54)
                Color(hex: "#007F3E")
                    .frame(width: size * 0.52)
            }
            .frame(width: size * 1.58, height: size * 0.85)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.1))
            .projectionEffect(ProjectionTransform(CGAffineTransform(a: 1, b: 0, c: -0.18, d: 1, tx: 0, ty: 0)))
            
            // 白字前景层，保证单行绝对不折行（保持直立，不进行斜切以保障阅读清晰度）
            HStack(spacing: size * 0.03) {
                Text("银联")
                    .font(.system(size: size * 0.32, weight: .black))
                    .foregroundColor(.white)
                Text("UnionPay")
                    .font(.system(size: size * 0.14, weight: .black))
                    .foregroundColor(.white)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .offset(x: -size * 0.05)
        }
        .frame(width: size * 1.85, height: size)
    }
}


// MARK: - Discover
private struct DiscoverIcon: View {
    let size: CGFloat
    let isForCardFace: Bool
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(spacing: size * 0.02) {
            Text("DISCOVER")
                .font(.system(size: size * 0.3, weight: .black))
                .foregroundColor(isForCardFace ? .white : (colorScheme == .dark ? .white : Color(hex: "#1A1A1A")))
            Circle()
                .fill(Color(hex: "#FF6600"))
                .frame(width: size * 0.4, height: size * 0.4)
        }
        .frame(width: size * 1.65, height: size)
    }
}

// MARK: - DinersClub
private struct DinersClubIcon: View {
    let size: CGFloat
    let isForCardFace: Bool
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let activeColor = isForCardFace ? Color.white : (colorScheme == .dark ? .white : Color(hex: "#0079C1"))
        let activeTextColor = isForCardFace ? Color.white : (colorScheme == .dark ? .white : Color(hex: "#1A1A1A"))
        HStack(spacing: size * 0.08) {
            ZStack {
                Circle()
                    .stroke(activeColor, lineWidth: size * 0.06)
                    .frame(width: size * 0.55, height: size * 0.55)
                Circle()
                    .stroke(activeColor, lineWidth: size * 0.06)
                    .frame(width: size * 0.55, height: size * 0.55)
                    .offset(x: size * 0.16)
            }
            Text("Diners")
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundColor(activeTextColor)
        }
        .frame(width: size * 1.65, height: size)
    }
}

// MARK: - JCB
private struct JCBIcon: View {
    let size: CGFloat
    let isForCardFace: Bool
    var body: some View {
        HStack(spacing: size * 0.03) {
            RoundedRectangle(cornerRadius: size * 0.06)
                .fill(Color(hex: "#003087"))
                .frame(width: size * 0.32, height: size * 0.6)
                .overlay(Text("J").font(.system(size: size * 0.26, weight: .black)).foregroundColor(.white))
            RoundedRectangle(cornerRadius: size * 0.06)
                .fill(Color(hex: "#CC0000"))
                .frame(width: size * 0.32, height: size * 0.6)
                .overlay(Text("C").font(.system(size: size * 0.26, weight: .black)).foregroundColor(.white))
            RoundedRectangle(cornerRadius: size * 0.06)
                .fill(Color(hex: "#009A44"))
                .frame(width: size * 0.32, height: size * 0.6)
                .overlay(Text("B").font(.system(size: size * 0.26, weight: .black)).foregroundColor(.white))
        }
        .frame(width: size * 1.65, height: size)
        .background(
            Group {
                if isForCardFace {
                    RoundedRectangle(cornerRadius: size * 0.1)
                        .fill(Color.white.opacity(0.18))
                        .padding(-size * 0.05)
                }
            }
        )
    }
}

// MARK: - Unknown
private struct UnknownCardIcon: View {
    let size: CGFloat
    let isForCardFace: Bool
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Image(systemName: "creditcard")
            .font(.system(size: size * 0.55))
            .foregroundColor(isForCardFace ? .white.opacity(0.8) : (colorScheme == .dark ? .white.opacity(0.6) : .gray.opacity(0.6)))
            .frame(width: size * 1.65, height: size)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
