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
- 原四个本地目录保留；另有本地 Git bundle 备份，未上传到新仓库。
- 不导入本地依赖、缓存、构建产物及工具内部引用。项目原有测试完整保留。

## GitHub 范围

- 新仓库使用私有可见性，默认分支为 `main`。
- 旧仓库不删除、不归档、不修改可见性；原 Issues、PR、Releases 仍留在原仓库。
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
| iOS | Xcode 可读取工程和 scheme；工程、Info.plist、entitlements 语法检查通过；完整构建受本机缺失 iOS 模拟器运行环境阻塞 |

iOS 已分别尝试 scheme 模拟器构建、直接使用模拟器 SDK 和不签名设备 SDK 构建。当前 Xcode 未安装可用的 iOS Simulator runtime，目的地选择或资源编译报错（`No available simulator runtimes`）。没有为通过检查而删除资源、修改部署目标或变更应用代码；安装对应 Xcode 的 iOS 组件后可重新执行 `make ios-build`。

真机操作、真实 WebDAV 同步及正式签名发布不在本次验证范围。
