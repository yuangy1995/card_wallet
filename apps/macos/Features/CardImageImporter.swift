import Foundation

enum CardImageImporter {
    static func read(_ urls: [URL]) -> [CardImageAsset] {
        urls.compactMap { url in
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? handle.close() }
            guard let raw = try? handle.read(upToCount: CardImagePolicy.maximumInputBytes + 1),
                  let jpeg = CardImagePolicy.jpeg(from: raw) else { return nil }
            return CardImageAsset(mimeType: "image/jpeg", data: "data:image/jpeg;base64,\(jpeg.base64EncodedString())", source: "mac_upload", name: url.lastPathComponent)
        }
    }
}
