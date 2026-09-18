import Foundation
import CryptoKit

// 只验证新格式的 32 字节 seed；不把私钥、输入或底层错误写入日志。
do {
    guard CommandLine.arguments.count == 2,
          let encoded = ProcessInfo.processInfo.environment["SPARKLE_PRIVATE_KEY"],
          let seed = Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines)),
          seed.count == 32 else { throw NSError(domain: "Signing", code: 1) }
    let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let expected = plist["SUPublicEDKey"] as? String else { throw NSError(domain: "Signing", code: 2) }
    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
    guard key.publicKey.rawRepresentation.base64EncodedString() == expected else {
        throw NSError(domain: "Signing", code: 3)
    }
    print("Sparkle 新私钥与应用内置公钥匹配。")
} catch {
    fputs("Sparkle 签名配置不正确或仍为旧密钥，停止发布。\n", stderr)
    exit(1)
}
