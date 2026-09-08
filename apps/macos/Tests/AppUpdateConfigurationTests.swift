import XCTest
@testable import CreditCardMac

final class AppUpdateConfigurationTests: XCTestCase {
    func testUpdatesAreAvailableInSettingsNavigation() {
        XCTAssertTrue(WalletSettingsSection.allCases.contains(.updates))
        XCTAssertEqual(WalletSettingsSection.updates.rawValue, "软件更新")
        XCTAssertEqual(WalletSettingsSection.updates.icon, "arrow.down.circle")
    }
    func testReleaseFeedAndSigningKey() {
        let bundle = Bundle(for: AppUpdater.self)
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
                       "https://github.com/yuangy1995/card-wallet-releases/releases/latest/download/appcast.xml")
        let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        XCTAssertEqual(key.flatMap { Data(base64Encoded: $0) }?.count, 32)
    }

    func testChecksAreAutomaticButInstallationRequiresConfirmation() {
        let bundle = Bundle(for: AppUpdater.self)
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool, true)
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "SUAutomaticallyUpdate") as? Bool, false)
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "SUEnableInstallerLauncherService") as? Bool, true)
    }
}
