# 两个旧对齐分支的实际整合与冲突处理

整合对象：`e8b8333b778927d9206b2f7a5d2a93ec52cf6bec` 和 `6948ec4e68eb54a6bda743c697e1e47c3affbbb1`。整合前业务代码基准为 main `7a0aadcf8e8cb90ee859585372c75d30b0fbebf2`。这不是直接覆盖或保留当前树的空合并。

## 逐类决议

| 旧分支内容 | 整合结果 |
| --- | --- |
| CardFutureFields、CardJSONValue、卡片与图片 extraFields | 迁移到三端原生模型，并补齐 Web 的导入保留逻辑。编辑、备份导入、同步和本地加密存储均保留未知 JSON；过滤本机 UI 状态、旧身份别名和危险属性名。 |
| CalendarRules、Metrics、Search、Operations 与旧测试数据 | 采用 main 的 WalletCardRules、cardCatalog、提醒、批量操作和共用 fixtures；不恢复同一业务的第二套实现。原有测试不删除，额外加入共用 unknown-fields fixture 和四端回归。 |
| Android v5 encrypted_payload、替代密钥别名及本地偏好加密方案 | 冲突选择 main 的 v4 分块密文、AAD 与 card_wallet_local_data_v1；保留大图片读写、丢失密钥失败保护和真实 AndroidKeyStore 回归，不更换数据库结构。 |
| Apple LocalWalletCipher、WebDAVSessionRegistry、锁定与引导流程 | 冲突选择 main 已落实的 LocalDataCipher、钥匙串错误处理、串行/原子写入、锁定保护和网络生命周期，避免恢复旧存储和并行状态实现。 |
| 旧品牌、界面和无障碍实现 | 保留 main 的四端离线素材、主题、图片策略、搜索排序、本机收藏和当前界面；不回退旧品牌判断或未完成界面。 |
| .parity-final 载荷、parity-apply/source/resume/workspace 临时流程、旧签名 | 不进入最终代码树；它们是传输/执行中间产物或已泄漏材料，不作为产品能力保留。完整原始 Git 备份已在仓库外加密保存。 |

两个旧分支互相比对，领域数据层的未知字段实现相同；completion 中额外的引导、主题修补及 sync-cases/schema 与 main 对照后采用当前主线的已完成实现。整合提交保留两个父分支的祖先关系。删除分支必须在整合后的四端 CI 全部成功后执行，并验证祖先关系与精确 SHA 租约；运行失败不删除。

## 验证范围

新增共同 JSON 夹具包含嵌套对象、数组、数值、布尔、null 与图片扩展信息。测试覆盖编辑、序列化往返、同步记录、Mac 字典备份导入以及 Android 真实加密数据库大图片往返。Swift JSON 编解码在本地完成编译与执行；完整原生、浏览器、Lint 和设备测试以本次 GitHub Actions 的最终结论为准。

签名 Secrets 上传和正式发布是独立门禁。代码整合成功不代表新密钥已经存入 Secrets，也不代表历史泄漏已从 GitHub 缓存清除。
