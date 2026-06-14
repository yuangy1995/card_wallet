import Foundation

public enum CardSyncState: String, Codable, Hashable, Sendable {
    case active
    case deleted
}

public enum SyncTimestamp {
    public static func now() -> String { string(from: Date()) }

    public static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    public static func date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: value) { return parsed }
        formatter.formatOptions = [.withInternetDateTime]
        if let parsed = formatter.date(from: value) { return parsed }
        return DataMigrationManager.parseLastModifyTime(value)
    }

    public static func milliseconds(from value: String) -> Double {
        DataMigrationManager.timestampMilliseconds(from: normalized(value)) ?? DataMigrationManager.currentTimestampMilliseconds()
    }

    public static func normalized(_ value: String) -> String {
        guard let date = date(from: value) else { return now() }
        return string(from: date)
    }

    public static func string(from timestamp: Double) -> String {
        guard let date = DataMigrationManager.date(fromTimestamp: timestamp) else { return now() }
        return string(from: date)
    }
}

public struct CardSyncRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: String { cardId }
    public var cardId: String
    public var mutationId: String
    public var changedAt: String
    public var state: CardSyncState
    public var card: SharedCard?

    private enum CodingKeys: String, CodingKey {
        case cardId, mutationId, changedAt, state, card
    }

    public init(
        cardId: String,
        mutationId: String = UUID().uuidString,
        changedAt: String,
        state: CardSyncState,
        card: SharedCard?
    ) {
        self.cardId = cardId
        self.mutationId = mutationId
        self.changedAt = SyncTimestamp.normalized(changedAt)
        self.state = state
        if state == .active {
            var normalizedCard = card
            normalizedCard?.id = cardId
            self.card = normalizedCard
        } else {
            self.card = nil
        }
        self.card?.lastModifyTime = SyncTimestamp.milliseconds(from: self.changedAt)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cardId = try container.decode(String.self, forKey: .cardId)
        let mutationId = try container.decodeIfPresent(String.self, forKey: .mutationId) ?? UUID().uuidString
        let changedAt = try container.decodeIfPresent(String.self, forKey: .changedAt) ?? SyncTimestamp.now()
        let state = try container.decode(CardSyncState.self, forKey: .state)
        let card = try container.decodeIfPresent(SharedCard.self, forKey: .card)
        self.init(cardId: cardId, mutationId: mutationId, changedAt: changedAt, state: state, card: card)
    }

    public static func active(_ card: SharedCard, changedAt: String = SyncTimestamp.now()) -> CardSyncRecord {
        CardSyncRecord(cardId: card.id, changedAt: changedAt, state: .active, card: card)
    }

    public static func deleted(cardId: String, changedAt: String = SyncTimestamp.now()) -> CardSyncRecord {
        CardSyncRecord(cardId: cardId, changedAt: changedAt, state: .deleted, card: nil)
    }

    public static func legacyActive(_ card: SharedCard) -> CardSyncRecord {
        let time = card.lastModifyTime > 0 ? SyncTimestamp.string(from: card.lastModifyTime) : SyncTimestamp.now()
        return active(card, changedAt: time)
    }
}

public struct WebDAVSyncSnapshotV4: Codable, Hashable, Sendable {
    public static let schemaVersion = "4.0.0"
    public var schemaVersion: String
    public var snapshotId: String
    public var generatedAt: String
    public var source: String
    public var records: [CardSyncRecord]

    public init(
        snapshotId: String = UUID().uuidString,
        generatedAt: String = SyncTimestamp.now(),
        source: String,
        records: [CardSyncRecord]
    ) {
        self.schemaVersion = Self.schemaVersion
        self.snapshotId = snapshotId
        self.generatedAt = generatedAt
        self.source = source
        self.records = CardSyncMergeEngine.merge([records])
    }
}

public typealias WebDAVSyncSnapshotV3 = WebDAVSyncSnapshotV4

public struct SyncEncryptionMetadata: Codable, Hashable, Sendable {
    public var version: Int
    public var algorithm: String
    public var kdf: String
    public var iterations: Int
    public var salt: String
    public var iv: String

    public init(
        version: Int = 1,
        algorithm: String = "AES-256-GCM",
        kdf: String = "PBKDF2-HMAC-SHA256",
        iterations: Int = 310000,
        salt: String,
        iv: String
    ) {
        self.version = version; self.algorithm = algorithm; self.kdf = kdf
        self.iterations = iterations; self.salt = salt; self.iv = iv
    }
}

public struct SyncEncryptedEnvelope: Codable, Hashable, Sendable {
    public var schemaVersion: String
    public var encryption: SyncEncryptionMetadata
    public var ciphertext: String

    public init(
        schemaVersion: String = WebDAVSyncSnapshotV4.schemaVersion,
        encryption: SyncEncryptionMetadata,
        ciphertext: String
    ) {
        self.schemaVersion = schemaVersion; self.encryption = encryption; self.ciphertext = ciphertext
    }
}

public enum CardSyncMergeEngine {
    public static func merge(_ recordSets: [[CardSyncRecord]]) -> [CardSyncRecord] {
        var winningRecords: [String: CardSyncRecord] = [:]
        for record in recordSets.flatMap({ $0 }) {
            guard !record.cardId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if let existing = winningRecords[record.cardId] {
                winningRecords[record.cardId] = winner(existing, record)
            } else {
                winningRecords[record.cardId] = record
            }
        }
        return winningRecords.values.sorted { $0.cardId < $1.cardId }
    }

    public static func activeCards(from records: [CardSyncRecord]) -> [SharedCard] {
        merge([records]).filter { $0.state == .active }.compactMap(\.card).sorted { $0.id < $1.id }
    }

    public static func winner(_ lhs: CardSyncRecord, _ rhs: CardSyncRecord) -> CardSyncRecord {
        let lhsDate = SyncTimestamp.date(from: lhs.changedAt) ?? .distantPast
        let rhsDate = SyncTimestamp.date(from: rhs.changedAt) ?? .distantPast
        if lhsDate != rhsDate { return lhsDate > rhsDate ? lhs : rhs }
        if lhs.state != rhs.state { return lhs.state == .deleted ? lhs : rhs }
        return lhs.mutationId >= rhs.mutationId ? lhs : rhs
    }
}

public struct SyncLedger: Codable, Sendable {
    public var records: [CardSyncRecord]
    public var processedWebDAVSnapshotIDs: Set<String>
    public var lastWebDAVSnapshotFilename: String?
    public var pendingWebDAVUpload: Bool
    public var pendingCloudKitUpload: Bool

    public init(
        records: [CardSyncRecord] = [],
        processedWebDAVSnapshotIDs: Set<String> = [],
        lastWebDAVSnapshotFilename: String? = nil,
        pendingWebDAVUpload: Bool = false,
        pendingCloudKitUpload: Bool = false
    ) {
        self.records = CardSyncMergeEngine.merge([records])
        self.processedWebDAVSnapshotIDs = processedWebDAVSnapshotIDs
        self.lastWebDAVSnapshotFilename = lastWebDAVSnapshotFilename
        self.pendingWebDAVUpload = pendingWebDAVUpload
        self.pendingCloudKitUpload = pendingCloudKitUpload
    }
}
