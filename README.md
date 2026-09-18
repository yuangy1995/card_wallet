# 卡包 · Card Wallet

同一个卡包应用的 Web、macOS、Android 和 iOS 客户端。四端统一在本仓库维护，分别构建、调试和发布。

英文项目名为 **Card Wallet**，仓库及本地总目录使用 `card_wallet`。目前管理信用卡和储蓄卡，命名不限定卡片类型，便于以后扩展。

GitHub 公开仓库：[yuangy1995/card_wallet](https://github.com/yuangy1995/card_wallet)。

## 项目目录

| 客户端 | 目录 | 开发工具 |
| --- | --- | --- |
| Web | `apps/web` | Vue 3、Vite、pnpm |
| macOS | `apps/macos` | Swift、Xcode、XcodeGen |
| Android | `apps/android` | Kotlin、Compose、Android Studio、Gradle |
| iOS | `apps/ios` | Swift、Xcode、XcodeGen |

在编辑器中打开仓库根目录即可同时查看四端代码。Xcode 分别打开 `apps/macos/CreditCardMac.xcodeproj` 和 `apps/ios/CreditCardIOS.xcodeproj`；Android Studio 打开 `apps/android`。

## 安装和调试

Web 首次运行需要 Node.js 和 pnpm，在仓库根目录执行：

```bash
pnpm --dir apps/web install --frozen-lockfile
make web-dev
```

Android 需要 JDK 17 和 Android SDK。通过 Android Studio 配置 SDK，或设置 `ANDROID_HOME`；机器专用配置放在不提交的 `apps/android/local.properties` 中。macOS 和 iOS 需要完整 Xcode；调整 `project.yml` 后，在对应客户端目录运行 `xcodegen generate`。

根目录提供常用入口，执行 `make help` 查看：

```bash
make web-build
make web-test
make macos-build
make macos-test
make ios-build
make android-build
make android-test
```

这些入口用于开发验证：Apple 客户端构建不进行发布签名，iOS 构建面向模拟器，Android 构建 Debug 安装包。真机运行和正式发布仍使用各端原有签名配置与工具。

各端已有说明见 [Web](apps/web/README.md)、[macOS](apps/macos/README.md)、[Android](apps/android/README.md)。运行原有打包脚本时，先进入对应客户端目录。

Android 和 macOS 直接通过本仓库 Releases 发布及检查更新，不再依赖独立产物仓库。发布步骤见 [签名与公开发布](docs/signing-security.md) 和 [Android 更新发布说明](apps/android/UPDATE_RELEASES.md)。

## CI

维护四个工作流：Platform quality 负责四端构建、回归和预览包，Signing security 负责签名安全，两端 Publish release 仅从 main 手动发布。重复检查已合并，旧分支的一次性构建已移除；详情及标签固定规则见 [CI 与正式发布](docs/ci-and-releases.md)。Actions 左栏的历史条目不代表仍存在可执行的工作流文件。

## 协作约定

- 日常开发使用本仓库的 `main`，功能分支使用 `codex/` 前缀。四端相关变更可以在同一个分支和 PR 中提交。
- 只修改任务涉及的客户端；数据字段、加密和同步协议变更需要核对其他客户端的兼容性。
- 保留现有测试；涉及界面文案时同步维护该端已有的国际化资源。
- 不修改各端现有应用标识、存储位置、签名身份或版本号来适应目录合并。
- 各端独立发布，不要求统一版本号；Android 标签使用 `android-v<版本>-<构建号>`，macOS 使用 `mac-v<版本>-<构建号>`。

## 迁移与安全

源码保持公开；发布私钥、密码和本地配置不得提交。Android 已移除当前代码中的旧签名材料；正式构建只接受 CI 注入的新签名，macOS 只提交更新公钥。密钥恢复和发布流程见 [签名与公开发布](docs/signing-security.md)。

已确认泄漏的签名文件和密码已从主线可达历史清理，旧分支已整合；范围与 GitHub PR 缓存的后续处理见 [历史清理记录](docs/signing-history-cleanup-2026-09-18.md)。请重新克隆，不要合并或推送旧克隆中的历史，也不要把已泄漏的旧签名重新放入 Secrets。安全迁移不改变应用标识、卡片数据格式或本地存储位置。迁移前先备份数据，Android 旧签名安装需重装，macOS 需手动替换一次应用。
