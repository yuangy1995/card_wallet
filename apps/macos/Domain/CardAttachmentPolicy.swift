import Foundation

/// Limits apply to NEW local imports only; old/remote attachments are never truncated.
public enum CardAttachmentPolicy {
    public static let maximumImages = 12
    public static let maximumSourceBytes = 10 * 1024 * 1024
    public static let maximumEdge = 1600
    public static func canAppend(existingCount: Int, additionalCount: Int) -> Bool {
        existingCount >= 0 && additionalCount >= 0 && existingCount <= maximumImages && additionalCount <= maximumImages - existingCount
    }
}
