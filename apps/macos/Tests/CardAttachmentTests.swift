import XCTest
@testable import CreditCardMac

final class CardAttachmentTests: XCTestCase {
    @MainActor
    func testAttachmentDecoderSupportsDataURLsAndRawBase64() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "AppIcon", withExtension: "png"))
        let payload = try Data(contentsOf: url).base64EncodedString()
        for value in [payload, "data:image/png;base64," + payload] {
            let asset = CardImageAsset(data: value, name: "test-only")
            let image = await CardImageCache.shared.image(for: asset, pixels: 240)
            XCTAssertNotNil(image)
            XCTAssertLessThanOrEqual(image?.size.width ?? 0, 240)
            XCTAssertLessThanOrEqual(image?.size.height ?? 0, 240)
        }
    }

    @MainActor
    func testDamagedAttachmentDoesNotProduceAnImage() async {
        let image = await CardImageCache.shared.image(for: CardImageAsset(data: "not-an-image"), pixels: 240)
        XCTAssertNil(image)
    }
}
