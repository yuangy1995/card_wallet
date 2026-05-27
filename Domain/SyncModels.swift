import Foundation

public enum CardSyncState: String, Codable, Hashable {
    case active
    case deleted
}

public enum SyncTimestamp {
    public static func now() -> String {
        string(from: Date())
    }

    public static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    public static func date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: value) {
            return parsed
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let parsed = formatter.date(from: value) {
            return parsed
        }
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
        guard let date = DataMigrationManager.date(fromTimestamp: timestamp) else {
            return now()
        }
        return string(from: date)
    }
}

public struct CardSyncRecord: Codable, Identifiable, Hashable {
    public var id: String { cardId }
    public var cardId: String
    public var mutationId: String
    public var changedAt: String
    public var state: CardSyncState
    public var card: SharedCard?

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
        self.card = state == .active ? card : nil
        self.card?.lastModifyTime = SyncTimestamp.milliseconds(from: self.changedAt)
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

public struct WebDAVSyncSnapshotV3: Codable, Hashable {
    public static let schemaVersion = "3.0.0"

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

public enum CardSyncMergeEngine {
    public static func merge(_ recordSets: [[CardSyncRecord]]) -> [CardSyncRecord] {
        var winningRecords: [String: CardSyncRecord] = [:]
        for record in recordSets.flatMap({ $0 }) {
            if let existing = winningRecords[record.cardId] {
                winningRecords[record.cardId] = winner(existing, record)
            } else {
                winningRecords[record.cardId] = record
            }
        }
        return winningRecords.values.sorted { $0.cardId < $1.cardId }
    }

    public static func activeCards(from records: [CardSyncRecord]) -> [SharedCard] {
        merge([records])
            .filter { $0.state == .active }
            .compactMap(\.card)
            .sorted { $0.id < $1.id }
    }

    public static func winner(_ lhs: CardSyncRecord, _ rhs: CardSyncRecord) -> CardSyncRecord {
        let lhsDate = SyncTimestamp.date(from: lhs.changedAt) ?? .distantPast
        let rhsDate = SyncTimestamp.date(from: rhs.changedAt) ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate ? lhs : rhs
        }
        if lhs.state != rhs.state {
            return lhs.state == .deleted ? lhs : rhs
        }
        return lhs.mutationId >= rhs.mutationId ? lhs : rhs
    }
}

public struct SyncLedger: Codable {
    public var records: [CardSyncRecord]
    public var processedWebDAVSnapshotIDs: Set<String>
    public var lastWebDAVSnapshotFilename: String?
    public var cloudKitStateData: Data?
    public var pendingWebDAVUpload: Bool
    public var pendingCloudKitUpload: Bool

    public init(
        records: [CardSyncRecord] = [],
        processedWebDAVSnapshotIDs: Set<String> = [],
        lastWebDAVSnapshotFilename: String? = nil,
        cloudKitStateData: Data? = nil,
        pendingWebDAVUpload: Bool = false,
        pendingCloudKitUpload: Bool = false
    ) {
        self.records = CardSyncMergeEngine.merge([records])
        self.processedWebDAVSnapshotIDs = processedWebDAVSnapshotIDs
        self.lastWebDAVSnapshotFilename = lastWebDAVSnapshotFilename
        self.cloudKitStateData = cloudKitStateData
        self.pendingWebDAVUpload = pendingWebDAVUpload
        self.pendingCloudKitUpload = pendingCloudKitUpload
    }
}
