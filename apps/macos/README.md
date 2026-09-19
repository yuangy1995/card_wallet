# 卡包 macOS 端

SwiftUI 的 macOS 原生卡包客户端，用于本地管理信用卡和储蓄卡，并通过 WebDAV SyncV4 与 Web、Android 端同步。

macOS 维护以当前代码、本文件和根目录 [AGENTS.md](../../AGENTS.md) 为准。后续复审与修复计划见 [四端复审](../../docs/code-review-20260919.md)。

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
- 凭证存储：`KeychainManager` 只保留历史调用接口，正常读写使用 `LocalCredentialStore` 的本地 AES-GCM 加密文件，不以系统钥匙串作为存储后端；每份凭证库使用独立随机密钥，凭证文件和密钥仅当前用户可读写。部分开关和间隔配置使用 `UserDefaults`。
- 历史版本兼容：已有的一次性旧钥匙串凭证读取仅用于迁入本地，完整写入本地后才标记迁移成功。可能需要系统授权；拒绝后不重复自动申请，可在锁屏主动重试。旧钥匙串记录不会被删除，迁移成功后不再访问。这不是恢复钥匙串存储的要求，不扩大此兼容路径；旧版本的本地加密文件也可读取。
- 云同步：`SyncCoordinator` 只协调本地账本和 WebDAV bridge；已移除 Apple 私有云同步及其权限。旧账本中的额外字段会被忽略，卡片和 WebDAV 状态仍可读取。
- WebDAV：`WebDAVBridgeService` 使用 SyncV4 自动快照，文件名包含 `[SyncV4][Mac][自]`。
- 性能：连续本地修改在 0.8 秒内合并触发上传，同步快照在后台准备和加密；系统通知刷新延迟 0.4 秒合并、排程在后台计算；卡片分组排序后台执行并丢弃过时结果，保留已有预计算缓存。锁定时取消尚未触发的上传和通知刷新。

## 本地安全存储：已确认的架构约定

维护者于 2026-09-19 明确：macOS 默认并持续使用现有本地加密存储，不使用系统钥匙串（Keychain）作为正常存储后端。这是确定的产品/架构选择，不是临时过渡方案，也不是待修复或延期整改项。后续审查、修复计划和自动化任务不得仅因密钥与密文同目录而再次安排 Keychain 或密码派生保险库迁移；只有维护者另行明确改变决定时才重新设计。

卡片、同步账本等业务数据沿用 `LocalDataCipher` 和 Application Support 下的 `CardWallet` 目录，数据密钥为 `local_data.key`。本机凭证沿用 `LocalCredentialStore` 的 `security_credentials.enc` 与 `security_credentials.key`。保留现有加密、随机密钥、目录/文件权限、原子写入及读写失败保护，不新增钥匙串写入，不迁移数据目录，不删除或重新生成已有数据密钥。

`KeychainManager` 的名称是历史兼容接口，不能据此认定当前还在使用钥匙串保存凭证。已有的旧版本单向迁入兼容不在本次文档更新中删除，也不扩展为日常钥匙串读写。锁定后释放内存、拒绝旧会话回调和后台读盘优化可以独立进行，不改变本地磁盘加密方案。

安全边界仍如实保留：若主体已经能同时读取密钥文件与密文，现有方案不能阻止其离线解密；维护者接受这一边界，不宣称风险被技术消除。真实明文泄漏、文件损坏或错误覆盖等实现缺陷仍应修复。运行时数据和密钥不得进入 Git、公开 CI 附件或 Release；备份必须视为敏感数据。

应用本地数据密钥与 Sparkle 发布签名私钥是不同用途。发布继续使用现有 GitHub Secrets，本约定不要求更改签名系列、iOS 的既有存储或 Android Keystore。复审剩余任务不包含 macOS 存储后端替换。

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

本地备用签名使用与 CI 相同的 `SPARKLE_PRIVATE_KEY` 输入：从仓库外私有备份在当前私有终端环境中提供，脚本通过标准输入交给 Sparkle，完成后撤销该环境变量。不要在聊天、日志、源码或 Release 中复制私钥。不再把创建/恢复本地钥匙串账户列为维护要求。现有脚本仍保留未提供环境变量时的旧钥匙串后备分支；本次文档更新不删除该兼容代码，它不是应用本地卡片或凭证的存储后端。

首次下载仍可能触发 Gatekeeper；按系统提供的允许打开流程操作，不要关闭系统全局安全检查。正式发布验证与真机更新验证是不同环节，使用备份或测试数据检查更新、重启和数据保留。

## 调试提示（本地功能）

- 构建失败时先查看 `build/xcodebuild-archive.log`。
- WebDAV 同步异常优先检查 `Domain/WebDAVBridgeService.swift`、`Domain/WebDAVClient.swift` 和同步密钥。
- 本地读写异常优先检查 `Domain/LocalStorageManager.swift`、`Domain/CryptoManager.swift` 和 Application Support 下的 `CardWallet/cards.json`。该目录名与现有存储实现一致，本次界面改造不迁移数据。
- 本地凭证文件为 `CardWallet/security_credentials.enc`，随机密钥文件为同目录的 `security_credentials.key`。手工备份凭证时必须同时保留两者，并将备份视为敏感数据；它们不会上传至 WebDAV。本地加密不能抵御已能读取当前用户全部文件的进程。

## 维护注意

- `CreditCardMac.xcodeproj` 由 XcodeGen 生成，结构调整优先修改 `project.yml`。
- 固定使用 Ad-Hoc 临时签名，不切换到开发团队签名或公证。
- 本地安全存储遵守本文件的已确认架构约定：保留本地加密文件，不改成钥匙串，不将该设计重新列入复审修复任务。
- 不要把 WebDAV 自动快照协议降级到旧导入导出方案。
- Web、Android、macOS 三端共用 SyncV4 数据语义，字段变更需要同时检查三端。

## 锁定与内存会话

锁定会清空当前窗口的卡片、详情/编辑请求、搜索与银行选择、提醒队列，并释放同步协调器的卡片账本、同步历史和附件缩略图缓存。冷启动停留在锁屏时不读取卡片或同步历史；解锁后重新读取原有本地加密文件，成功后才恢复同步。读取失败保留原文件并显示重试入口，不把锁定产生的空列表保存或同步为删除。

在途同步、图片解码和通知刷新会取消；延迟回调通过会话标记及可撤销数据容器拒绝旧结果，不能在再次解锁后写回旧会话。已排程的通用系统提醒仍保留。这里只释放应用可控的明文引用，不承诺 Swift、图像/加密库或系统分配器中的临时副本已逐字节擦除。磁盘格式、凭证存放模式、发布签名和已有数据均不变。

回归覆盖冷启动锁定不读盘、锁定不落盘空数据、含删除记录/待上传状态的解锁恢复、旧回调拒绝、读取失败重试、历史清理与恢复，以及缩略图缓存和在途解码撤销。真机可在打开详情、照片或同步期间锁定，再离线解锁确认本机数据恢复；不需要卸载或清空数据。
