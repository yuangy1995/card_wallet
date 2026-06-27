import Foundation

public enum BankNameNormalizer {
    private static let bankParenthesesPattern = "\\s*[（(][^（）()]*[）)]\\s*"
    private static let whitespacePattern = "\\s+"

    public static func display(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func normalizedKey(_ value: String?) -> String {
        display(value)
            .replacingOccurrences(of: bankParenthesesPattern, with: "", options: .regularExpression)
            .replacingOccurrences(of: whitespacePattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func namesReferToSameBank(_ left: String?, _ right: String?) -> Bool {
        let leftDisplay = display(left)
        let rightDisplay = display(right)
        guard !leftDisplay.isEmpty, !rightDisplay.isEmpty else { return false }
        if leftDisplay == rightDisplay { return true }

        let leftKey = normalizedKey(leftDisplay)
        let rightKey = normalizedKey(rightDisplay)
        return !leftKey.isEmpty && !rightKey.isEmpty && leftKey == rightKey
    }


}
