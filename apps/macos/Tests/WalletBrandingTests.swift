import XCTest
import SwiftUI
import AppKit
@testable import CreditCardMac

final class WalletBrandingTests: XCTestCase {
    func testCatalogueContainsTheImportedAndroidInstitutions() {
        let entries = WalletLogoCatalog.shared.entries
        XCTAssertEqual(entries.count, 374)
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
    }

    func testChineseEnglishTraditionalAndCorporateSuffixes() {
        let cases = ["招商银行": "cmbchina", "招商銀行（信用卡）": "cmbchina",
                     "中国农业银行股份有限公司": "abchina", "Agricultural Bank of China Limited": "abchina",
                     "中国工商银行": "icbc", "Bank of China": "boc",
                     "北京银行": "bankofbeijing", "Bank of Beijing": "bankofbeijing",
                     "Capital One": "capitalone", "第一資本銀行": "capitalone",
                     "AMEX": "amex", "American Express National Bank": "amex", "HSBC": "hsbc"]
        for (name, id) in cases {
            XCTAssertEqual(WalletLogoCatalog.shared.match(name: name)?.id, id, name)
        }
        XCTAssertEqual(WalletLogoCatalog.normalized("ＳＯＣＩÉＴÉ"), "societe")
    }

    func testUnknownAndConflictingAliasesDoNotBorrowAnotherLogo() {
        let catalog = WalletLogoCatalog(entries: [
            WalletIssuerLogo(id: "a", name: "Alpha Bank", aliases: ["Same Bank"], resource: "a"),
            WalletIssuerLogo(id: "b", name: "Beta Bank", aliases: ["Same Bank"], resource: "b")
        ])
        XCTAssertNil(catalog.match(name: "Same Bank"))
        XCTAssertNil(WalletLogoCatalog.shared.match(name: ""))
        XCTAssertNil(WalletLogoCatalog.shared.match(name: "不存在的测试银行"))
        XCTAssertNotEqual(WalletLogoCatalog.shared.match(name: "Citizens Bank")?.id, "citibank")
        XCTAssertNil(WalletLogoCatalog.shared.match(name: "兴业银行", country: "Malaysia"))
        XCTAssertEqual(WalletLogoCatalog.shared.match(name: "兴业银行", country: "中国")?.id, "cib")
    }

    func testRepeatedLookupsAndEvictionKeepResultsCorrect() {
        let catalog = WalletLogoCatalog.shared
        for i in 0..<300 { XCTAssertNil(catalog.match(name: "不存在的测试银行-\(i)")) }
        XCTAssertEqual(catalog.match(name: "Capital One")?.id, "capitalone")
        XCTAssertNil(catalog.match(name: "不存在的测试银行-0"))
    }

    @MainActor
    func testAllBundledIssuerVariantsAndNetworksResolve() {
        for issuer in WalletLogoCatalog.shared.entries {
            for suffix in ["", "_card"] {
                autoreleasepool {
                    let image = NSImage(named: NSImage.Name(issuer.resource + suffix))
                    XCTAssertNotNil(image, issuer.resource + suffix)
                    XCTAssertGreaterThan(image?.size.width ?? 0, 0)
                }
            }
        }
        for brand in CardBrand.allCases where brand != .unknown {
            XCTAssertNotNil(NSImage(named: NSImage.Name(brand.logoResource!)), brand.rawValue)
        }
        XCTAssertNil(CardBrand.unknown.logoResource)
    }

    func testNetworkNumberRulesMatchAndroid() {
        let cases: [(String, CardBrand)] = [
            ("4111 1111 1111 1111", .visa), ("4000000000000000001", .visa),
            ("5555555555554444", .mastercard), ("2221000000000000", .mastercard),
            ("2720000000000000", .mastercard), ("2721000000000000", .unknown),
            ("378282246310005", .amex), ("371234", .unknown),
            ("6221260000000000", .unionpay), ("8100000000000000", .unionpay),
            ("6011000000000000", .discover), ("6440000000000000", .discover),
            ("3528000000000000", .jcb), ("3590000000000000", .unknown),
            ("30500000000000", .dinersClub), ("36000000000000", .dinersClub),
            ("", .unknown), ("1234", .unknown)
        ]
        for (number, expected) in cases { XCTAssertEqual(CardBrand.detect(from: number), expected, number) }
    }

    func testMacExplicitLevelHintIsPreservedWithoutAmexSubstringFalsePositive() {
        XCTAssertEqual(CardBrand.detect(from: "6221260000000000", level: "Discover"), .discover)
        XCTAssertEqual(CardBrand.detect(from: "", level: "銀聯-金卡"), .unionpay)
        XCTAssertEqual(CardBrand.detect(from: "4111111111111111", level: "Aeroplan"), .visa)
        XCTAssertEqual(CardBrand.detect(from: "6221260000000000", level: "UnionPay / Discover"), .unionpay)
    }

    @MainActor
    func testNativeLightDarkCardAndListRendering() throws {
        let samples = [
            SharedCard(id: "sample-cgb", country: "中国", bank: "广发银行", cardNumber: "6221260000001205", alias: "示例信用卡", level: "银联-钻石卡", type: "CNY", limit: 50000, valid: "08/34"),
            SharedCard(id: "sample-amex", country: "美国", bank: "AMEX", cardNumber: "378282246310005", alias: "示例卡片", type: "USD", valid: "12/30"),
            SharedCard(id: "sample-capital", country: "美国", bank: "Capital One", cardNumber: "5555555555554444", alias: "示例卡片", type: "USD", valid: "12/30"),
            SharedCard(id: "sample-unknown", country: "中国", bank: "不存在的测试银行", cardNumber: "9999999999999999", alias: "默认图标", type: "CNY", valid: "12/30")
        ]
        for scheme in [ColorScheme.light, .dark] {
            let palette = WalletPalette(skin: .ice, scheme: scheme)
            let content = VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ForEach(samples) { card in WalletCardFace(card: card).frame(width: 240, height: 149) }
                }
                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 6) {
                        ForEach(samples) { card in
                            WalletCatalogRow(item: CardCatalogItem(card: card), grid: false, selected: card.id == "sample-cgb", selectionMode: false, compact: true)
                        }
                    }.frame(width: 720)
                    VStack(spacing: 8) {
                        ForEach(CardBrand.allCases, id: \.rawValue) { brand in
                            HStack { Text(brand.rawValue).font(.caption); Spacer(); CardBrandIcon(brand: brand) }
                        }
                    }.frame(width: 256)
                }
            }
            .padding(24).background(palette.background)
            .environment(\.walletPalette, palette).environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.nsImage)
            XCTAssertGreaterThan(image.size.width, 0)
            try save(image, name: scheme == .dark ? "macos-brand-dark" : "macos-brand-light")
        }
    }

    @MainActor
    private func save(_ image: NSImage, name: String) throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("build/brand-review")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: folder.appendingPathComponent(name + ".png"))
    }
}
