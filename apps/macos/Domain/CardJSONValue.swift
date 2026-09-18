import Foundation

/// Opaque future fields round-trip without becoming editable UI or changing SyncV4.
public enum CardJSONValue: Codable, Hashable, Sendable {
    case null, bool(Bool), string(String), number(Decimal), array([CardJSONValue]), object([String: CardJSONValue])
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode(Decimal.self) { self = .number(v) }
        else if let v = try? value.decode([CardJSONValue].self) { self = .array(v) }
        else { self = .object(try value.decode([String: CardJSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

struct CardJSONKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

enum CardFutureFields {
    static let transient: Set<String> = ["showCardNumber", "showCVV", "countryRowSpan", "showCountry", "bankRowSpan", "showBank", "limitRowSpan", "showLimit", "lastTimeRowSpan", "showLastTime", "cardId", "uuid", "legacyId"]
    static func allowed(_ key: String) -> Bool { !key.hasPrefix("_") && !transient.contains(key) }
    static func decode(from decoder: Decoder, known: Set<String>) throws -> [String: CardJSONValue] {
        let container = try decoder.container(keyedBy: CardJSONKey.self)
        var fields: [String: CardJSONValue] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) && allowed(key.stringValue) {
            fields[key.stringValue] = try container.decode(CardJSONValue.self, forKey: key)
        }
        return fields
    }
    static func encode(_ fields: [String: CardJSONValue], to encoder: Encoder, known: Set<String>) throws {
        var container = encoder.container(keyedBy: CardJSONKey.self)
        for (name, value) in fields where !known.contains(name) && allowed(name) {
            try container.encode(value, forKey: CardJSONKey(name))
        }
    }
}
