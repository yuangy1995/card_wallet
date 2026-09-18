import Foundation

/// Local display preferences. They never change card records, timestamps or SyncV4.
enum LocalCardPreferences {
    static let favoritesKey = "wallet_favorite_card_ids_v1"
    static let onlyFavoritesKey = "wallet_only_favorites_v1"

    static func favoriteIDs(_ value: String) -> Set<String> {
        guard let data = value.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids.filter { !$0.isEmpty })
    }

    static func toggle(_ id: String, defaults: UserDefaults = .standard) {
        guard !id.isEmpty else { return }
        var ids = favoriteIDs(defaults.string(forKey: favoritesKey) ?? "")
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        save(ids, defaults: defaults)
    }

    static func retain(_ validIDs: Set<String>, defaults: UserDefaults = .standard) {
        let ids = favoriteIDs(defaults.string(forKey: favoritesKey) ?? "")
        let valid = ids.intersection(validIDs)
        if ids != valid { save(valid, defaults: defaults) }
    }

    private static func save(_ ids: Set<String>, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(ids.sorted()),
              let text = String(data: data, encoding: .utf8) else { return }
        defaults.set(text, forKey: favoritesKey)
    }
}
