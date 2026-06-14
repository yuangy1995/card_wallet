import Foundation

public class DataMigrationManager {

    /// 将有效期格式（YYYY-MM-DD, YYYY-MM, ISO Date 串）转换为标准的 MM/YY 格式
    public static func convertValidToMMYY(_ valid: String?) -> String {
        guard let valid = valid, !valid.isEmpty else { return "" }
        let trimmed = valid.trimmingCharacters(in: .whitespacesAndNewlines)
        let mmyyRegex = "^\\d{2}/\\d{2}$"
        if trimmed.range(of: mmyyRegex, options: .regularExpression) != nil { return trimmed }
        let yyyymmddRegex = "^(\\d{4})-(\\d{2})(-\\d{2})?$"
        if trimmed.range(of: yyyymmddRegex, options: .regularExpression) != nil {
            let components = trimmed.components(separatedBy: "-")
            if components.count >= 2 {
                return "\(components[1])/\(String(components[0].suffix(2)))"
            }
        }
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss", "yyyy/MM/dd", "EEE MMM dd HH:mm:ss zzz yyyy"
        ]
        for format in formats {
            let df = DateFormatter()
            df.dateFormat = format
            df.locale = Locale(identifier: "en_US_POSIX")
            if let date = df.date(from: trimmed) {
                let cal = Calendar.current
                let year = cal.component(.year, from: date)
                let month = cal.component(.month, from: date)
                return String(format: "%02d/%02d", month, year % 100)
            }
        }
        let digits = trimmed.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        if digits.count >= 6 {
            let yearSuffix = String(digits.prefix(4).suffix(2))
            let month = String(digits.dropFirst(4).prefix(2))
            return "\(month)/\(yearSuffix)"
        }
        return ""
    }

    public static func ensureDouble(_ value: Any?, defaultValue: Double = 0.0) -> Double {
        guard let value = value else { return defaultValue }
        if let v = value as? Double { return v }
        if let v = value as? Int { return Double(v) }
        if let v = value as? Float { return Double(v) }
        if let v = value as? String { return Double(v) ?? defaultValue }
        return defaultValue
    }

    public static func timestampMilliseconds(from value: Any?) -> Double? {
        guard let value = value else { return nil }
        if let v = value as? Double { return normalizeTimestampNumber(v) }
        if let v = value as? Int { return normalizeTimestampNumber(Double(v)) }
        if let v = value as? Int64 { return normalizeTimestampNumber(Double(v)) }
        if let v = value as? Float { return normalizeTimestampNumber(Double(v)) }
        if let v = value as? Date { return v.timeIntervalSince1970 * 1000.0 }
        if let v = value as? String {
            let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if let numeric = Double(trimmed) { return normalizeTimestampNumber(numeric) }
            if let date = parseLastModifyTime(trimmed) { return date.timeIntervalSince1970 * 1000.0 }
        }
        return nil
    }

    public static func currentTimestampMilliseconds() -> Double {
        Date().timeIntervalSince1970 * 1000.0
    }

    public static func date(fromTimestamp timestamp: Double?) -> Date? {
        guard let timestamp, timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: normalizeTimestampNumber(timestamp) / 1000.0)
    }

    private static func normalizeTimestampNumber(_ value: Double) -> Double {
        guard value > 0 else { return value }
        return value < 10_000_000_000 ? value * 1000.0 : value
    }

    public static func ensureBool(_ value: Any?, defaultValue: Bool) -> Bool {
        guard let value = value else { return defaultValue }
        if let v = value as? Bool { return v }
        if let v = value as? String {
            let lower = v.lowercased()
            if lower == "true" || lower == "1" || lower == "yes" { return true }
            if lower == "false" || lower == "0" || lower == "no" { return false }
        }
        if let v = value as? Int { return v != 0 }
        return defaultValue
    }

    public static func parseLastModifyTime(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let numeric = Double(trimmed) { return date(fromTimestamp: numeric) }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: trimmed) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: trimmed) { return d }
        let formats = [
            "yyyy-MM-dd HH:mm:ss", "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSS", "yyyy/MM/dd HH:mm:ss.SSS",
            "yyyy-MM-dd", "yyyy/MM/dd"
        ]
        for format in formats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = format
            if let d = df.date(from: trimmed) { return d }
        }
        return nil
    }

    public static func compareLastModifyTime(local: Double, backup: Double) -> ComparisonResult? {
        guard let localDate = date(fromTimestamp: local),
              let backupDate = date(fromTimestamp: backup) else { return nil }
        return localDate.compare(backupDate)
    }

    public static func recursivelyParseJSON(_ jsonString: String) -> Any? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: [])
            if let str = parsed as? String { return recursivelyParseJSON(str) }
            return parsed
        } catch { return nil }
    }

    public static func migrateSingleCard(_ rawDict: [String: Any]) -> SharedCard {
        let idStr = firstStringValue(in: rawDict, keys: ["id", "cardId", "_id", "uuid"]) ?? ""
        let finalId = idStr.isEmpty ? UUID().uuidString : idStr
        let rawCategory = (rawDict["cardCategory"] as? String) ?? "credit"
        let cardCategory = rawCategory == "debit" ? "debit" : "credit"
        let country = (rawDict["country"] as? String) ?? ""
        let bank = (rawDict["bank"] as? String) ?? ""
        let cardNumber = (rawDict["cardNumber"] as? String) ?? ""
        let alias = rawDict["alias"] as? String
        let level = rawDict["level"] as? String
        let type = (rawDict["type"] as? String) ?? ""
        let cvv = rawDict["cvv"] as? String
        let equity = rawDict["equity"] as? String
        let remark = rawDict["remark"] as? String
        let valid = convertValidToMMYY(rawDict["valid"] as? String)
        let accountBillDate = rawDict["accountBillDate"] != nil ? String(describing: rawDict["accountBillDate"]!) : ""
        let dueDate = rawDict["dueDate"] != nil ? String(describing: rawDict["dueDate"]!) : ""
        let limit = ensureDouble(rawDict["limit"])
        let annualFee = ensureDouble(rawDict["annualFee"])
        var isQualified = (rawDict["isQualified"] as? String) ?? "2"
        if !["1","2","3"].contains(isQualified) { isQualified = "2" }
        let nextAnnualFeeCollectionTime = timestampMilliseconds(from: rawDict["nextAnnualFeeCollectionTime"])
        let lastTime = timestampMilliseconds(from: rawDict["lastTime"])
        let isSharedLimit = ensureBool(rawDict["isSharedLimit"], defaultValue: true)
        let billingDaySpendingToNextBill = ensureBool(rawDict["billingDaySpendingToNextBill"], defaultValue: true)
        let cardImages = parseCardImages(rawDict["cardImages"])
        let lastModifyTime = timestampMilliseconds(from: rawDict["lastModifyTime"]) ?? currentTimestampMilliseconds()

        return SharedCard(
            id: finalId, cardCategory: cardCategory, country: country, bank: bank,
            cardNumber: cardNumber, alias: alias, level: level, type: type,
            limit: limit, cvv: cvv, valid: valid, annualFee: annualFee,
            isQualified: isQualified,
            nextAnnualFeeCollectionTime: nextAnnualFeeCollectionTime,
            lastTime: lastTime, accountBillDate: accountBillDate, dueDate: dueDate,
            billingDaySpendingToNextBill: billingDaySpendingToNextBill,
            equity: equity, remark: remark, lastModifyTime: lastModifyTime,
            isSharedLimit: isSharedLimit, cardImages: cardImages
        )
    }

    public static func migrateCardsBatch(_ rawArray: [[String: Any]]) -> [SharedCard] {
        rawArray.map { migrateSingleCard($0) }
    }

    private static func firstStringValue(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let raw = dict[key], !(raw is NSNull) else { continue }
            let str: String
            if let v = raw as? String { str = v }
            else if let v = raw as? NSNumber { str = v.stringValue }
            else { str = String(describing: raw) }
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private static func parseCardImages(_ value: Any?) -> [CardImageAsset] {
        guard let rawItems = value as? [Any] else { return [] }
        return rawItems.enumerated().compactMap { index, item in
            if let dataUrl = item as? String, !dataUrl.isEmpty {
                return CardImageAsset(data: dataUrl, source: "legacy", name: "card_image_\(index + 1).jpg")
            }
            guard let dict = item as? [String: Any], let data = dict["data"] as? String, !data.isEmpty else { return nil }
            let createdAt = timestampMilliseconds(from: dict["createdAt"]) ?? currentTimestampMilliseconds()
            return CardImageAsset(
                id: (dict["id"] as? String) ?? UUID().uuidString,
                mimeType: (dict["mimeType"] as? String) ?? "image/jpeg",
                data: data, createdAt: createdAt,
                source: (dict["source"] as? String) ?? "ios_upload",
                name: (dict["name"] as? String) ?? ""
            )
        }
    }

    public static func cardsFromBackupJSON(_ jsonString: String) -> [SharedCard]? {
        let cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cards = decodeV3SnapshotCards(from: cleaned) { return cards }
        guard let parsedObject = recursivelyParseJSON(cleaned) else { return nil }
        if let dict = parsedObject as? [String: Any],
           dict["schemaVersion"] as? String == WebDAVSyncSnapshotV3.schemaVersion,
           let data = try? JSONSerialization.data(withJSONObject: dict),
           let snapshot = try? JSONDecoder().decode(WebDAVSyncSnapshotV3.self, from: data) {
            return CardSyncMergeEngine.activeCards(from: snapshot.records)
        }
        var rawCards: [[String: Any]] = []
        if let array = parsedObject as? [[String: Any]] {
            rawCards = array
        } else if let dict = parsedObject as? [String: Any] {
            rawCards = (dict["cards"] as? [[String: Any]]) ?? (dict["data"] as? [[String: Any]]) ?? []
        }
        return rawCards.isEmpty ? nil : migrateCardsBatch(rawCards)
    }

    public static func backupJSONIsV3Snapshot(_ jsonString: String) -> Bool {
        let cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if decodeV3SnapshotCards(from: cleaned) != nil { return true }
        guard let parsedObject = recursivelyParseJSON(cleaned),
              let dict = parsedObject as? [String: Any],
              dict["records"] is [[String: Any]] else { return false }
        return dict["schemaVersion"] as? String == WebDAVSyncSnapshotV3.schemaVersion
    }

    private static func decodeV3SnapshotCards(from jsonString: String) -> [SharedCard]? {
        guard let data = jsonString.data(using: .utf8),
              let snapshot = try? JSONDecoder().decode(WebDAVSyncSnapshotV3.self, from: data),
              snapshot.schemaVersion == WebDAVSyncSnapshotV3.schemaVersion else { return nil }
        return CardSyncMergeEngine.activeCards(from: snapshot.records)
    }
}
