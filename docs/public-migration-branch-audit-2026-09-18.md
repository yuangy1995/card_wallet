# 公开发布迁移：分支核验记录

## 2026-09-18 已执行

公开发布源统一为 `yuangy1995/card_wallet`，保留 main 在 `16a627d` 引入的新 Android 证书指纹和 Sparkle 公钥，不另建第二套签名身份。并行迁移分支的重复发布实现以 main 中已固定公钥的实现为准；额外保留全仓扫描修复与回归门禁。应用标识、数据存储位置及 Ad-Hoc 签名约定不变。

运行 `35329536486` 在删除前重新获取远端引用，并逐一验证分支 SHA、`git merge-base --is-ancestor` 和精确 SHA 租约。下列三个分支已删除，提交仍可从 main 到达：

| 分支 | 删除前 SHA |
| --- | --- |
| `codex/four-platform-parity-20260918` | `1838e0475501f2acf8b186b60b9177f09201f5e7` |
| `codex/web-audit-platform-parity-20260918` | `ca0eb54dc5fd6ea976ee39d8b8549a040eadda9e` |
| `codex/web-security-performance-completion` | `430f9336240a98d1e95c69fc04a483b151fd1169` |

该运行仅输出 Secrets 是否缺失，不输出值。检查时 Android 五项签名 Secrets 均缺失；已有 `SPARKLE_PRIVATE_KEY` 只确认存在，不能由此认定它匹配新的公钥。检查与代码合并不等于完成密钥上传、历史清理或正式发布。

## 两个尚未合并的旧试验分支

| 分支 | SHA | 未进入 main 的提交数 |
| --- | --- | ---: |
| `codex/four-platform-parity-completion-20260918` | `e8b8333b778927d9206b2f7a5d2a93ec52cf6bec` | 9 |
| `codex/four-platform-parity-stages` | `6948ec4e68eb54a6bda743c697e1e47c3affbbb1` | 7 |

两者不是可以依据名称直接删除的已合并分支。`git cherry` 未把其独立提交判为已应用的等价补丁；其中同时含临时传输工作流、未完成的载荷、不同的四端实现和旧签名文件。

针对去除签名材料后的源码快照进行对照，发现以下需要人工设计迁移并测试的实质差异：

- Android 的 main 使用版本 4 分块密文表和 `card_wallet_local_data_v1` 本机密钥；试验分支改用版本 5 的 `encrypted_payload` 列和不同的密钥别名。不能将试验分支直接覆盖到现有数据库实现，否则可能无法读取既有密文。
- 试验分支的 `extraFields`/`CardFutureFields` 是当前 main 数据模型没有的未知字段保留实现，不能把两个分支直接宣称为完全重复。
- Apple 客户端的钥匙串错误处理、同步引导、锁定状态与写入流程也存在不同实现，需要在保留 main 已有保护的前提下逐项整合。
- main 已有离线品牌资源及相应测试；不能为接纳旧试验实现而回退这些资源和已通过的回归覆盖。

因此本次没有删除这两个分支，也没有使用保留当前树的空合并来伪装完成合并。后续整合需先剔除旧签名和临时载荷，再迁移确有价值的功能、处理数据库兼容并运行四端测试；只有验证后的提交进入 main，才能删除对应分支。

## 发布前仍需完成

使用匹配仓库公开信任基准的私有备份运行 `scripts/upload-release-secrets.py`，确认六项 Secrets 全部上传成功，再执行两端发布和公开下载验证。旧发布仓库由维护者自行删除；在新仓库两端发布可用并安装新版之前保留它。详细步骤见 [签名与公开发布](signing-security.md)。

当前索引扫描不代表 Git 历史、PR 缓存或已下载副本已清除。任何发现的旧私钥均不得重新导入 CI。
