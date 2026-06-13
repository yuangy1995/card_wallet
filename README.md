# 银行卡管理 macOS 端

SwiftUI 的 macOS 原生客户端，用于本地管理信用卡和储蓄卡，并通过 WebDAV SyncV4 与 Web、Android 端同步。

本仓库只保留根目录 `README.md` 作为维护入口。旧开发计划文档已删除，后续维护以当前代码和本文件为准。

## 当前架构

- 平台：macOS 14+，SwiftUI，XcodeGen 生成 Xcode 工程。
- 依赖：CryptoSwift、CryptoKit、CloudKit。
- 本地卡片数据：`LocalStorageManager` 写入 Application Support 下的加密 `cards.json`。
- 凭证存储：WebDAV 账号、同步密钥和应用锁密码通过 `KeychainManager` 管理；部分开关和间隔配置使用 `UserDefaults`。
- 云同步：`SyncCoordinator` 统一协调本地账本、WebDAV bridge 和可选 iCloud。
- WebDAV：`WebDAVBridgeService` 使用 SyncV4 自动快照，文件名包含 `[SyncV4][Mac][自]`。
- iCloud：CloudKit 仅在具备正式签名和 entitlement 的构建中可验证；离线构建不具备真实 iCloud 能力。

## 关键数据规则

- `cardCategory` 表示卡类别，取值为 `credit` 或 `debit`；历史数据缺失时按 `credit` 处理。
- `type` 是历史字段名，当前实际表示币种代码。
- `bank` 是发卡行显示名；编辑同一银行名称时，需要同步影响同银行下的多张卡片。
- `cardImages` 保存卡片图片资产，会随卡片数据和 SyncV4 快照同步。
- `lastModifyTime` 是跨端合并的重要字段，保存本地修改时必须更新。

## 常用命令

```bash
# 生成工程并离线打包
./build.sh

# 带 CloudKit entitlement 的签名归档
CLOUDKIT_SIGNED_BUILD=1 DEVELOPMENT_TEAM=<Apple Team ID> ./build.sh
```

脚本成功后会输出：

```text
dist/CreditCardMac.app
```

如果本机没有 XcodeGen，需要先安装：

```bash
brew install xcodegen
```

## 调试提示

- 构建失败时先查看 `build/xcodebuild-archive.log`。
- WebDAV 同步异常优先检查 `Domain/WebDAVBridgeService.swift`、`Domain/WebDAVClient.swift` 和同步密钥。
- 本地读写异常优先检查 `Domain/LocalStorageManager.swift`、`Domain/CryptoManager.swift` 和 Application Support 下的 `CreditCardMac/cards.json`。
- CloudKit 不可用时，先确认是否使用正式签名归档，以及 entitlement 中是否包含 CloudKit。

## 维护注意

- `CreditCardMac.xcodeproj` 由 XcodeGen 生成，结构调整优先修改 `project.yml`。
- 离线构建用于本地运行，不代表 iCloud/CloudKit 能力已通过验证。
- 不要把 WebDAV 自动快照协议降级到旧导入导出方案。
- Web、Android、macOS 三端共用 SyncV4 数据语义，字段变更需要同时检查三端。
