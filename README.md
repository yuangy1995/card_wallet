# 卡包

同一个卡包应用的 Web、macOS、Android 和 iOS 客户端。四端统一在本仓库维护，分别构建、调试和发布。

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

## 协作约定

- 日常开发使用本仓库的 `main`，功能分支使用 `codex/` 前缀。四端相关变更可以在同一个分支和 PR 中提交。
- 只修改任务涉及的客户端；数据字段、加密和同步协议变更需要核对其他客户端的兼容性。
- 保留现有测试；涉及界面文案时同步维护该端已有的国际化资源。
- 不修改各端现有应用标识、存储位置、签名身份或版本号来适应目录合并。
- 各端独立发布，不要求统一版本号；新增发布标签建议使用 `web/v…`、`macos/v…`、`android/v…`、`ios/v…`。

## 迁移与安全

本仓库为私有仓库。原 Android 历史中包含发布签名文件和明文签名配置，本次为保留历史和应用升级身份而原样导入；私有仓库不会消除旧公开仓库中的既有暴露。未经单独安全处理，不要将本仓库公开，也不要新增签名材料或凭证到版本控制。

四个旧本地项目已按用户要求移到废纸篓，四个旧 GitHub 仓库也已删除；原始代码历史保存在本仓库中，迁移前的本地 Git 备份继续保留。日常开发只使用本仓库。迁移来源、历史查询方式和验证情况见 [迁移记录](docs/migration-2026-09-08.md)。
