import Foundation

enum WalletCacheStorage {
    static func directory(in cachesRoot: URL) -> URL {
        cachesRoot.appendingPathComponent("com.applist.cardwallet.mac", isDirectory: true)
    }

    static func clear(in cachesRoot: URL, fileManager: FileManager = .default) throws {
        let directory = directory(in: cachesRoot)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let values = try directory.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values.isSymbolicLink != true, values.isDirectory == true else {
            throw CocoaError(.fileWriteNoPermission)
        }
        for item in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try fileManager.removeItem(at: item)
        }
    }
}
