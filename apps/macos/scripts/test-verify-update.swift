import Foundation
import CryptoKit

// 仅使用临时生成的测试密钥与虚拟安装包，不读取用户钥匙串或真实卡包。
let manager = FileManager.default
let root = manager.temporaryDirectory.appendingPathComponent("wallet-update-tests-\(UUID().uuidString)")
try manager.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? manager.removeItem(at: root) }
let app = root.appendingPathComponent("卡包.app")
let contents = app.appendingPathComponent("Contents")
try manager.createDirectory(at: contents, withIntermediateDirectories: true)
let key = Curve25519.Signing.PrivateKey()
let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
let plist: [String: Any] = [
    "CFBundleShortVersionString": "1.0.2",
    "CFBundleVersion": "4",
    "SUPublicEDKey": publicKey
]
let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
try plistData.write(to: contents.appendingPathComponent("Info.plist"))
let namespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"
let downloadRepository = "https://github.com/yuangy1995/card_wallet/"
var items: [String] = []
for arch in ["arm64", "x86_64"] {
    let data = Data("测试安装包 \(arch)".utf8)
    let name = "CardWallet-1.0.2-4-\(arch).zip"
    try data.write(to: root.appendingPathComponent(name))
    let signature = try key.signature(for: data).base64EncodedString()
    items.append("""
    <item>
      <sparkle:version>4</sparkle:version>
      <sparkle:shortVersionString>1.0.2</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      \(arch == "arm64" ? "<sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>" : "")
      <enclosure url="\(downloadRepository)releases/download/mac-v1.0.2-4/\(name)"
        length="\(data.count)" sparkle:edSignature="\(signature)"/>
    </item>
    """)
}
let xml = "<rss xmlns:sparkle=\"\(namespace)\"><channel>\(items.joined())</channel></rss>"
let verifier = root.appendingPathComponent("verify-update")
let compiler = Process()
compiler.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
compiler.arguments = ["swiftc", "scripts/verify-update.swift", "-o", verifier.path]
try compiler.run()
compiler.waitUntilExit()
guard compiler.terminationStatus == 0 else { fatalError("验证脚本编译失败") }
var count = 0
func check(_ name: String, _ feed: String, succeeds: Bool = false) throws {
    try Data(feed.utf8).write(to: root.appendingPathComponent("appcast.xml"))
    let process = Process()
    process.executableURL = verifier
    process.arguments = [app.path, root.path]
    let log = Pipe()
    process.standardOutput = log
    process.standardError = log
    try process.run()
    let data = log.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard (process.terminationStatus == 0) == succeeds else {
        fputs("失败：\(name)\n\(String(decoding: data, as: UTF8.self))", stderr)
        exit(1)
    }
    count += 1
    print("通过：\(name)")
}

try check("两个架构的有效签名", xml, succeeds: true)
try check("阻止错误构建号", xml.replacingOccurrences(of: "<sparkle:version>4", with: "<sparkle:version>3"))
try check("阻止错误版本", xml.replacingOccurrences(of: "<sparkle:shortVersionString>1.0.2", with: "<sparkle:shortVersionString>1.0.1"))
for (name, repository) in [
    ("阻止错误下载仓库", "https://github.com/yuangy1995/other-releases/"),
    ("阻止旧下载仓库", "https://github.com/yuangy1995/card-wallet-releases/"),
    ("阻止错误下载所有者", "https://github.com/other-owner/card_wallet/")
] {
    let changed = xml.replacingOccurrences(of: downloadRepository, with: repository)
    // 迁移地址后也必须真正改坏样本，不能把有效 feed 当作反例。
    guard changed != xml else { fatalError("下载仓库测试没有修改样本") }
    try check(name, changed)
}
try check("阻止错误大小", xml.replacingOccurrences(of: "length=\"", with: "length=\"9"))
try check("阻止缺失签名", xml.replacingOccurrences(of: "sparkle:edSignature=", with: "unsigned="))
try check("阻止错误签名命名空间", xml.replacingOccurrences(of: namespace, with: "https://example.invalid"))
try check("阻止缺失架构", xml.replacingOccurrences(of: items[1], with: ""))
try check("阻止错误架构顺序", xml.replacingOccurrences(of: items.joined(), with: items.reversed().joined()))
try check("阻止提高系统门槛", xml.replacingOccurrences(of: ">14.0<", with: ">15.0<"))
try check("阻止缺失架构条件", xml.replacingOccurrences(of: "<sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>", with: ""))
var wrongPlist = plist
wrongPlist["SUPublicEDKey"] = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
try PropertyListSerialization.data(fromPropertyList: wrongPlist, format: .xml, options: 0)
    .write(to: contents.appendingPathComponent("Info.plist"))
try check("阻止错误签名密钥", xml)
try plistData.write(to: contents.appendingPathComponent("Info.plist"))
let archivePath = root.appendingPathComponent("CardWallet-1.0.2-4-arm64.zip")
var corrupted = try Data(contentsOf: archivePath)
corrupted[0] ^= 1
try corrupted.write(to: archivePath)
try check("阻止同大小安装包内容篡改", xml)
print("\(count) 项更新包验证回归测试全部通过。")
