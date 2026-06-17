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
}
