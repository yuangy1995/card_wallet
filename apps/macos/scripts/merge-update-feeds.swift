import Foundation

// Sparkle 同版本保留第一个兼容条目：Apple Silicon 优先，Intel 回退。
let paths = CommandLine.arguments
let arm = try XMLDocument(contentsOf: URL(fileURLWithPath: paths[1]))
let intel = try XMLDocument(contentsOf: URL(fileURLWithPath: paths[2]))
let channel = try arm.nodes(forXPath: "/rss/channel").first!
let armItem = try arm.nodes(forXPath: "/rss/channel/item").first!
let armRequirement = try armItem.nodes(forXPath: "*[local-name()='hardwareRequirements']").first?.stringValue
precondition(armRequirement == "arm64")
let intelItem = try intel.nodes(forXPath: "/rss/channel/item").first!.copy() as! XMLElement
let intelRequirements = try intelItem.nodes(forXPath: "*[local-name()='hardwareRequirements']")
precondition(intelRequirements.isEmpty)
(channel as! XMLElement).addChild(intelItem)
try arm.xmlData(options: .nodePrettyPrint).write(to: URL(fileURLWithPath: paths[3]))
