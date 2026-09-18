# Android 在线更新与公开发布

源码与 APK 统一发布在 `yuangy1995/card_wallet`。客户端分页读取本仓库 Releases，按 Android versionCode 筛选正式版本，忽略 Mac、草稿和预发布；不依赖 Latest。下载地址仅接受本仓库 HTTPS 地址，并验证 GitHub SHA-256、包名、版本和安装签名。

## 本次迁移

2026-09-18 移除已暴露的旧签名，改用仓库外生成的新密钥。包名 `com.applist.cardwallet` 和数据格式不变，但新签名不能覆盖旧签名安装。先导出并确认备份，再卸载旧版、安装新版并恢复；后续同一新签名版本可正常覆盖更新。不要重新使用旧密钥或建立旧签名兼容链。

## 发布配置

签名 Secrets 为 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`、`ANDROID_SIGNING_CERT_SHA256`。公开证书指纹记录在 `signing-certificate.sha256`。配置方法见 [签名与公开发布](../../docs/signing-security.md)。

工作流仅从 `main` 手动执行。发布使用 GitHub 临时 `GITHUB_TOKEN` 和 job 的 `contents: write`，不需要跨仓库 PAT。签名文件只恢复到 runner 临时目录，完成构建后始终清理；正式构建不使用 Gradle 配置缓存、守护进程或发布缓存，缺失签名就停止。

```bash
gh workflow run android-release.yml --repo yuangy1995/card_wallet --ref main \
  -f version=1.3.0 -f version_code=5 -f publish=true
```

准备版本为 1.3.0（5）。每次后续发布递增 `app/build.gradle.kts` 中默认版本和版本编号，准备 `release-notes/<版本>.md` 并提交到 main。标签为 `android-v<版本>-<编号>`，附件为 `CardWallet-Android-<编号>.apk`。创建标签时绑定实际构建提交。

流程包含回归测试、正式签名构建、独立证书校验、草稿上传、远端文件大小和 SHA-256 核验以及公开下载校验。Android 发布始终不更改 Latest，防止影响 Mac 的固定更新入口。不要将触发成功当作发布完成。

关闭 `publish` 可演练；APK 仅作为工作流附件保留 14 天。公开仓库的附件不是私有存储，不上传私钥、凭据或真实卡片数据。上传失败可能留下草稿，不自动覆盖已有 Release。

本地备用打包需要相同的签名环境变量（以 `ANDROID_KEYSTORE_PATH` 指向绝对路径替代 Base64）：

```bash
bash prepare-update.sh 1.3.0 5
```

只有新仓库的 Android 与 Mac 正式发布均验证通过、维护者已安装新版后，才删除旧产物仓库。当前源码清理不代表 Git 历史和其他分支已清除。

## 设计与验证

Android 保持原生 Compose / Material 3；暖白和石墨黑双主题，青绿色强调色，16/24dp 圆角、明确的标题层级、原生触控反馈。首页常驻搜索，卡片仅显示尾号；卡片模式和列表模式、分组排序、批量操作、工具自定义及原有功能入口保持。

详情、编辑和设置使用统一可展开分组；切换淡入 180ms，分组展开 220ms。Compose 原生动画遵循系统动画时长；没有新增常驻装饰动画，静止同步图标不创建循环动画。卡包使用 LazyColumn，列表位置与筛选状态保留；下载与验证在 IO 线程，进度仅按整数百分比更新。

编译通过不代表真机性能已验证；正式发布前需要用低端真机检查长列表滚动、字号放大、NFC/相机、锁屏、云同步及覆盖安装后的数据保留。

### 本次验证（2026-09-11）

- 19 项本地测试通过：4 项原有同步测试、8 项发布版本筛选测试、7 项 Compose 界面测试。
- 界面测试覆盖浅色／深色、横屏、大字号、卡号遮罩、搜索、卡片打开、切换页面后状态保留、工具／设置入口和自动更新偏好持久化。
- `bash prepare-update.sh 1.1.0 2` 完整执行通过；生成约 3.4 MB 的正式签名 APK，包名为 `com.applist.cardwallet`，版本 `1.1.0 (2)`；APK v1/v2 签名验证通过。
- 全量 Lint 未通过：主要为既有日期 API 在 Android 6/7 上的兼容问题、Android 6 网络回调及通知权限检查问题。未通过屏蔽规则隐藏问题，也未扩展修改同步核心；不要据此宣称旧系统兼容已经验证。
- 本地没有可用真机或完整模拟器镜像。截图由原生 Compose 的本地 Android 渲染测试生成，使用虚构卡片；不等于真机帧率、硬件扫描或线上更新链路实测。
- 尚未向 GitHub 发布安装包；用户确认体验后再发布。旧版须先手动覆盖安装此版本，后续发布更大的 Android 版本编号才能验证在线升级。
