import SwiftUI

/// Offline network artwork shared with Android; display hint, not a BIN/ownership check.
public struct CardBrandIcon: View {
    public let brand: CardBrand
    public var onCard: Bool
    public var width: CGFloat
    public var height: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    public init(brand: CardBrand, onCard: Bool = false, width: CGFloat = 40, height: CGFloat = 24) {
        self.brand = brand
        self.onCard = onCard
        self.width = width
        self.height = height
    }

    public var body: some View {
        WalletBrandImage(resource: brand.logoResource, label: NSLocalizedString(brand.displayName, comment: ""),
                         lightMark: onCard,
                         whiteTemplate: (onCard || colorScheme == .dark) && (brand == .visa || brand == .amex),
                         width: width, height: height)
    }
}

extension CardBrand {
    var logoResource: String? {
        guard self != .unknown else { return nil }
        return "wallet_network_" + (self == .dinersClub ? "diners" : rawValue)
    }
}
