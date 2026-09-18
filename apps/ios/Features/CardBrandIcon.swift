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
