# 卡包 Web 端

Vue 3 + Element Plus + Vite 的本地优先卡包应用，用于管理信用卡、储蓄卡、统计分析、安全锁和 WebDAV 加密后台同步。

仓库总览见根目录 README；本次安全、性能修复及四端对齐方案见 [实施记录](../../docs/web-completion-and-parity-2026-09-18.md)。历史审查描述的是对应基线，不是当前未修复清单。

## 当前架构

- 前端框架：Vue 3 Composition API、Element Plus、Vite、SCSS。
- 本地主数据：IndexedDB，数据库名 `card-wallet-web-local-db`，对象仓库 `kv`。
- 大体量数据：`cardData`、`cardSyncRecordsV4`、`cardSyncPendingV4`、`cardSyncMutationRevisionV4` 已迁入 IndexedDB。
- 本地保险库：IndexedDB 版本 2，卡片、账本、历史、快照及 WebDAV 凭证使用 AES-GCM 密文；需要本地密码解锁，旧数据验证后迁移。
- 轻量偏好：主题、视图模式、筛选条件和表格列配置使用 `localStorage`；不在这里保存新的明文同步凭证。
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
# 默认使用相对路径，适合根路径或任意子路径静态部署
pnpm build

# 如果部署平台明确需要绝对子路径，例如 https://example.com/card/
VITE_BASE=/card/ pnpm build
```

## 本地验证

1. 启动开发服务：`pnpm dev`。
2. 打开浏览器控制台的 Application 面板，确认 IndexedDB 下存在 `card-wallet-web-local-db`。
3. 新增或编辑一张卡，确认页面很快关闭 loading，本地数据立即更新。
4. 等待顶部同步状态变为成功，确认 WebDAV 上生成新的 `[SyncV4][Web][自].json`。
5. 刷新页面，先输入本地密码，解锁后显示本地数据并检查云端更新；手动锁定应立即关闭详情/统计弹窗。
6. 本地密码和同步密钥独立；忘记本地密码只能确认重置本地密文后，使用原云端配置与同步密钥恢复。不要回退旧版本 1 的数据库代码。

## 维护注意

- 不再恢复基于 `localStorage` 存储全量卡片数据的旧方案，否则数据量变大后仍会触发浏览器 quota 问题。
- 不支持 IndexedDB 的浏览器直接提示升级或更换浏览器，不再做旧浏览器兼容。
- 改动同步协议、卡片字段或迁移逻辑后，优先补充 `src/utils/*.test.js` 里的单元测试。
- Web、Android、iOS、macOS 四端共用 SyncV4 数据语义，字段变更需要同时检查四端。

## 自动验证

`pnpm test:run` 保留原有测试并覆盖本地加密、并发与分页。`pnpm build` 构建生产包。CI 另外运行 `python scripts/browser-regression.py`（Playwright 1.57.0 + Chromium），使用合成卡片，不连接真实账户。必须通过 HTTPS 或 localhost 部署；服务器需提供可信证书及 WebDAV CORS 设置。

## 列表浏览

收藏筛选与表格排序集中在列表上方，收藏数量即时显示；提示按钮说明收藏仅保存在本机。收藏仍使用现有本机加密存储，不加入云同步。

表格默认每页 50 条，可选择 20、50、100、200 条；卡片视图保留每页 24 张的默认值，同时支持上述数量。两种视图分别记住每页数量。筛选、搜索、排序或每页数量改变时回到第一页，分页条显示当前范围，窄屏自动换行。

鼠标移到银行组内任意记录时，高亮当前页中同地区、同银行的整个连续分组，包括合并的银行名称块。光带裁剪到表格可视区域，滚动、调整窗口和换页时清除旧位置，避免遮盖表头或分页。
