# 卡包 Web 端

Vue 3 + Element Plus + Vite 的本地优先卡包应用，用于管理信用卡、储蓄卡、统计分析、安全锁和 WebDAV 加密后台同步。

本仓库只保留根目录 `README.md` 作为维护入口。旧的 `docs` 目录、历史审计报告和过期方案文档已经删除，避免后续维护时被旧实现误导。

## 当前架构

- 前端框架：Vue 3 Composition API、Element Plus、Vite、SCSS。
- 本地主数据：IndexedDB，数据库名 `credit-card-web-local-db`，对象仓库 `kv`。
- 大体量数据：`cardData`、`cardSyncRecordsV4`、`cardSyncPendingV4`、`cardSyncMutationRevisionV4` 已迁入 IndexedDB。
- 轻量偏好：主题、视图模式、筛选条件、表格列配置、WebDAV 配置等仍使用 `localStorage`。
- 云同步：SyncV4 账本模型 + WebDAV 自动快照，保存和刷新页面时先使用本地数据，云端同步在后台执行。
- 同步文件：`[SyncV4][Web][自].json`，通过同步密钥加密后上传到 WebDAV。

## 关键数据规则

- `cardCategory` 表示卡类别，取值为 `credit` 或 `debit`；历史数据缺失时按 `credit` 处理。
- `type` 是历史字段名，当前实际表示币种代码；空币种保持为空，不再强制默认 `CNY`。
- `bank` 是发卡行显示名；编辑同一银行名称时，会同步更新同银行下的多张卡片。
- `cardImages` 保存卡片图片数据，会跟随卡片数据参与本地保存和 WebDAV 同步。
- `lastModifyTime` 是跨端合并的重要字段，保存和同步逻辑依赖它判断新旧数据。

## 常用命令

```bash
pnpm install
pnpm dev
pnpm test:run
pnpm build
```

不同部署路径的构建方式：

```bash
# 子路径部署，例如 https://example.com/card/
pnpm build -- --mode with-card

# 根路径部署，例如 https://example.com/
pnpm build -- --mode without-card
```

## 本地验证

1. 启动开发服务：`pnpm dev`。
2. 打开浏览器控制台的 Application 面板，确认 IndexedDB 下存在 `credit-card-web-local-db`。
3. 新增或编辑一张卡，确认页面很快关闭 loading，本地数据立即更新。
4. 等待顶部同步状态变为成功，确认 WebDAV 上生成新的 `[SyncV4][Web][自].json`。
5. 刷新页面，确认页面先显示本地数据，后台再检查云端更新。

## 维护注意

- 不再恢复基于 `localStorage` 存储全量卡片数据的旧方案，否则数据量变大后仍会触发浏览器 quota 问题。
- 不支持 IndexedDB 的浏览器直接提示升级或更换浏览器，不再做旧浏览器兼容。
- 改动同步协议、卡片字段或迁移逻辑后，优先补充 `src/utils/*.test.js` 里的单元测试。
- Web、Android、macOS 三端共用 SyncV4 数据语义，字段变更需要同时检查三端。
