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

## GitHub Releases 自动更新

- 源码仓库保持私有；公开仓库 `yuangy1995/card-wallet-releases` 仅用于发布经过检查的安装包和更新清单，禁止推送源码、历史记录或签名材料。
- 应用通过「设置 → 软件更新」或应用菜单「检查更新…」手动检查，两处共用同一个更新器；设置页同时显示当前版本。默认由 Sparkle 定期检查，发现新版后提示用户确认安装，不默认静默安装。
- 更新地址固定为 `https://github.com/yuangy1995/card-wallet-releases/releases/latest/download/appcast.xml`。首个正式 Release 发布前该地址不可用，检查更新会报连接失败，而不是显示已是最新版。
- 保留应用标识和本地数据位置。Xcode 默认构建保留原有沙盒；`build.sh` 保持旧临时签名产物的非沙盒运行方式，使用单独的 `CreditCardMacAdHoc.entitlements`，避免新启用沙盒后改读容器内的数据。单元测试宿主不创建更新器或请求更新服务。
- 每次发布都必须递增 `project.yml` 中的 `CURRENT_PROJECT_VERSION`，并按需修改 `MARKETING_VERSION`。Sparkle 用构建号判断新旧，不以 GitHub 标签排序判断。

### 首次发布准备

1. 固定使用 Ad-Hoc 临时签名，不使用 Developer ID 或公证。`build.sh` 在 Xcode 归档阶段完成临时签名，保持旧打包脚本产物的非沙盒运行方式，即使设置了 `DEVELOPMENT_TEAM` 环境变量也不切换签名方式。对外发布统一使用该脚本，不要混用 Xcode 默认沙盒构建。
2. 为允许临时签名的应用加载 Sparkle，保留 Hardened Runtime 并关闭库验证（`disable-library-validation`）。这不等于获得 Apple 信任：首次从 GitHub 下载后仍可能被 Gatekeeper 拦截，用户需将应用移入 Applications，并按系统提示在「隐私与安全性」中确认打开。不应要求用户关闭系统全局安全检查。
3. 2026-09-14 按维护者要求重新开始正式公开发布：当前版本为 1.0.0（构建号 4），已更换 Sparkle 更新签名密钥。当前钥匙串账户为 `com.applist.cardwallet.mac.public`，与早期版本使用的账户分开，未修改应用标识。私钥保存在创建它的 Mac 登录钥匙串和私有源码仓库的 `SPARKLE_PRIVATE_KEY` Secret 中，代码仓库只保存公钥。早期版本必须手动下载安装本次正式版；后续版本必须沿用本次新密钥。请通过安全渠道备份，不要把私钥、GitHub 令牌或 Apple 凭证写进应用或提交仓库。

### GitHub Actions 打包并发布（推荐）

私有源码仓库的 `Publish macOS release` 工作流（`.github/workflows/macos-release.yml`）从 `main` 手动触发，在 GitHub 的 macOS 执行器上测试、打包和签名，再发布到 `yuangy1995/card-wallet-releases`。不会向公开仓库推送源码、Git 历史或签名材料，也不会因普通提交或 PR 自动发布。

#### 一次性配置

在**私有源码仓库 `yuangy1995/card_wallet`** 的 Settings → Secrets and variables → Actions 中添加：

| Secret | 内容与权限 |
| --- | --- |
| `SPARKLE_PRIVATE_KEY` | 当前正式发布系列的 Sparkle 私钥文件内容，保持 `generate_keys -x` 导出的 Base64 文本原样，不再次编码。沿用 1.0.0（构建号 4）的新密钥，不使用早期版本密钥。 |
| `RELEASES_TOKEN` | Fine-grained personal access token，仅选择公开产物仓库 `yuangy1995/card-wallet-releases`，授予 Contents: Read and write；Metadata 只读。设置适当有效期，到期前更新。 |

GitHub 默认的 `GITHUB_TOKEN` 仅能访问工作流所在仓库，不能替代跨仓库发布令牌。不要把自己的全权限令牌用于发布，也不要将这两个值提交到仓库或贴入聊天、Issue、日志中。

在保存当前密钥的 Mac 上，可通过已登录的 `gh` 直接上传私钥 Secret；先进入 `apps/macos` 并确认 Sparkle 工具已解析，以下命令不打印私钥：

```bash
(
  set -e
  umask 077
  export_dir=$(mktemp -d)
  trap 'rm -f "$export_dir/sparkle.key"; rmdir "$export_dir"' EXIT
  build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
    --account com.applist.cardwallet.mac.public -x "$export_dir/sparkle.key"
  gh secret set SPARKLE_PRIVATE_KEY --repo yuangy1995/card_wallet < "$export_dir/sparkle.key"
)
```

`RELEASES_TOKEN` 可在 GitHub Secret 页面配置，或运行 `gh secret set RELEASES_TOKEN --repo yuangy1995/card_wallet` 后通过隐藏输入设置。上传密钥前先核对目标仓库；不要开启 shell 的 `set -x`。工作流签名时仅通过标准输入传递私钥，不导入执行器钥匙串、不保存私钥文件。

#### 每次发布

1. 修改 `project.yml` 的版本号和构建号，运行 `xcodegen generate`，并准备 `releases/<版本>.md`。将对应源码及发布说明提交到私有仓库 `main`。
2. 在私有仓库 Actions → **Publish macOS release** → Run workflow，选择 `main`，输入与工程一致的版本号，例如 `1.0.0`。配置了 `RELEASES_TOKEN` 时保留 `publish` 开关，自动上传正式发布；也可运行 `gh workflow run macos-release.yml --repo yuangy1995/card_wallet --ref main -f version=1.0.0 -f publish=true`。
3. 工作流检查密钥配置、版本、发布说明与已有版本，拒绝重复标签或不高于已发布 Mac 稳定版的构建号。随后运行回归测试，生成通用 Ad-Hoc 应用，拆分并签署 arm64 / x86_64 更新包。
4. 使用应用内置公钥独立验证两个 ZIP 的 EdDSA 签名，同时核对版本、构建号、下载地址、架构和文件大小。验证不通过就不上传。
5. 在公开产物仓库创建草稿，只上传两个 ZIP 与 `appcast.xml`，核对远端附件集合、大小和 SHA-256。通过后设为最新正式版，并检查 `latest/download/appcast.xml` 与本地产物一致。公开仓库自动附带的 Source code 链接只对应其自身内容，不对应私有源码仓库。

未配置跨仓库令牌时，关闭 `publish`（命令行使用 `-f publish=false`）。GitHub 仍完成全部测试、构建和签名，只将两个 ZIP 与 `appcast.xml` 存为私有工作流附件，保留 14 天，不自动公开。维护者可用 `gh run download <运行编号> --repo yuangy1995/card_wallet --name mac-v<版本>-<构建号> --dir <空目录>` 下载，核对签名后按下方发布步骤上传到公开仓库。此方式不需要把维护者的全权限登录令牌存入 CI。

本次重新首发同时更换密钥，因此早期 1.0.0（构建号 2）和 1.0.1（构建号 3）不能通过自动更新升级到当前版本，必须先手动安装。新 1.0.0（构建号 4）之后的版本保持新密钥、公钥、更新地址和应用标识不变，且递增构建号，即可继续自动升级。Ad-Hoc 和未公证状态保持不变。

上传或核验失败时可能留下草稿；工作流不自动覆盖、删除或重建同一标签。先检查失败步骤及草稿附件，再人工决定如何处理，不能直接替换已发布的签名包。旧 Release 保留。如新版有问题，可人工将上一 Mac 稳定版设为 Latest，恢复旧版下载及更新入口；这不会让已安装新版自动降级。若最终下载检查失败，Release 可能已经发布，应先查看远端状态，不能假定发布未发生。

### 本地生成发布附件（备用）

以下命令均在 `apps/macos` 目录执行：

```bash
xcodegen generate
xcodebuild -resolvePackageDependencies -project CreditCardMac.xcodeproj \
  -scheme CreditCardMac -clonedSourcePackagesDirPath build/SourcePackages
./build.sh
bash prepare-update.sh "$(pwd)/dist/卡包.app"
```

脚本检查应用标识、更新签名密钥和 Ad-Hoc 签名完整性，不检查公证。将通用归档中的应用及内嵌组件拆分成 arm64 和 x86_64 两份，逐层重新签名，生成 `dist/updates/mac-v<版本>-<构建号>/` 下的 `*-arm64.zip`、`*-x86_64.zip` 和带 EdDSA 更新包签名的 `appcast.xml`。清单中 Apple Silicon 专用条目排在前面，Intel 使用兼容回退条目；Sparkle 2.9 的硬件限制及同版本首次匹配规则保证 Apple Silicon 优先使用原生版本。两份清单先独立生成，再合并，避免生成器按版本号去重丢失其中一个架构。输出目录已存在时停止，避免覆盖待发布附件；不会自行上传或发布。Ad-Hoc 不需要固定证书，但更新验证使用的 EdDSA 密钥必须保持不变；私钥丢失后不能依赖 Apple 签名恢复更新信任，需要用户手动安装新版。

在公开仓库新建 Release，标签必须与脚本输出一致，同时上传该目录里的 ZIP 和 `appcast.xml`，填写面向用户的更新说明。先保存草稿并检查附件，再发布为最新正式版；不要只上传安装包，也不要将测试版设为最新正式版。每个正式版本都要带上更新清单，且发布后不要替换已签名的 ZIP。当前清单只保留本次完整更新包，适用于仍支持 macOS 14 的稳定通道；以后提高系统门槛时，需保留旧系统可用的更新条目。

首个含自动更新功能的版本需要用户手动安装一次。正式发布前，用两个构建号的 Ad-Hoc 签名应用在独立 macOS 测试账户中验证发现新版、下载安装、重启后版本与数据保留；不要拿真实卡包数据进行升级测试。

当前正式公开首发为 [1.0.0（构建号 4）](https://github.com/yuangy1995/card-wallet-releases/releases/tag/mac-v1.0.0-4)，包含原计划 1.0.2 的改进。旧 Mac 发布 `mac-v1.0.0-2` 和 `mac-v1.0.1-3` 在新包发布验证后移除，Android 发布保留。公开安装说明和版本说明的维护副本位于 `releases/`。

本次验证：64 项单元测试通过（含设置更新入口、更新地址、公钥格式及检查/安装默认行为）；Apple Silicon + Intel 通用 Ad-Hoc 归档和嵌套签名完整性检查通过；更新附件生成及 EdDSA 签名验证通过。仍需在独立测试账户中完成安装替换及重启的端到端升级验证。

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
