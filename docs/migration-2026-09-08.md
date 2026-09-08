# 四端仓库合并记录

## 来源

2026-09-08，先对四个原仓库执行 `git fetch origin --tags`，再执行 `git merge --ff-only origin/main`。四端本地与远端主分支均一致，无未提交改动，无合并冲突。

GitHub 当前账户为 `yuangy1995`；旧 remote 中的 `qwertyuiop1995` 地址仍能重定向。

| 客户端 | 原仓库 | 导入的 main 提交 | 新目录 |
| --- | --- | --- | --- |
| Web | `yuangy1995/credit_card_web` | `505de616025cf5515eaa5e4ea6c1ef0876bb0d8a` | `apps/web` |
| macOS | `yuangy1995/credit_card_mac` | `02eb46d758e9d281bc1955f72816974660f3f2be` | `apps/macos` |
| Android | `yuangy1995/credit_card_android` | `e71444ef77cc0d19d4c483fddaf59ff3c939c90a` | `apps/android` |
| iOS | `yuangy1995/credit_card_iOS` | `f59c32dc04dd9d079a98eeb04277c5f456ac64a8` | `apps/ios` |

## 历史保留

- 各端通过独立合并提交导入子目录，保留原提交 ID、作者、时间和父子关系，不压缩或重写原历史。
- 新目录中的 Git 树与来源主分支进行完整比较，包括文件内容和可执行权限。
- 原分支保存在 `codex/archive/<客户端>/<原分支名>`，供查询迁移前的历史，不用于日常开发。macOS 原有的备份分支也一并保留。
- 导入时四个仓库均没有标签，也没有额外远端开发分支。
- 迁移前的提交使用旧目录布局。查询 Web 旧历史的示例：`git log codex/archive/web/main -- src`；当前历史使用 `git log -- apps/web`。
- 迁移阶段保留原四个本地目录；后续清理状态见下文。另有本地 Git bundle 备份，未上传到新仓库。
- 不导入本地依赖、缓存、构建产物及工具内部引用。项目原有测试完整保留。

## GitHub 范围

- 新仓库使用私有可见性，默认分支为 `main`。
- 迁移阶段未删除、归档或修改旧仓库可见性；后续按用户新授权执行清理，状态见下文。
- 本次不迁移平台设置、Secrets、发布附件或部署服务；各客户端源码中未发现已跟踪的 `.github` 工作流。
- 原 Android 仓库为公开仓库，主分支已跟踪发布签名文件，构建配置包含明文签名口令。为保留提交历史及升级身份，本次未更换签名或清理历史；新仓库私有不等于已修复原有安全风险。

## 验证

| 项目 | 结果 |
| --- | --- |
| 文件与权限 | 四端共 367 个已跟踪文件；四个子目录 Git tree 与来源 main 完全一致 |
| 历史 | 四个来源 main 都是总仓库 main 的祖先；`git fsck --full` 通过 |
| Web | 锁定依赖安装成功；10 个测试文件、54 项测试通过；生产构建通过 |
| macOS | Debug 构建通过；Release 测试构建成功，61 项测试全部通过 |
| Android | Debug APK 构建通过；3 个测试类、4 项单元测试全部通过 |
| iOS | 工程、Info.plist、entitlements 检查通过；安装运行环境后 `make ios-build` 通过；App 已安装到专用 iPhone 17 Pro 模拟器并成功打开卡包首页 |
| GitHub | 私有仓库 `yuangy1995/credit_card`，默认分支 `main`；总项目及 5 个历史保留分支已推送，远端分支提交与本地核对一致 |

iOS 首次构建因本机没有模拟器运行环境而失败。经用户授权，已下载并安装 iOS 26.5（23F73，arm64），新建并启动“卡包调试 - iPhone 17 Pro”。在空白模拟器中安装、启动卡包，并确认显示“还没有银行卡”的首页；未导入真实卡片或配置真实云同步账户。原有的其他模拟器保留。

验证机器为 Xcode 26.6（17F113）。其 `iphoneos26.5` SDK 实际版本为 26.5.1（23F81a），默认运行环境映射不能匹配已下载的 23F73。通过 Xcode 自带命令为这个特定 SDK build 设置本地映射后，工程的模拟器目的地和资源编译恢复正常：

```bash
xcrun simctl runtime match set iphoneos26.5 23F73 --sdkBuild 23F81a
```

这只是验证机器的配置，不修改项目文件，也不要求其他机器照搬。以后若为该 SDK 安装了默认匹配的运行环境，可恢复默认映射：

```bash
xcrun simctl runtime match set iphoneos26.5 --default --sdkBuild 23F81a
```

本次没有为通过构建而删除资源、修改部署目标或变更任何客户端的应用代码。

真机操作、真实 WebDAV 同步及正式签名发布不在本次验证范围。

## 旧项目清理（2026-09-08）

用户随后明确要求删除四个旧本地项目及四个旧 GitHub 仓库。删除前再次拉取并核对：旧四端没有新增提交或未提交改动，没有标签、额外远端分支、开放 Issues/PR 或 Releases；来源提交在新 GitHub 仓库完整可达，四份本地 Git bundle 验证通过。

- 四个旧本地目录已使用系统废纸篓功能移走，未永久擦除，可从废纸篓恢复。新总项目及迁移备份保持不动。
- 待删除的旧 GitHub 仓库为 `yuangy1995/credit_card_web`、`yuangy1995/credit_card_mac`、`yuangy1995/credit_card_android`、`yuangy1995/credit_card_iOS`。
- 当前 GitHub CLI 凭证缺少 `delete_repo` 权限，已发起授权流程，等待用户完成；四个远端旧仓库尚未删除。
