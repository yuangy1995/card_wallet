import XCTest
@testable import CreditCardMac

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
}
