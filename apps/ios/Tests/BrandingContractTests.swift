import XCTest
import SwiftUI
import UIKit
@testable import CreditCardIOS

final class BrandingContractTests: XCTestCase {
    private struct Network: Decodable { let number: String; let level: String; let expected: String }
    private struct Issuer: Decodable { let name: String; let country: String; let expected: String? }
    private struct Cases: Decodable { let networks: [Network]; let issuers: [Issuer] }
    private func cases() throws -> Cases {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "branding", withExtension: "json", subdirectory: "fixtures"))
        return try JSONDecoder().decode(Cases.self, from: Data(contentsOf: url))
    }
    func testSharedNetworkBoundariesAndExplicitHints() throws {
        for item in try cases().networks {
            let brand = CardBrand.detect(from: item.number, level: item.level)
            XCTAssertEqual(brand == .dinersClub ? "diners" : brand.rawValue, item.expected, item.number + " / " + item.level)
        }
    }
    func testSharedIssuerAliasesAndFallbacks() throws {
        for item in try cases().issuers {
            XCTAssertEqual(WalletLogoCatalog.shared.match(name: item.name, country: item.country)?.id, item.expected, item.name)
        }
        let conflict = WalletLogoCatalog(entries: [
            WalletIssuerLogo(id: "a", name: "Alpha", aliases: ["Same Bank"], resource: "a"),
            WalletIssuerLogo(id: "b", name: "Beta", aliases: ["Same Bank"], resource: "b")
        ])
        XCTAssertNil(conflict.match(name: "Same Bank"))
        XCTAssertEqual(WalletLogoCatalog.normalized("ＳＯＣＩÉＴÉ"), "societe")
    }
    @MainActor
    func testAllBundledArtworkLoadsAndKeepsItsSize() throws {
        XCTAssertEqual(WalletLogoCatalog.shared.entries.count, 374)
        for issuer in WalletLogoCatalog.shared.entries {
            for suffix in ["", "_card"] {
                try autoreleasepool {
                    let image = try XCTUnwrap(UIImage(named: issuer.resource + suffix), issuer.resource + suffix)
                    XCTAssertGreaterThan(image.size.width, 0)
                    XCTAssertGreaterThan(image.size.height, 0)
                }
            }
        }
        for brand in CardBrand.allCases where brand != .unknown {
            XCTAssertNotNil(UIImage(named: try XCTUnwrap(brand.logoResource)), brand.rawValue)
        }
        XCTAssertNil(CardBrand.unknown.logoResource)
    }
    @MainActor
    func testNativeLightDarkAndLargeTextRendering() throws {
        let card = SharedCard(id: "brand-render-fixture", country: "美国", bank: "American Express", cardNumber: "378282246310005", alias: "合成测试卡", type: "USD", limit: 1200)
        for scheme in [ColorScheme.light, .dark] {
            for size in [DynamicTypeSize.large, .accessibility1] {
                let content = VStack(spacing: 16) {
                    CreditCardView(card: card).frame(width: 350)
                    CreditCardMiniView(card: card)
                    WalletBankLogo(bank: "不存在的测试银行", width: 36, height: 28)
                }
                .padding(16).frame(width: 382)
                .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size)
                .background(scheme == .dark ? Color.black : Color.white)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size.width, 382, accuracy: 1)
                XCTAssertGreaterThan(image.size.height, 200)
                let attachment = XCTAttachment(image: image)
                attachment.name = "ios-branding-\(scheme)-\(size)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
