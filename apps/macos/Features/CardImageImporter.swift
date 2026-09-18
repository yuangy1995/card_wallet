import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CardImageImporter {
    /// 在后台读取并缩小位图，避免导入多张照片时阻塞编辑表单。
    static func read(_ urls: [URL]) -> [CardImageAsset] {
        urls.compactMap { url in
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= CardAttachmentPolicy.maximumSourceBytes,
                  let raw = try? Data(contentsOf: url), raw.count <= CardAttachmentPolicy.maximumSourceBytes else { return nil }
            let payload: Data
            let mimeType: String
            if let source = CGImageSourceCreateWithData(raw as CFData, nil),
               let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: CardAttachmentPolicy.maximumEdge
               ] as CFDictionary) {
                let output = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
                CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.84] as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { return nil }
                payload = output as Data
                mimeType = "image/jpeg"
            } else { return nil }
            return CardImageAsset(mimeType: mimeType, data: "data:\(mimeType);base64,\(payload.base64EncodedString())", source: "mac_upload", name: url.lastPathComponent)
        }
    }
}
