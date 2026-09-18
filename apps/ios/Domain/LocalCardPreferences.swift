import Foundation

/// Local presentation preference, deliberately outside SharedCard and the SyncV4 ledger.
public enum LocalCardPreferences {
    public static let favoritesKey = "wallet_favorite_card_ids"
    public static func decodeFavorites(_ raw: String) -> Set<String> {
        guard let bytes = raw.data(using: .utf8), let values = try? JSONDecoder().decode([String].self, from: bytes) else { return [] }
        return Set(values.filter { !$0.isEmpty })
    }
    public static func favorites(in defaults: UserDefaults = .standard) -> Set<String> {
        decodeFavorites(defaults.string(forKey: favoritesKey) ?? "[]")
    }
    private static func save(_ ids: Set<String>, in defaults: UserDefaults) {
        guard let bytes = try? JSONEncoder().encode(ids.sorted()), let raw = String(data: bytes, encoding: .utf8) else { return }
        defaults.set(raw, forKey: favoritesKey)
    }
    public static func toggleFavorite(_ id: String, in defaults: UserDefaults = .standard) {
        guard !id.isEmpty else { return }
        var ids = favorites(in: defaults)
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        save(ids, in: defaults)
    }
    /// Only committed tombstones are removed. Filtering, paging, locking and loading cannot clear favorites.
    public static func removeDeleted(_ deletedIDs: Set<String>, in defaults: UserDefaults = .standard) {
        let old = favorites(in: defaults), next = favorites(in: defaults).subtracting(deletedIDs)
        if old != next { save(next, in: defaults) }
    }
}
