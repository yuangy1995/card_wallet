import Foundation

public class DataMigrationManager {
    
    /// 将有效期格式（YYYY-MM-DD, YYYY-MM, ISO Date 串）转换为标准的 MM/YY 格式
    public static func convertValidToMMYY(_ valid: String?) -> String {
        guard let valid = valid, !valid.isEmpty else { return "" }
        
        let trimmed = valid.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 如果已经是 MM/YY 格式，直接返回
        let mmyyRegex = "^\\d{2}/\\d{2}$"
        if trimmed.range(of: mmyyRegex, options: .regularExpression) != nil {
            return trimmed
        }
        
        // 2. 尝试匹配 YYYY-MM-DD 或 YYYY-MM 格式
        let yyyymmddRegex = "^(\\d{4})-(\\d{2})(-\\d{2})?$"
        if let match = trimmed.range(of: yyyymmddRegex, options: .regularExpression) {
            let components = trimmed.components(separatedBy: "-")
            if components.count >= 2 {
                let year = components[0]
                let month = components[1]
                let yearSuffix = String(year.suffix(2))
                return "\(month)/\(yearSuffix)"
            }
        }
        
        // 3. 尝试使用 DateFormatter 解析 ISO 8601 或其他常见日期字符串
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd",
            "EEE MMM dd HH:mm:ss zzz yyyy"
        ].map { format -> DateFormatter in
            let df = DateFormatter()
            df.dateFormat = format
            df.locale = Locale(identifier: "en_US_POSIX")
            return df
        }
        
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) {
                let calendar = Calendar.current
                let year = calendar.component(.year, from: date)
                let month = calendar.component(.month, from: date)
                let monthStr = String(format: "%02d", month)
                let yearSuffix = String(format: "%02d", year % 100)
                return "\(monthStr)/\(yearSuffix)"
            }
        }
        
        // 4. 降级容错：尝试直接用正则提取数字
        let digits = trimmed.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        if digits.count >= 6 {
            // 假设前4位为年，后2位为月
            let yearSuffix = String(digits.prefix(4).suffix(2))
            let month = String(digits.dropFirst(4).prefix(2))
            return "\(month)/\(yearSuffix)"
        }
        
        return ""
    }
    
    /// 将 Any 类型的数据安全地转换为 Double 数值
    public static func ensureDouble(_ value: Any?, defaultValue: Double = 0.0) -> Double {
        guard let value = value else { return defaultValue }
        if let doubleVal = value as? Double {
            return doubleVal
        }
        if let intVal = value as? Int {
            return Double(intVal)
        }
        if let floatVal = value as? Float {
            return Double(floatVal)
        }
        if let stringVal = value as? String {
            return Double(stringVal) ?? defaultValue
        }
        return defaultValue
    }
    
    /// 将 Any 类型的数据安全地转换为 Bool 布尔值
    public static func ensureBool(_ value: Any?, defaultValue: Bool) -> Bool {
        guard let value = value else { return defaultValue }
        if let boolVal = value as? Bool {
            return boolVal
        }
        if let stringVal = value as? String {
            let lower = stringVal.lowercased()
            if lower == "true" || lower == "1" || lower == "yes" { return true }
            if lower == "false" || lower == "0" || lower == "no" { return false }
        }
        if let intVal = value as? Int {
            return intVal != 0
        }
        return defaultValue
    }

    /// 解析跨端产生的卡片最后修改时间，兼容 Web 与 macOS 的历史格式
    public static func parseLastModifyTime(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: trimmed) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: trimmed) {
            return date
        }

        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy/MM/dd HH:mm:ss.SSS"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    /// 比较本地与备份版本时间；无法可靠解析时返回 nil，由调用方采用保守策略
    public static func compareLastModifyTime(local: String, backup: String) -> ComparisonResult? {
        guard let localDate = parseLastModifyTime(local),
              let backupDate = parseLastModifyTime(backup) else {
            return nil
        }

        return localDate.compare(backupDate)
    }
    
    /// 💡 递归解析嵌套的 JSON（防范多次转义的字符串与嵌套包裹）
    public static func recursivelyParseJSON(_ jsonString: String) -> Any? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: [])
            if let str = parsed as? String {
                return recursivelyParseJSON(str)
            }
            return parsed
        } catch {
            return nil
        }
    }
    
    /// 清洗和规范化单张卡片数据（对应 Web 端 migrateCardData 逻辑）
    /// - Parameter rawDict: 解析 JSON 得到的原始卡片字典
    /// - Returns: 100% 标准化、规整的 SharedCard 模型
    public static func migrateSingleCard(_ rawDict: [String: Any]) -> SharedCard {
        var dict = rawDict
        
        // 1. UUID/ID 缺失补全与类型高宽容度兼容提取
        var idStr = ""
        if let rawId = dict["id"] {
            if let strId = rawId as? String {
                idStr = strId.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // 💡 如果是 Int, Double 等数值型 ID，高精还原为 String 格式，防范转型失败引致的卡片 ID 重生成错配！
                idStr = String(describing: rawId).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let finalId = idStr.isEmpty ? UUID().uuidString : idStr
        
        // 2. 基本字段规范化为 String
        let country = (dict["country"] as? String) ?? "中国"
        let bank = (dict["bank"] as? String) ?? "未知银行"
        let cardNumber = (dict["cardNumber"] as? String) ?? ""
        let alias = dict["alias"] as? String
        let level = dict["level"] as? String
        let type = (dict["type"] as? String) ?? "CNY"
        let cvv = dict["cvv"] as? String
        let equity = dict["equity"] as? String
        let remark = dict["remark"] as? String
        
        // 3. 有效期格式 YYYY-MM-DD / YYYY-MM 转换为 MM/YY
        let oldValid = dict["valid"] as? String
        let valid = convertValidToMMYY(oldValid)
        
        // 4. 账单日和还款日强制统一为 String
        let accountBillDate = dict["accountBillDate"] != nil ? String(describing: dict["accountBillDate"]!) : ""
        let dueDate = dict["dueDate"] != nil ? String(describing: dict["dueDate"]!) : ""
        
        // 5. 确保数值类型正确
        let limit = ensureDouble(dict["limit"], defaultValue: 0.0)
        let annualFee = ensureDouble(dict["annualFee"], defaultValue: 0.0)
        
        // 6. 年费达标状态字段校验，默认为 "2" (未达标)
        var isQualified = (dict["isQualified"] as? String) ?? "2"
        if !["1", "2", "3"].contains(isQualified) {
            isQualified = "2"
        }
        
        let nextAnnualFeeCollectionTime = dict["nextAnnualFeeCollectionTime"] as? String
        let lastTime = dict["lastTime"] as? String
        
        // 7. 确保布尔值正确
        let isSharedLimit = ensureBool(dict["isSharedLimit"], defaultValue: true)
        let billingDaySpendingToNextBill = ensureBool(dict["billingDaySpendingToNextBill"], defaultValue: true)
        
        // 8. 补全最后修改时间 (YYYY-MM-DD HH:mm:ss 格式)
        var lastModifyTime = (dict["lastModifyTime"] as? String) ?? ""
        if lastModifyTime.isEmpty {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            lastModifyTime = df.string(from: Date())
        }
        
        return SharedCard(
            id: finalId,
            country: country,
            bank: bank,
            cardNumber: cardNumber,
            alias: alias,
            level: level,
            type: type,
            limit: limit,
            cvv: cvv,
            valid: valid,
            annualFee: annualFee,
            isQualified: isQualified,
            nextAnnualFeeCollectionTime: nextAnnualFeeCollectionTime,
            lastTime: lastTime,
            accountBillDate: accountBillDate,
            dueDate: dueDate,
            billingDaySpendingToNextBill: billingDaySpendingToNextBill,
            equity: equity,
            remark: remark,
            lastModifyTime: lastModifyTime,
            isSharedLimit: isSharedLimit
        )
    }
    
    /// 批量迁移和修复卡片数据（对应 Web 端 autoMigrateLocalData 逻辑）
    /// - Parameter rawArray: 原始解析得到的卡片数组
    /// - Returns: 洗清整洁后的 SharedCard 数组
    public static func migrateCardsBatch(_ rawArray: [[String: Any]]) -> [SharedCard] {
        return rawArray.map { migrateSingleCard($0) }
    }
}
