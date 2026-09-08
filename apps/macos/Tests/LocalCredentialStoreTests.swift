import XCTest
@testable import CreditCardMac

final class LocalCredentialStoreTests: XCTestCase {
    private var directory: URL!
    private var store: LocalCredentialStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("wallet-local-credentials-test-" + UUID().uuidString)
        store = LocalCredentialStore(directory: directory)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    func testRoundTripEncryptsCredentialsAndRestrictsFilePermissions() throws {
        let credentials = ["app_lock_password": "test-secret-123", "webdav_username": "test-user"]
        try store.save(credentials)
        XCTAssertEqual(try store.load(), credentials)
        let file = directory.appendingPathComponent("security_credentials.enc")
        let encrypted = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(encrypted.hasPrefix("local-v1:"))
        XCTAssertFalse(encrypted.contains("test-secret-123"))
        for name in ["security_credentials.enc", "security_credentials.key"] {
            let attributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(name).path)
            XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
    }

    func testMigrationKeepsAllLocalAndImportedCredentials() throws {
        try store.save(["existing": "keep"])
        try store.importLegacy(keys: ["password", "missing"]) { $0 == "password" ? "imported" : nil }
        XCTAssertEqual(try store.load(), ["existing": "keep", "password": "imported"])
    }

    func testDeniedMigrationDoesNotChangeExistingVault() throws {
        try store.save(["existing": "keep"])
        let file = directory.appendingPathComponent("security_credentials.enc")
        let before = try Data(contentsOf: file)
        XCTAssertThrowsError(try store.importLegacy(keys: ["allowed", "denied"]) {
            if $0 == "denied" { throw CocoaError(.fileReadNoPermission) }
            return "not-committed"
        })
        XCTAssertEqual(try Data(contentsOf: file), before)
        XCTAssertEqual(try store.load(), ["existing": "keep"])
    }

    func testDeniedFirstMigrationDoesNotCreateEmptyVault() throws {
        XCTAssertThrowsError(try store.importLegacy(keys: ["password"]) { _ in throw CocoaError(.fileReadNoPermission) })
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testOldLocalEncryptionRemainsReadableAndUpgradesOnSave() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let credentials = ["app_lock_password": "legacy-test-only"]
        let json = String(data: try JSONEncoder().encode(credentials), encoding: .utf8)!
        let legacy = try CryptoManager.encrypt(plainText: json, password: "Credential.Default.AES.Key.@@1995")
        let file = directory.appendingPathComponent("security_credentials.enc")
        try legacy.write(to: file, atomically: true, encoding: .utf8)
        XCTAssertEqual(try store.load(), credentials)
        try store.save(store.load())
        XCTAssertTrue(try String(contentsOf: file, encoding: .utf8).hasPrefix("local-v1:"))
        XCTAssertEqual(try store.load(), credentials)
    }

    func testMissingKeyOrDamagedVaultIsNotTreatedAsEmptyCredentials() throws {
        try store.save(["password": "test-only"])
        let keyFile = directory.appendingPathComponent("security_credentials.key")
        let key = try Data(contentsOf: keyFile)
        try FileManager.default.removeItem(at: keyFile)
        XCTAssertThrowsError(try store.load())
        try key.write(to: keyFile)
        try "local-v1:invalid".write(to: directory.appendingPathComponent("security_credentials.enc"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try store.load())
    }

    func testOldLedgerFieldsDoNotPreventReadingWebDAVState() throws {
        let data = Data(#"{"records":[],"cloudKitStateData":"AQ==","pendingCloudKitUpload":true,"pendingWebDAVUpload":true,"processedWebDAVSnapshotIDs":["saved"]}"#.utf8)
        let ledger = try JSONDecoder().decode(SyncLedger.self, from: data)
        XCTAssertTrue(ledger.pendingWebDAVUpload)
        XCTAssertEqual(ledger.processedWebDAVSnapshotIDs, ["saved"])
        let encoded = String(data: try JSONEncoder().encode(ledger), encoding: .utf8)!
        XCTAssertFalse(encoded.contains("cloudKit"))
    }
}
