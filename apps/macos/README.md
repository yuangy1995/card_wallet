# 卡包 macOS 端

SwiftUI 的 macOS 原生卡包客户端，用于本地管理信用卡和储蓄卡，并通过 WebDAV SyncV4 与 Web、Android 端同步。

本仓库只保留根目录 `README.md` 作为维护入口。旧开发计划文档已删除，后续维护以当前代码和本文件为准。

## 当前架构

- 平台：macOS 14+，SwiftUI，XcodeGen 生成 Xcode 工程。
- 界面：侧栏、卡片列表与详情三栏布局；窗口顶部透明且不显示标题，保留系统窗口按钮。分类切换统一使用轻量标签，云同步入口集中在侧栏底部。默认冰蓝皮肤，可切换森绿、浅色/深色、紧凑列表及减少透明效果，尊重系统减少动态效果设置。
- 展示层：`WalletTheme` 统一外观，`CardCatalog`、`CardStatistics`、`CardEditing` 分离筛选统计和编辑规则；列表与图片使用缓存，避免反复解码和计算。
- 本地化：`Resources/Localizable.xcstrings` 维护简体及繁体中文界面文案。
- 详情与编辑：自定义分区布局取代系统大表单；弹窗宽高根据父窗口预留边距，正文独立滚动，操作按钮固定显示。终免年费不显示金额和收取日期。
- 附件照片：侧栏详情与完整详情均有缩略图和明确的查看入口；独立预览支持上一张/下一张、缩放、适应窗口，预览框跟随皮肤且受锁屏保护，不修改原始附件。
- 导航：优惠用卡、卡片统计、检查卡片各保留一个侧栏入口，同步只保留底部入口；移除重复的工具汇总页。
- 设置：分类采用图标导航，子页使用统一主题卡片、可视化皮肤选项和分层说明；同步记录的选中高亮随皮肤及浅色/深色外观变化，支持单击与方向键选择。
- 统计：概览卡片保持等高，多币种独立分行；年费待确认、提额记录和低额度卡片分区展示。
- 图标：`Resources/AppIcon.png` 为 1024px 源图，`AppIcon.appiconset` 提供 Dock/系统图标，`WalletLogo.imageset` 用于侧栏。使用内置图片生成工具设计，经用户同意用本地工具裁切透明圆角并导出各尺寸。设计提示词摘要：简洁的蓝色卡包，冰蓝和森绿卡片，白色圆角底，清晰轮廓、轻微层次、无文字和霓虹装饰，小尺寸可辨认。
- 依赖：CryptoSwift、CryptoKit、Sparkle 2。
- 本地卡片数据：`LocalStorageManager` 写入 Application Support 下的加密 `cards.json`。
- 凭证存储：`KeychainManager` 保留调用接口，正常读写改为 `LocalCredentialStore` 的本地 AES-GCM 加密文件；每份凭证库使用独立随机密钥，凭证文件和密钥仅当前用户可读写。部分开关和间隔配置使用 `UserDefaults`。
- 首次升级：读取旧钥匙串凭证，完整写入本地后才标记迁移成功。可能需要系统授权；拒绝后不重复自动申请，可在锁屏主动重试。旧钥匙串记录不会被删除，迁移成功后不再访问。旧版本的本地加密文件也可读取。
- 云同步：`SyncCoordinator` 只协调本地账本和 WebDAV bridge；已移除 Apple 私有云同步及其权限。旧账本中的额外字段会被忽略，卡片和 WebDAV 状态仍可读取。
- WebDAV：`WebDAVBridgeService` 使用 SyncV4 自动快照，文件名包含 `[SyncV4][Mac][自]`。
- 性能：连续本地修改在 0.8 秒内合并触发上传，同步快照在后台准备和加密；系统通知刷新延迟 0.4 秒合并、排程在后台计算；卡片分组排序后台执行并丢弃过时结果，保留已有预计算缓存。锁定时取消尚未触发的上传和通知刷新。

## 关键数据规则

- `cardCategory` 表示卡类别，取值为 `credit` 或 `debit`；历史数据缺失时按 `credit` 处理。
- `type` 是历史字段名，当前实际表示币种代码。
- `bank` 是发卡行显示名；编辑同一银行名称时，需要同步影响同银行下的多张卡片。
- `cardImages` 保存卡片图片资产，会随卡片数据和 SyncV4 快照同步。
- `lastModifyTime` 是跨端合并的重要字段，保存本地修改时必须更新。

## 常用命令

```bash
# 生成工程并以固定 Ad-Hoc 临时签名打包
./build.sh
```

脚本成功后会输出：

```text
dist/卡包.app
```

如果本机没有 XcodeGen，需要先安装：

```bash
brew install xcodegen
```

## 操作与回归测试

- `⌘N` 添加卡片，`⌘F` 搜索，`⌘E` 编辑当前卡片，`⌘,` 打开设置；列表支持方向键选卡。
- 单击卡片立即选中并更新右侧详情；仅方向键导航触发自动滚动，焦点使用细圆角线提示。
- 卡片编辑、图片、批量操作、年费提醒、优惠用卡、统计导出、应用锁与同步设置仍保留。
- 单元测试通过 `WALLET_TEST_HOST=1` 隔离应用启动，不读取真实卡包、钥匙串或启动云同步。

```bash
xcodegen generate
xcodebuild -project CreditCardMac.xcodeproj -scheme CreditCardMac \
  -configuration Release ENABLE_TESTABILITY=YES \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  test CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS=''
```

回归测试覆盖日期、加密、同步合并，以及共享额度、卡片编辑、年费确认、同步状态脱敏、CSV 导出、皮肤偏好、缓存清理边界、本地凭证加密、旧凭证迁移、授权拒绝后的重试和后台处理结果一致性。完整同步密文测试包含密钥派生运算，建议按上述 Release 配置运行；Debug 未优化构建会明显更慢。真实 WebDAV 和 Touch ID 需使用对应账户及设备另行验证。

## 公开仓库发布和在线更新

源码、发布工作流和正式安装包统一在 `yuangy1995/card_wallet`。不再依赖独立产物仓库或跨仓库发布令牌。应用使用本仓库的 `releases/latest/download/appcast.xml`；Android 发布必须保持 `--latest=false`，Mac 发布设为 Latest。

发布仍使用 `build.sh` 的 Ad-Hoc 签名和非沙盒数据位置，不增加 Developer ID 或公证要求。应用标识和本地存储不变，不要删除用户数据文件。2026-09-18 的迁移更换 Sparkle 更新密钥并切换仓库，旧版需先手动安装迁移后的版本；之后同一密钥系列的版本可以继续应用内更新。

`Publish macOS release` 仅从本仓库 `main` 手动触发。Secrets 只需 `SPARKLE_PRIVATE_KEY`，发布权限来自 job 的 `contents: write` 与临时 `GITHUB_TOKEN`，不再使用 `RELEASES_TOKEN`。新私钥为 Base64 编码的 32 字节 Ed25519 seed；公钥保存在 `Resources/Info.plist`。工作流在编译前验证私钥与公钥匹配，不接受旧密钥。

配置步骤与备份规则见 [签名与公开发布](../../docs/signing-security.md)。准备版本 `1.1.0`、构建号 `7` 及对应 `releases/1.1.0.md` 后执行：

```bash
gh workflow run macos-release.yml --repo yuangy1995/card_wallet --ref main -f version=1.1.0 -f publish=true
```

后续发布先递增 `project.yml` 中的版本和构建号，运行 `xcodegen generate` 并提交对应发布说明。工作流完成原有回归测试、通用 Ad-Hoc 构建、双架构打包、EdDSA 验证、草稿上传及远端 SHA-256 核验后才公开 Release。标签绑定实际构建的源代码提交，不跟随随后移动的 main。

关闭 `publish` 可演练构建；只上传两个 ZIP 与 appcast.xml 作为工作流附件，不创建 Release。公开仓库的 Actions 附件不是私有保险箱，不能包含私钥、密码、本地卡片或凭据。工作流失败可能保留草稿；不自动覆盖既有发布，不把开始运行视为发布成功。

本地备用打包：

```bash
./build.sh
bash prepare-update.sh "$PWD/dist/卡包.app"
```

本地新钥匙串账户为 `com.applist.cardwallet.mac.public-20260918`。使用 Sparkle `generate_keys --account <该账户> -f <私钥文件>` 导入备份；不要在聊天、日志、源码或 Release 中复制私钥。也可在私有终端环境中设置 `SPARKLE_PRIVATE_KEY`，脚本通过标准输入传给签名工具。

首次下载仍可能触发 Gatekeeper；按系统提供的允许打开流程操作，不要关闭系统全局安全检查。正式发布验证与真机更新验证是不同环节，使用备份或测试数据检查更新、重启和数据保留。

## 调试提示（本地功能）

- 构建失败时先查看 `build/xcodebuild-archive.log`。
- WebDAV 同步异常优先检查 `Domain/WebDAVBridgeService.swift`、`Domain/WebDAVClient.swift` 和同步密钥。
- 本地读写异常优先检查 `Domain/LocalStorageManager.swift`、`Domain/CryptoManager.swift` 和 Application Support 下的 `CardWallet/cards.json`。该目录名与现有存储实现一致，本次界面改造不迁移数据。
- 本地凭证文件为 `CardWallet/security_credentials.enc`，随机密钥文件为同目录的 `security_credentials.key`。手工备份凭证时必须同时保留两者，并将备份视为敏感数据；它们不会上传至 WebDAV。本地加密不能抵御已能读取当前用户全部文件的进程。

## 维护注意

- `CreditCardMac.xcodeproj` 由 XcodeGen 生成，结构调整优先修改 `project.yml`。
- 固定使用 Ad-Hoc 临时签名，不切换到开发团队签名或公证。
- 不要把 WebDAV 自动快照协议降级到旧导入导出方案。
- Web、Android、macOS 三端共用 SyncV4 数据语义，字段变更需要同时检查三端。
