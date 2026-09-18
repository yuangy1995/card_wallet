import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CardImagePolicy {
    static let maximumCount = 20
    static let maximumInputBytes = 10 * 1024 * 1024
    static let maximumStoredBytes = 2 * 1024 * 1024
    static let maximumEdge = 1600
    static func canAppend(existing: Int, incoming: Int) -> Bool {
        incoming > 0 && existing >= 0 && existing + incoming <= maximumCount
    }
    /// Only newly selected images are normalized. Existing attachments remain unchanged.
    static func jpeg(from raw: Data) -> Data? {
        guard !raw.isEmpty, raw.count <= maximumInputBytes,
              let source = CGImageSourceCreateWithData(raw as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumEdge
              ] as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.84] as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length <= maximumStoredBytes else { return nil }
        return output as Data
    }
}
