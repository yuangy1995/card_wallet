# 银行卡管理 Android 端

Kotlin + Jetpack Compose 的原生 Android 客户端，用于本地管理信用卡和储蓄卡，并通过 WebDAV SyncV4 与 Web、macOS 端同步。

本仓库只保留根目录 `README.md` 作为维护入口。过期设计说明不再作为实现依据，实际行为以当前代码和三端 SyncV4 数据语义为准。

## 当前架构

- 平台：Android 原生应用，`minSdk 23`，`targetSdk 36`，Java/Kotlin 17。
- UI：Jetpack Compose + Material 3。
- 本地数据：SQLite 数据库 `credit_card.db`，包含 `cards` 和 `sync_records` 两张核心表。
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
```

Release 成功后，脚本会输出：

- `releases/CreditCard-Release.apk`
- `releases/CreditCard-Release-<时间戳>.apk`

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
