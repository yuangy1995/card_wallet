# CI 与正式发布

## 保留的四个工作流

| 工作流 | 用途与触发 |
| --- | --- |
| `platform-quality.yml` | PR、主线变更及手动检查；运行 Web 构建和浏览器回归、Android 测试/Lint/设备密钥测试、iOS/macOS 原生测试。PR 和手动运行同时提供独立包名的 Android 预览 APK。 |
| `signing-security.yml` | PR、主线推送及手动检查；阻止签名材料进入源码，并验证新证书、发布地址和标签安全逻辑。不会读取发布私钥。 |
| `android-release.yml` | 仅维护者从 main 手动发布 Android 正式版，或关闭 publish 演练。 |
| `macos-release.yml` | 仅维护者从 main 手动发布 Mac 正式版，或关闭 publish 演练。 |

日常提交只自动运行 Platform quality 和 Signing security；两个 Publish 工作流只在手动发布或演练时运行，不随普通提交发布。需要 Android 预览包时手动运行 Platform quality，无需另外建立测试包工作流。

`android-ui-integration.yml` 和 `web-quality.yml` 的重复检查合并进 Platform quality；Android 独立预览包和全部原有回归测试保留。`macos-brand-workbench.yml`、`wallet-feedback-build.yml` 只服务已结束的旧分支并会回写代码，已删除。

`release-completion-once.yml` 已在 Android 1.3.0（5）和 Mac 1.1.0（7）正式发布成功、附件及公开下载校验通过后删除。当前 `.github/workflows/` 只保留上表四个文件，不再保留一次性发布触发器。后续发布直接使用两个长期发布入口。

按维护者追加授权，已清理 27 个退役工作流的 121 次历史运行及其临时 Actions 附件，清理后复核退役运行剩余 0 次。四个长期工作流的历史、正式 Releases、安装包、appcast.xml、标签和 Secrets 均保留。一次性清理与代码恢复 job 在完成后移除，不留下额外工作流或 Actions 写权限。

## 发布提交固定

两端使用同一并发组串行发布。Android 不抢占 Latest，Mac 保持 Latest 和 appcast.xml 更新入口。

正式发布在编译前通过 `scripts/release-tag.py pin` 把版本标签固定到实际检出的 GITHUB_SHA。新标签只允许从尚未移动的 main 创建；同一任务重跑可复用相同 SHA 的标签，任何不同提交或不同类型的已有标签都拒绝覆盖。

上传使用 `gh release create --verify-tag`，不再把旧提交作为 `--target` 交给 Release API 临时创建标签。上传前和公开前再次验证远端标签仍与构建源码一致。即使之后 main 前进，也不会把安装包错误关联到未测试的新提交。

这避免临时工作流删除或其他主线更新后，向无引用旧提交创建 Release 所触发的 Workflows 写权限要求；发布仍只需仓库自带 GITHUB_TOKEN 的 Contents 写权限。不增加长期 PAT，不把签名 Secrets 输出到日志，不关闭测试或签名验证。

标签固定后构建失败，可重跑同一源码任务。需要修改源码时应递增版本/构建号；不要自动移动已固定标签。只有明确确认标签未对应任何发布并获得维护者批准后，才可单独清理失败预留的标签。publish=false 不创建标签或发布。

临时触发器不得在发布任务完成前清理。只有两端任务成功、附件校验及公开下载验证通过后才视为完成；发出工作流请求不等于发布成功。

参考：[GitHub 的 Release 工作流权限规则](https://github.blog/changelog/2023-11-02-github-actions-enforcing-workflow-scope-when-creating-a-release/)、[Release API](https://docs.github.com/en/rest/releases/releases)、[gh release create](https://cli.github.com/manual/gh_release_create)。
