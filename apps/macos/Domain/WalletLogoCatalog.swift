import Foundation

/// Display-only metadata, copied from the Android offline catalogue. Never stored on a card.
struct WalletIssuerLogo: Decodable, Sendable, Equatable {
    let id: String
    let name: String
    let aliases: [String]
    let resource: String
}

/// Immutable indexes plus a thread-safe, bounded cache. Only bank names/regions are inspected.
final class WalletLogoCatalog: @unchecked Sendable {
    static let shared: WalletLogoCatalog = {
        guard let url = Bundle.main.url(forResource: "WalletBrandCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([WalletIssuerLogo].self, from: data) else {
            return WalletLogoCatalog(entries: [])
        }
        return WalletLogoCatalog(entries: entries)
    }()

    let entries: [WalletIssuerLogo]
    private struct Alias: Sendable { let value: String; let issuer: WalletIssuerLogo }
    private final class Match: NSObject {
        let issuer: WalletIssuerLogo?
        init(_ issuer: WalletIssuerLogo?) { self.issuer = issuer }
    }
    private let index: [Alias]
    private let exact: [String: [Alias]]
    private let cache = NSCache<NSString, Match>()
    private static let translations = Dictionary(zip(
        "銀國業興華農發門灣臺廣東滙豐慶陽儲郵長蘇龍寧漢廈恆華僑滬浙齊魯晉遼瀋陝鄭濰烏義壽營濟贛贊聯眾雲貴黔陸",
        "银国业兴华农发门湾台广东汇丰庆阳储邮长苏龙宁汉厦恒华侨沪浙齐鲁晋辽沈陕郑潍乌义寿营济赣赞联众云贵黔陆"
    ), uniquingKeysWith: { first, _ in first })
    private static let suffix = try! NSRegularExpression(pattern: "(?:股份有限公司|有限责任公司|有限公司|corporation|limited|ltd|inc)$")
    private static let words = try! NSRegularExpression(pattern: "[a-z0-9]+")

    init(entries: [WalletIssuerLogo]) {
        self.entries = entries
        self.index = entries.flatMap { issuer in
            Set((issuer.aliases + [issuer.name]).map(Self.normalized)).filter { !$0.isEmpty }
                .map { Alias(value: $0, issuer: issuer) }
        }
        self.exact = Dictionary(grouping: index, by: \.value)
        cache.countLimit = 256
    }

    /// Same NFKD / diacritic / common traditional-character handling as Android.
    static func normalized(_ value: String) -> String {
        let decomposed = value.decomposedStringWithCompatibilityMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
        let letters = String(String.UnicodeScalarView(decomposed.unicodeScalars.filter {
            !CharacterSet.nonBaseCharacters.contains($0) && CharacterSet.alphanumerics.contains($0)
        }))
        let mapped = String(letters.map { translations[$0] ?? $0 })
        return suffix.stringByReplacingMatches(in: mapped, range: NSRange(mapped.startIndex..., in: mapped), withTemplate: "")
    }

    func match(name: String, country: String = "") -> WalletIssuerLogo? {
        let key = (name + "\u{0000}" + country) as NSString
        if let cached = cache.object(forKey: key) { return cached.issuer }
        let normalized = Self.normalized(name)
        guard !normalized.isEmpty else { return nil }
        // Do not borrow China's Industrial Bank mark for Malaysia's RHB.
        let malaysian = ["malaysia", "my", "马来西亚"].contains(Self.normalized(country)) || normalized.contains("马来西亚")
        let restrictRHB = malaysian && normalized.contains("兴业银行")
        let precise = restrictRHB ? [] : (exact[normalized] ?? [])
        let unique = Dictionary(precise.map { ($0.issuer.id, $0.issuer) }, uniquingKeysWith: { a, _ in a })
        let result: WalletIssuerLogo?
        if unique.count == 1 {
            result = unique.values.first
        } else {
            let lower = name.lowercased(with: Locale(identifier: "en_US_POSIX"))
            let words = Set(Self.words.matches(in: lower, range: NSRange(lower.startIndex..., in: lower)).compactMap {
                Range($0.range, in: lower).map { String(lower[$0]) }
            })
            var bestScore = -1
            var best: [String: WalletIssuerLogo] = [:]
            for alias in index where !restrictRHB || alias.issuer.id.contains("rhb") {
                let a = alias.value
                let nonLatin = a.unicodeScalars.contains { $0.value > 127 }
                let matches = a == normalized || words.contains(a) ||
                    (nonLatin && a.count >= 3 && normalized.contains(a)) ||
                    (!nonLatin && a.count >= 8 && (normalized.hasPrefix(a) || normalized.hasSuffix(a)))
                guard matches else { continue }
                let score = a.count + (a == normalized ? 10_000 : 0)
                if score > bestScore { bestScore = score; best.removeAll(keepingCapacity: true) }
                if score == bestScore { best[alias.issuer.id] = alias.issuer }
            }
            result = best.count == 1 ? best.values.first : nil
        }
        cache.setObject(Match(result), forKey: key)
        return result
    }
}
