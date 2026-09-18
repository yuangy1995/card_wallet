import Foundation

enum LocalSyncHistory {
    private static var file: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CardWallet/sync-history.enc") }
    static func read<T: Codable>(_ type: T.Type, legacyKey: String) throws -> T? {
        if FileManager.default.fileExists(atPath: file.path) {
            let data = try Data(contentsOf: file)
            let plain = try LocalDataCipher.shared.open(data)
            return try JSONDecoder().decode(type, from: plain)
        }
        guard let data = UserDefaults.standard.data(forKey: legacyKey) else { return nil }
        let value = try JSONDecoder().decode(type, from: data)
        try write(value)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        return value
    }
    static func write<T: Encodable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        let encrypted = try LocalDataCipher.shared.seal(data)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encrypted.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
