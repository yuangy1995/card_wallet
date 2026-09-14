import SwiftUI
import AppKit

/// All marks use their intrinsic aspect ratio. No white container, clipping or synthetic monogram.
struct WalletBankLogo: View {
    let bank: String
    var country = ""
    var onCard = false
    var width: CGFloat = 36
    var height: CGFloat = 32
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let issuer = WalletLogoCatalog.shared.match(name: bank, country: country)
        WalletBrandImage(resource: issuer.map { $0.resource + (onCard || colorScheme == .dark ? "_card" : "") },
                         label: issuer?.name ?? NSLocalizedString(CardBrand.unknown.displayName, comment: ""),
                         lightMark: onCard, width: width, height: height)
    }
}

struct WalletBrandImage: View {
    let resource: String?
    let label: String
    var lightMark = false
    var whiteTemplate = false
    let width: CGFloat
    let height: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var markOpacity: Double {
        if colorScheme == .dark {
            return lightMark ? 0.90 : 0.78
        }
        return lightMark ? 0.90 : 1.0
    }

    var body: some View {
        Group {
            if let resource, NSImage(named: NSImage.Name(resource)) != nil {
                Image(resource)
                    .renderingMode(whiteTemplate ? .template : .original)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .opacity(whiteTemplate || resource.hasSuffix("_card") ? markOpacity : 1.0)
            } else {
                Image(systemName: "creditcard")
                    .resizable().scaledToFit()
                    .padding(4)
                    .foregroundStyle(lightMark ? Color.white.opacity(0.92) : Color.secondary)
            }
        }
        .frame(width: width, height: height)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(resource ?? "wallet-bank-fallback")
    }
}
