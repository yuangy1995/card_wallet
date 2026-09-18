import Foundation
import CryptoKit

// 使用应用内置公钥独立验证更新包，不能只信任生成器的退出码。
struct VerificationError: Error, CustomStringConvertible {
    let description: String
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw VerificationError(description: message) }
}

func verify(app: URL, output: URL) throws {
    let plistData = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
    let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
    guard let version = plist?["CFBundleShortVersionString"] as? String,
          let build = plist?["CFBundleVersion"] as? String,
          let encodedKey = plist?["SUPublicEDKey"] as? String,
          let keyData = Data(base64Encoded: encodedKey) else {
        throw VerificationError(description: "应用缺少版本号、构建号或更新公钥。")
    }
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
    let tag = "mac-v\(version)-\(build)"
    let prefix = "https://github.com/yuangy1995/card_wallet/releases/download/\(tag)/"
    let feed = try XMLDocument(contentsOf: output.appendingPathComponent("appcast.xml"),
                               options: .nodeLoadExternalEntitiesNever)
    let items = try feed.nodes(forXPath: "/rss/channel/item")
    try require(items.count == 2, "更新清单必须包含两个架构条目。")
    let namespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"
    for (index, arch) in ["arm64", "x86_64"].enumerated() {
        guard let item = items[index] as? XMLElement else {
            throw VerificationError(description: "更新条目格式不正确。")
        }
        func values(_ name: String) -> [String] {
            item.elements(forLocalName: name, uri: namespace).compactMap(\.stringValue)
        }
        try require(values("version") == [build], "更新构建号与应用不一致。")
        try require(values("shortVersionString") == [version], "更新版本号与应用不一致。")
        try require(values("minimumSystemVersion") == ["14.0"], "更新系统门槛不符合当前稳定通道。")
        try require(values("hardwareRequirements") == (arch == "arm64" ? ["arm64"] : []),
                    "更新架构顺序或兼容条件不正确。")
        let enclosures = try item.nodes(forXPath: "enclosure")
        guard enclosures.count == 1, let enclosure = enclosures.first as? XMLElement else {
            throw VerificationError(description: "更新条目必须包含一个安装包。")
        }
        let filename = "CardWallet-\(version)-\(build)-\(arch).zip"
        try require(enclosure.attribute(forName: "url")?.stringValue == prefix + filename,
                    "安装包下载地址不符合发布目标。")
        let archive = try Data(contentsOf: output.appendingPathComponent(filename))
        try require(enclosure.attribute(forName: "length")?.stringValue == String(archive.count),
                    "安装包大小与清单不一致。")
        guard let encodedSignature = enclosure.attribute(forLocalName: "edSignature", uri: namespace)?.stringValue,
              let signature = Data(base64Encoded: encodedSignature) else {
            throw VerificationError(description: "安装包缺少有效更新签名。")
        }
        try require(key.isValidSignature(signature, for: archive), "安装包签名不能通过应用内置公钥验证。")
    }
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw VerificationError(description: "用法: swift verify-update.swift /路径/卡包.app /路径/更新目录")
    }
    try verify(app: URL(fileURLWithPath: CommandLine.arguments[1]),
               output: URL(fileURLWithPath: CommandLine.arguments[2]))
    print("两个架构的更新地址、版本、大小和 EdDSA 签名验证通过。")
} catch {
    // 不输出生成器输入或私钥，只报告验证错误。
    fputs("更新包验证失败：\(error)\n", stderr)
    exit(1)
}
