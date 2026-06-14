import SwiftUI

/// 各卡组织的矢量品牌图标（纯 SwiftUI Canvas 绘制，无外部资源依赖）
struct CardBrandIcon: View {
    let brand: CardBrand
    var size: CGFloat = 38

    var body: some View {
        Group {
            switch brand {
            case .visa:     VisaIcon(size: size)
            case .mastercard: MastercardIcon(size: size)
            case .amex:     AmexIcon(size: size)
            case .unionpay: UnionPayIcon(size: size)
            case .discover: DiscoverIcon(size: size)
            case .dinersClub: DinersClubIcon(size: size)
            case .jcb:      JCBIcon(size: size)
            case .unknown:  UnknownCardIcon(size: size)
            }
        }
        .frame(width: size * 1.6, height: size)
    }
}

// MARK: - Visa
private struct VisaIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(
                    LinearGradient(colors: [Color(hex: "#1A1F71"), Color(hex: "#1A1F71").opacity(0.85)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("VISA")
                .font(.system(size: size * 0.42, weight: .black, design: .serif))
                .foregroundStyle(
                    LinearGradient(colors: [Color.white, Color(hex: "#FFD700")],
                                   startPoint: .top, endPoint: .bottom)
                )
                .italic()
        }
        .frame(width: size * 1.6, height: size)
    }
}

// MARK: - Mastercard
private struct MastercardIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#EB001B"))
                .frame(width: size * 0.78, height: size * 0.78)
                .offset(x: -size * 0.22)
            Circle()
                .fill(Color(hex: "#F79E1B"))
                .frame(width: size * 0.78, height: size * 0.78)
                .offset(x: size * 0.22)
            Circle()
                .fill(Color(hex: "#FF5F00"))
                .frame(width: size * 0.36, height: size * 0.78)
                .clipped()
        }
        .frame(width: size * 1.6, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
    }
}

// MARK: - Amex
private struct AmexIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(
                    LinearGradient(colors: [Color(hex: "#007BC1"), Color(hex: "#00A9E0")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            VStack(spacing: 0) {
                Text("AMERICAN")
                    .font(.system(size: size * 0.18, weight: .black))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(1.5)
                Text("EXPRESS")
                    .font(.system(size: size * 0.22, weight: .black))
                    .foregroundColor(.white)
                    .tracking(2)
            }
        }
        .frame(width: size * 1.6, height: size)
    }
}

// MARK: - UnionPay
private struct UnionPayIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(
                    LinearGradient(colors: [Color(hex: "#CC0000"), Color(hex: "#FF3333")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            HStack(spacing: size * 0.06) {
                Text("银联")
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundColor(.white)
                Text("UnionPay")
                    .font(.system(size: size * 0.15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(width: size * 1.6, height: size)
    }
}

// MARK: - Discover
private struct DiscoverIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(
                    LinearGradient(colors: [Color(hex: "#FF6600"), Color(hex: "#FF8C00")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            HStack(spacing: size * 0.04) {
                Text("DISCOVER")
                    .font(.system(size: size * 0.25, weight: .black))
                    .foregroundColor(.white)
                Circle()
                    .fill(
                        LinearGradient(colors: [Color(hex: "#FF6600"), Color(hex: "#FFD700")],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size * 0.5, height: size * 0.5)
                    .shadow(color: .orange.opacity(0.6), radius: 4, x: 0, y: 0)
            }
        }
        .frame(width: size * 1.6, height: size)
    }
}

// MARK: - DinersClub
private struct DinersClubIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(Color(hex: "#1A1A1A"))
            HStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: size * 0.05)
                        .frame(width: size * 0.7, height: size * 0.7)
                    Circle()
                        .stroke(Color.white, lineWidth: size * 0.05)
                        .frame(width: size * 0.7, height: size * 0.7)
                        .offset(x: size * 0.24)
                }
                Text("Diners")
                    .font(.system(size: size * 0.2, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.leading, size * 0.12)
            }
        }
        .frame(width: size * 1.6, height: size)
    }
}

// MARK: - JCB
private struct JCBIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: size * 0.12).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
            HStack(spacing: size * 0.05) {
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(Color(hex: "#003087"))
                    .frame(width: size * 0.38, height: size * 0.72)
                    .overlay(Text("J").font(.system(size: size * 0.32, weight: .black)).foregroundColor(.white))
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(Color(hex: "#CC0000"))
                    .frame(width: size * 0.38, height: size * 0.72)
                    .overlay(Text("C").font(.system(size: size * 0.32, weight: .black)).foregroundColor(.white))
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(Color(hex: "#009A44"))
                    .frame(width: size * 0.38, height: size * 0.72)
                    .overlay(Text("B").font(.system(size: size * 0.32, weight: .black)).foregroundColor(.white))
            }
        }
        .frame(width: size * 1.6, height: size)
    }
}

// MARK: - Unknown
private struct UnknownCardIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(Color.white.opacity(0.15))
            Image(systemName: "creditcard.fill")
                .font(.system(size: size * 0.5))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: size * 1.6, height: size)
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
