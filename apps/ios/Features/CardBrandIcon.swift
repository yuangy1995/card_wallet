import SwiftUI

/// Offline artwork; display hint only, preserving the existing iOS sizing API.
struct CardBrandIcon: View {
    let brand: CardBrand
    var size: CGFloat = 38
    var isForCardFace = false
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        WalletBrandImage(resource: brand.logoResource, label: NSLocalizedString(brand.displayName, comment: ""),
                         lightMark: isForCardFace,
                         whiteTemplate: (isForCardFace || colorScheme == .dark) && (brand == .visa || brand == .amex),
                         width: size * 1.65, height: size)
    }
}
extension CardBrand {
    var logoResource: String? {
        guard self != .unknown else { return nil }
        return "wallet_network_" + (self == .dinersClub ? "diners" : rawValue)
    }
}

// Existing utility is also used by the tools page, independently of brand artwork.
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
