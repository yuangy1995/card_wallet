# 卡包 Android 端

Kotlin + Jetpack Compose 的原生 Android 卡包客户端，用于本地管理信用卡和储蓄卡，并通过 WebDAV SyncV4 与 Web、macOS 端同步。

仓库总览见根目录 `README.md`；Android 在线更新与发布步骤见 [更新发布说明](UPDATE_RELEASES.md)。过期设计说明不再作为实现依据，实际行为以当前代码和 SyncV4 数据语义为准。

正式发布使用当前公开仓库 `yuangy1995/card_wallet` 的 **Publish Android release** 工作流：手动触发后自动测试、打包、签名校验并发布到本仓库。签名来自现有 GitHub Secrets，发布使用临时 `GITHUB_TOKEN`，不使用独立产物仓库或 `RELEASES_TOKEN`；Android 不抢占 Mac 使用的 Latest 更新入口。

## 当前架构

- 平台：Android 原生应用，`minSdk 23`，`targetSdk 36`，Java/Kotlin 17。
- UI：Jetpack Compose + Material 3。
- 本地数据：SQLite 数据库 `card_wallet.db`，包含 `cards`、`sync_records` 和加密数据块表 `encrypted_payload_chunks`。保留已有文件名和版本；`DatabaseHelper` 显式实现 `Closeable`，保证 Android API 23–28 的 `use {}` 也能安全关闭数据库。
- 偏好配置：主题、工具菜单、WebDAV 配置、同步状态等使用 `SharedPreferences`。
- 云同步：`SyncCoordinator` 负责本地 SQLite 与 WebDAV SyncV4 快照合并。
- NFC：只在快速验卡或添加卡片的 NFC 页面开启前台读卡会话，离开页面后关闭。
- 相机扫描：CameraX + ML Kit 文本识别，用于卡号和有效期辅助录入。
- 存储管理：支持清理缓存、代码缓存、外部缓存和无对应卡片的旧扫描残留；卡片资料、图片、同步账本和配置不属于一键清理范围。

## 关键数据规则

- `cardCategory` 表示卡类别，取值为 `credit` 或 `debit`；历史数据缺失时按 `credit` 处理。
- `type` 是历史字段名，当前实际表示币种代码；空币种保持为空。
- `bank` 是发卡行显示名；编辑同一银行名称时，需要同步影响同银行下的多张卡片。
- `cardImages` 保存卡片图片资产，会写入本地数据库并参与 SyncV4 同步。
- `lastModifyTime` 是跨端合并的重要字段，保存本地修改时必须更新。

## 常用命令

```bash
# Debug 构建
./gradlew :app:assembleDebug

# Release 构建并复制到 releases 目录
./build_release.sh

# 单元测试
./gradlew test

# 准备 GitHub Releases 在线更新包（不自动上传）
bash prepare-update.sh 1.1.0 2
```

Release 成功后，脚本会输出：

- `releases/CardWallet-Release.apk`
- `releases/CardWallet-Release-<时间戳>.apk`

安装或转发给手机时，优先使用带时间戳的 APK，避免聊天工具或文件管理器缓存同名安装包。

## 调试提示

- 设备已开启无线调试时，可通过 `adb devices` 确认连接状态。
- 相机扫描闪退优先查看 `adb logcat` 中的 `AndroidRuntime`、CameraX、ML Kit 相关堆栈。
- NFC 行为优先检查 `MainActivity` 的前台调度启停和 `NfcScannerManager` 的 reader session 计数。
- 同步异常优先检查 `SyncCoordinator`、`WebDAVClient`、`sync_records` 表和 WebDAV 自动快照文件。

## 维护注意

- 不要在非 NFC 功能页面长期启用 NFC 前台调度，避免误读卡片、额外耗电和发热。
- 不要把必要数据加入一键清理范围；必要数据包括卡片、卡片图片、同步账本、WebDAV 配置、安全锁和主题设置。
- R8、资源压缩、locale 过滤已经用于压缩安装包体积，新增依赖前需要确认 APK 体积影响。
- Web、Android、macOS 三端共用 SyncV4 数据语义，字段变更需要同时检查三端。

## 解锁与本地卡片加载

启用安全锁后，锁定会清除内存卡片并取消本次本地加载。解锁时先在后台读取本地 SQLite；读取完成前显示载入状态，读取失败提供重试且保留原数据库，不显示“空卡包”。只有成功读取到零张卡片才显示新增入口。

本地卡片先交给界面，同步历史、凭证及云同步随后加载；历史或凭证损坏不会隐藏已成功读取的卡片。重复初始化共用一次加载，旧会话的结果不会在重新锁定后写回。每个数据库操作复用一个不可导出的 AndroidKeyStore 密钥句柄，仍逐块执行 AES-GCM 验证，不缓存明文、不改变数据库格式或发布签名。

回归测试：`LocalCardLoaderTest` 覆盖慢读取、15 秒附属任务、重复加载、失败重试、空库及锁定竞态；`LocalCardsLoadingScreenTest` 覆盖加载与重试界面；`LocalVaultInstrumentedTest` 在 AndroidKeyStore 上验证句柄复用、撤销及取消读取后数据完整性。实际解锁耗时仍需在带有真实图片的设备上测量。

## PIN 校验升级与回归

数字 PIN 校验记录使用带版本的 PBKDF2-HMAC-SHA256、600000 次迭代及独立随机盐；卡片数据库继续使用原 Android Keystore 密钥，不将 PIN 变成卡片加密密钥。正确输入原 PIN 后自动原子升级，失败保留旧验证能力；只用生物识别时延后至下次 PIN 验证升级。派生与持久化在后台执行，锁定/离开页面会拒绝旧结果，错误次数和冷却机制保留。无需重设 PIN、卸载或删除卡片。

迁移单元测试覆盖 Android API 23/34，设备测试覆盖真实密钥与 PIN 校验。`PinStorageRoundTripTest` 使用四端共享合成账本，确认升级前后数据库字节、删除记录、图片未来字段和同步偏好保持不变。参数并不表示已在维护者手机上取得固定耗时保证；设备与性能验收见 [四阶段执行记录](../../docs/implementation-stages-20260919.md)。
