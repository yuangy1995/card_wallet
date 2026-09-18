import XCTest
@testable import CreditCardMac
final class LocalDataCipherTests: XCTestCase {
    func testRandomAuthenticatedStorageAndLegacyRead() throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cipher=LocalDataCipher(directory: directory)
        let plain=Data("synthetic-card-data".utf8)
        let a=try cipher.seal(plain);let b=try cipher.seal(plain)
        XCTAssertNotEqual(a,b);XCTAssertEqual(try cipher.open(a),plain)
        let old=try CryptoManager.encrypt(plainText:String(decoding:plain,as:UTF8.self))
        XCTAssertEqual(try cipher.open(Data(old.utf8)),plain)
        let attrs=try FileManager.default.attributesOfItem(atPath:directory.appendingPathComponent("local_data.key").path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue,0o600)
        try a.write(to:directory.appendingPathComponent("cards.json"))
        try FileManager.default.removeItem(at:directory.appendingPathComponent("local_data.key"))
        XCTAssertThrowsError(try cipher.open(a))
        XCTAssertThrowsError(try cipher.seal(plain))
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent("cards.json")),a)
    }
}
