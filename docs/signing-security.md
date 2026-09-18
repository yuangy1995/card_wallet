# 公开仓库签名与发布

## 信任边界

源码和安装包统一位于 `yuangy1995/card_wallet`。私钥、签名密码不进入 Git；Actions 只在正式签名步骤从 Secrets 读取。发布本仓库使用临时 `GITHUB_TOKEN`，无需原跨仓库 `RELEASES_TOKEN`。普通 PR、推送和 Debug 构建不取得发布密钥。

Android 已移除当前代码中的旧 keystore 和明文配置，拒绝旧证书。新公钥证书指纹在 `apps/android/signing-certificate.sha256`。macOS 新更新公钥在 `apps/macos/Resources/Info.plist`，CI 在构建前验证新私钥与其一致；保留原 Ad-Hoc 构建，不增加 Apple 证书或公证要求。

## 配置新密钥

私有备份必须保存在本仓库之外的加密磁盘或密码管理器中，不得上传到源码、Release、Actions 附件或聊天。备份内包含 `release.p12`、`signing.json` 和 `sparkle-private-key.txt`。公钥和证书指纹可公开，私钥与密码不可公开。

在已登录 GitHub CLI 且安装 JDK 17、OpenSSL 的维护者电脑上运行：

```bash
python3 scripts/upload-release-secrets.py --directory /仓库之外/私有签名目录
```

工具只通过标准输入上传六项 Secrets：Android 的 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`、`ANDROID_SIGNING_CERT_SHA256`，以及 Mac 的 `SPARKLE_PRIVATE_KEY`。它会先验证本地签名材料和远端公开信任基准，上传失败时不触发发布；重跑上传同一套备份，不重复生成密钥。

加 `--publish` 可在六项上传全部成功后触发 Android 1.3.0（5）和 Mac 1.1.0（7）的发布工作流。触发不等于发布完成，必须检查两个运行结论和 Release 附件。此工具不会删除旧仓库、改写历史或强制合并分支。Secrets 写入需要账号对当前仓库有 Secrets 写权限；不要把账号令牌粘贴到聊天中。

## 发布和安装

Android 旧签名版本不能直接覆盖：先导出并验证数据备份，再卸载安装新版。Mac 旧更新地址及公钥不再沿用，需要手动替换一次应用，但不删除数据目录。后续版本保留这套新密钥并递增构建号。

Android Releases 使用 `--latest=false`，Mac Release 设为 Latest 并包含双架构 ZIP 和 `appcast.xml`。客户端、打包脚本、签名验证脚本统一限定本仓库。`publish=false` 可以演练，但公开仓库的 Actions 附件不具备私密性。

旧产物仓库由维护者自行删除；在本仓库两端正式发布验证成功并安装新版之前不要删除它。

## 历史和分支

删除当前文件不会移除 Git 历史、旧分支、PR 引用、缓存或已下载副本。本次轮换不继续信任旧密钥；历史清理仍需独立执行，不能把当前索引检查通过写成完整历史已清除。

分支删除前使用 `git merge-base --is-ancestor <分支SHA> main` 验证，并核对远端分支未在检查后发生移动。两个旧四端对齐试验分支存在未合并提交和不同实现，不能凭名称或已有相关 PR 合并就直接删除，也不能直接用其旧实现覆盖 main。

进行历史清理时先把完整镜像备份到仓库外，完成未合并改动的审核后，再使用 git-filter-repo 从所有相关引用移除签名文件和旧密码。`scripts/prepare-signing-history-redactions.py` 只在私有目录生成替换表，不打印密码、不推送。重写历史会改变提交 SHA，并可能需要 GitHub Support 处理 PR 缓存；禁止在公开仓库创建含旧密钥的备份分支或标签。

## 检查

```bash
python3 scripts/check-signing-secrets.py
python3 -m unittest discover -s scripts -p 'test_*security.py'
python3 -m unittest discover -s scripts -p 'test_public_release_migration.py'
python3 -m unittest discover -s apps/android/scripts -p 'test_*.py'
```

这些是当前 Git 索引及配置回归检查，不替代完整历史审计、原生构建或真机更新测试。
