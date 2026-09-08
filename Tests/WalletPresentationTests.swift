import XCTest
import SwiftUI
@testable import CreditCardMac

final class WalletPresentationTests: XCTestCase {
    func testSelectionColorsFollowSkinAndAppearance() {
        for scheme in [ColorScheme.light, .dark] {
            XCTAssertNotEqual(WalletPalette(skin: .ice, scheme: scheme).selection, WalletPalette(skin: .forest, scheme: scheme).selection)
        }
        for skin in WalletSkin.allCases {
            XCTAssertNotEqual(WalletPalette(skin: skin, scheme: .light).selection, WalletPalette(skin: skin, scheme: .dark).selection)
        }
    }

    func testAppIconHasTransparentCornersAndOpaqueArtwork() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "AppIcon", withExtension: "png"))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
        XCTAssertEqual(bitmap.pixelsWide, 1024)
        XCTAssertEqual(bitmap.pixelsHigh, 1024)
        XCTAssertEqual(bitmap.colorAt(x: 0, y: 0)?.alphaComponent, 0)
        XCTAssertEqual(bitmap.colorAt(x: 512, y: 512)?.alphaComponent, 1)
    }

    func testDetailAndEditorSheetsStayInsideParentWindow() {
        for parent in [CGSize(width: 980, height: 660), CGSize(width: 1160, height: 800), CGSize(width: 1600, height: 1000)] {
            let sheet = WalletSheetLayout.size(in: parent)
            XCTAssertLessThanOrEqual(sheet.width, parent.width - 64)
            XCTAssertLessThanOrEqual(sheet.height, parent.height - 80)
            XCTAssertLessThanOrEqual(sheet.height, 680)
        }
        XCTAssertEqual(WalletSheetLayout.size(in: CGSize(width: 980, height: 660)).height, 580)
    }

    func testCacheCleanupKeepsOtherApplicationsFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("wallet-cache-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let own = WalletCacheStorage.directory(in: root)
        let other = root.appendingPathComponent("other-application", isDirectory: true)
        try FileManager.default.createDirectory(at: own, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try Data([1]).write(to: own.appendingPathComponent("cache"))
        try Data([2]).write(to: other.appendingPathComponent("keep"))
        try WalletCacheStorage.clear(in: root)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: own.path).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.appendingPathComponent("keep").path))
    }

    func testCacheCleanupDoesNotFollowDirectorySymlinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("wallet-cache-link-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let other = root.appendingPathComponent("keep", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try Data([1]).write(to: other.appendingPathComponent("important"))
        try FileManager.default.createSymbolicLink(at: WalletCacheStorage.directory(in: root), withDestinationURL: other)
        XCTAssertThrowsError(try WalletCacheStorage.clear(in: root))
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.appendingPathComponent("important").path))
    }

    private func card(_ id: String, bank: String = "招商银行", limit: Double? = 80000, currency: String = "CNY", shared: Bool = true, category: String = "credit", country: String = "中国") -> SharedCard {
        SharedCard(id: id, cardCategory: category, country: country, bank: bank, cardNumber: "411111111111" + id,
                   alias: "测试卡片", type: currency, limit: limit, valid: "08/29", isQualified: "2",
                   accountBillDate: "10", dueDate: "28", lastModifyTime: 1000, isSharedLimit: shared)
    }

    func testSharedLimitUsesMaximumRegardlessOfCardOrder() {
        let small = card("0001", limit: 20000), large = card("0002", limit: 80000)
        XCTAssertEqual(CardCatalog.creditLimits(cards: [small, large])["CNY"], 80000)
        XCTAssertEqual(CardCatalog.creditLimits(cards: [large, small])["CNY"], 80000)
    }

    func testCurrenciesCountriesAndIndependentLimitsRemainSeparate() {
        let cards = [card("0001", limit: 20000), card("0002", limit: 80000),
                     card("0003", limit: 10000, shared: false), card("0004", limit: 5000, currency: "USD"),
                     card("0005", limit: 40000, country: "香港特别行政区"), card("0006", limit: 999999, category: "debit")]
        let totals = CardCatalog.creditLimits(cards: cards)
        XCTAssertEqual(totals["CNY"], 130000)
        XCTAssertEqual(totals["USD"], 5000)
    }

    func testBankAliasesShareOneCatalogGroupAndStatisticsTotal() {
        let cards = [card("0001", bank: "招商银行 (Visa)", limit: 20000), card("0002", limit: 80000)]
        let query = CardCatalogQuery(group: .bank)
        let groups = CardCatalog.groups(items: cards.map(CardCatalogItem.init), query: query)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.title, "招商银行")
        XCTAssertEqual(groups.first?.limits["CNY"], 80000)
        let statistics = CardStatistics(cards: cards)
        XCTAssertEqual(statistics.bankLimits.count, 1)
        XCTAssertEqual(statistics.bankLimits.first?.amount, 80000)
        XCTAssertEqual(statistics.totalLimits["CNY"], 80000)
    }

    func testSearchCategoryAndBankFiltersCompose() {
        let items = [card("0001"), card("0002", bank: "中国银行", category: "debit"), card("0003", bank: "中国银行")].map(CardCatalogItem.init)
        let query = CardCatalogQuery(search: "0002", bank: "中国银行", category: .debit)
        XCTAssertEqual(CardCatalog.groups(items: items, query: query).flatMap(\.items).map(\.id), ["0002"])
        XCTAssertTrue(CardCatalog.groups(items: items, query: CardCatalogQuery(search: "不存在的卡片")).isEmpty)
    }

    func testAmountSortIsDeterministicForTies() {
        let items = [card("0003", limit: 40000), card("0002", limit: 80000), card("0001", limit: 80000)].map(CardCatalogItem.init)
        XCTAssertEqual(CardCatalog.groups(items: items, query: CardCatalogQuery(sort: .limitDesc)).flatMap(\.items).map(\.id), ["0001", "0002", "0003"])
        XCTAssertEqual(CardCatalog.groups(items: items, query: CardCatalogQuery(sort: .limitAsc)).flatMap(\.items).map(\.id), ["0003", "0001", "0002"])
    }

    func testInvalidBillingDatesAndDebitCardsSortAfterKnownPeriods() {
        var invalid = card("0001")
        invalid.accountBillDate = ""
        let valid = card("0002"), debit = card("0003", category: "debit")
        let items = [invalid, debit, valid].map(CardCatalogItem.init)
        XCTAssertNil(items.first?.interestFreeDays)
        for sort in [SortOption.daysAsc, .daysDesc] {
            XCTAssertEqual(CardCatalog.groups(items: items, query: CardCatalogQuery(sort: sort)).flatMap(\.items).first?.id, valid.id)
        }
    }

    func testSubmissionUpdatesOnlyEligibleSharedPeers() {
        let original = card("0001", limit: 20000)
        let peer = card("0002", limit: 20000)
        let independent = card("0003", limit: 7000, shared: false)
        let otherCurrency = card("0004", limit: 6000, currency: "USD")
        let debit = card("0005", limit: 0, category: "debit")
        var edited = original
        edited.limit = 80000
        let result = CardEditing.applySubmission(edited, previous: original, to: [original, peer, independent, otherCurrency, debit])
        XCTAssertEqual(result.first { $0.id == peer.id }?.limit, 80000)
        XCTAssertEqual(result.first { $0.id == independent.id }?.limit, 7000)
        XCTAssertEqual(result.first { $0.id == otherCurrency.id }?.limit, 6000)
        XCTAssertEqual(result.first { $0.id == debit.id }?.limit, 0)
    }

    func testBankRenameUpdatesRelatedCardsWithoutLosingImages() {
        var original = card("0001")
        original.cardImages = [CardImageAsset(id: "photo", data: "data:image/png;base64,AQID")]
        let peer = card("0002", bank: "招商银行 (Visa)"), unrelated = card("0003", bank: "中国银行")
        var edited = original
        edited.bank = "招商银行新名称"
        let result = CardEditing.applySubmission(edited, previous: original, to: [original, peer, unrelated])
        XCTAssertEqual(result.first { $0.id == peer.id }?.bank, edited.bank)
        XCTAssertEqual(result.first { $0.id == unrelated.id }?.bank, unrelated.bank)
        XCTAssertEqual(result.first { $0.id == original.id }?.cardImages, original.cardImages)
    }

    func testSavingDeletedCardDoesNotResurrectIt() {
        let deleted = card("0001"), retained = card("0002")
        XCTAssertEqual(CardEditing.applySubmission(deleted, previous: deleted, to: [retained]), [retained])
    }

    func testAnnualConfirmationAdvancesOnceAndPreservesOtherFields() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 12))!
        var original = card("0001")
        original.nextAnnualFeeCollectionTime = DateCalculator.timestamp(from: now.addingTimeInterval(10 * 86400))
        let confirmed = CardEditing.settingAnnualStatus("1", for: original, now: now)
        XCTAssertEqual(confirmed.isQualified, "1")
        XCTAssertEqual(confirmed.nextAnnualFeeCollectionTime, DateCalculator.timestampByAddingOneYear(original.nextAnnualFeeCollectionTime))
        XCTAssertEqual(CardEditing.settingAnnualStatus("1", for: confirmed, now: now), confirmed)
        XCTAssertEqual(confirmed.bank, original.bank)
        XCTAssertEqual(confirmed.cardNumber, original.cardNumber)
    }

    func testLifetimeWaiverClearsAnnualDateAndDoesNotModifyDebitCards() {
        var original = card("0001")
        original.nextAnnualFeeCollectionTime = 1000
        XCTAssertNil(CardEditing.settingAnnualStatus("3", for: original).nextAnnualFeeCollectionTime)
        let debit = card("0002", category: "debit")
        XCTAssertEqual(CardEditing.settingAnnualStatus("1", for: debit), debit)
    }

    func testStatisticsExcludesUnspecifiedLimitsFromLowLimitReview() {
        let snapshot = CardStatistics(cards: [card("0001", limit: nil), card("0002", limit: 3000), card("0003", limit: 900, currency: "USD")])
        XCTAssertEqual(snapshot.lowLimitCards.map(\.id), ["0002"])
    }

    func testSyncStatusNeverReportsNewChangesAsCompleted() {
        XCTAssertEqual(WalletSyncState.resolve(enabled: true, syncing: false, message: "本机有新修改，正在继续同步", latestStatus: "success", lastSuccess: Date()), .pending)
        XCTAssertEqual(WalletSyncState.resolve(enabled: true, syncing: false, message: "请填写同步密钥", latestStatus: "success", lastSuccess: Date()), .attention)
        XCTAssertEqual(WalletSyncState.resolve(enabled: true, syncing: false, message: "云同步还未设置", latestStatus: "success", lastSuccess: Date()), .unconfigured)
    }

    func testInFlightSyncRemainsVisibleWhenAutomaticSyncIsDisabled() {
        XCTAssertEqual(WalletSyncState.resolve(enabled: false, syncing: true, message: "云端同步已关闭", latestStatus: nil, lastSuccess: nil), .syncing)
        XCTAssertEqual(WalletSyncState.resolve(enabled: false, syncing: false, message: "", latestStatus: nil, lastSuccess: nil), .disabled)
    }

    func testHistoryMasksCardNumberAndSecurityCode() {
        XCTAssertEqual(WalletSyncState.safeValue(label: "卡号", value: "4111111111118806"), "•••• 8806")
        XCTAssertEqual(WalletSyncState.safeValue(label: "CVV 安全码", value: "123"), "•••")
        XCTAssertEqual(WalletSyncState.safeValue(label: "额度", value: "80000"), "80000")
    }

    func testCSVQuotesFieldsAndProtectsSpreadsheetFormulas() {
        XCTAssertEqual(CardStatistics.csvRow(["银行,名称", "含\"引号"]), "\"银行,名称\",\"含\"\"引号\"\n")
        XCTAssertEqual(CardStatistics.csvRow(["=1+1", "80000"]), "\"'=1+1\",\"80000\"\n")
    }

    @MainActor
    func testSkinAndAppearancePreferencesPersistIndependently() {
        let suiteName = "wallet-tests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appearance = WalletAppearance(defaults: defaults)
        XCTAssertEqual(appearance.skin, .ice)
        XCTAssertEqual(appearance.colorMode, .system)
        appearance.skin = .forest
        appearance.colorMode = .dark
        appearance.animationsEnabled = false
        appearance.reduceTransparency = true
        let restored = WalletAppearance(defaults: defaults)
        XCTAssertEqual(restored.skin, .forest)
        XCTAssertEqual(restored.colorMode, .dark)
        XCTAssertFalse(restored.animationsEnabled)
        XCTAssertTrue(restored.reduceTransparency)
        XCTAssertNotEqual(WalletPalette(skin: .ice, scheme: .light).accent, WalletPalette(skin: .ice, scheme: .dark).accent)
    }

    @MainActor
    func testSensitiveViewsFailClosedWithoutSessionEnvironment() {
        XCTAssertTrue(EnvironmentValues().walletIsLocked)
    }

    func testTraditionalChineseSkinResourcesAreBundled() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "zh-Hant", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(bundle.localizedString(forKey: "配色皮肤", value: nil, table: "Localizable"), "配色皮膚")
        XCTAssertEqual(bundle.localizedString(forKey: "冰蓝", value: nil, table: "Localizable"), "冰藍")
        XCTAssertEqual(bundle.localizedString(forKey: "森绿", value: nil, table: "Localizable"), "森綠")
    }

    @MainActor
    func testImageSizesWithoutDecodingLargeBitmaps() {
        XCTAssertEqual(CardImageView.byteCount(CardImageAsset(data: "data:image/png;base64,AQID")), 3)
        XCTAssertEqual(CardImageView.byteCount(CardImageAsset(data: "AQ==")), 1)
        XCTAssertEqual(CardImageView.byteCount(CardImageAsset(data: "AQI=")), 2)
    }
}
