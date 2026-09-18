# Web 审查与四端功能对照（2026-09-18）

> 后续状态：本报告保留 PR #5 的历史审查结论。剩余 Web 问题的修复及新的四端实施建议见 [后续实施记录](web-completion-and-parity-2026-09-18.md)。

## 范围和基线

- 基线：`main@34a811c3c0502af84120a6b32d7617891901354d`。
- PR：[#5](https://github.com/yuangy1995/card_wallet/pull/5)。代码修复截至 `c6d8f523a3d89a407d2aaf3f6290702623f96cc5`。
- 审查了 Web 的本地数据库、密码和自动锁定、主题、主要列表入口、同步服务，以及 Android/iOS/macOS 的数据模型、主列表、工具和相关构建配置。
- 本文区分“入口/模型已存在”“行为未对齐”“尚未完成的验证”。存在源码不等于默认构建可用，存在相同字段也不等于四端业务计算完全一致。
- 本 PR 修复部分已确认的 Web 问题，并记录仍未修复的问题；没有改写其他三个客户端，没有修改 SyncV4 协议或签名材料，也没有声称完成全部功能补齐。

## 本 PR 已修复

| 问题 | 原始风险 | 修复及验证点 |
| --- | --- | --- |
| 旧 localStorage 数据清理前没有迁移 | 旧用户升级后，卡片及同步元数据可能被删除 | 新数据库中先以单个事务迁移六类记录，再清理对应源值；失败保留源数据；已有数据库包括空账本优先，避免旧卡复活 |
| IndexedDB 提交前更新缓存 | 写入失败或数据库不可用时，界面读到尚未保存的值；失败回滚可能覆盖后续写入 | 只在事务完成后发布缓存，写入/删除失败不更改已提交缓存；数据库打开失败允许重试 |
| 每次保存都进行容量估算和额外复制 | 连续保存和带图片卡片增加不必要开销 | 30 秒内复用/合并容量估算；不再复制整份旧值用于回滚；数据库加载不再重复 JSON 深复制 |
| 自动锁定依赖延迟计时器和先读后节流 | 后台恢复的首次操作可能延长过期会话；闲置标签页可能锁住活跃页面 | 先节流再读同步存储；按真实截止时间计算倒计时；首次输入先检查过期；到期重查跨标签页活动；移除监听和计时器 |
| 设置密码忽略持久化失败 | 存储被禁用时仍报告密码设置成功 | 持久化失败明确报错，不继续成功流程 |
| 忘记密码重置遗漏同步快照/历史 | 清空主数据后仍留下关联卡片资料 | 同时清理六类数据库和 legacy 数据；数据删除失败不清除密码 |
| Web 默认写死深色，系统监听失效 | 首次启动即保存 dark，使“无偏好时跟随系统”的条件无法成立；监听器不清理 | 新用户默认跟随系统；保留已保存的 light/dark；支持 system 值；卸载移除媒体监听；存储被禁用时仍可临时切换 |

迁移限制：已经被旧版本删除的 localStorage 数据不能凭空恢复；数据库和 legacy 存在分歧时，本次不自动混合，避免传播过时记录。旧版本自动写入的 dark 与用户主动选择的 dark 无法可靠区分，因此既有 dark 偏好会保留。

### 自动验证

新增四个测试文件，共 31 个用例：数据库 14、自动锁定 7、密码/清空 5、主题 5。保留原有测试。

- 首轮 CI：[Web quality / 35293476043](https://github.com/yuangy1995/card_wallet/actions/runs/35293476043)，13 个测试文件、80 个测试通过，`pnpm build` 通过。
- 包含主题修复与测试的代码版本 CI：[Web quality / 35293725277](https://github.com/yuangy1995/card_wallet/actions/runs/35293725277)，工作流结果 success。
- 工作流使用 Node 22、pnpm 10、冻结 lockfile 安装，只读仓库权限；不发布、不读取发布密钥。
- 本地另执行了同源数据库测试的 Node 运行器适配版，14/14 通过；100 次连续写入只触发一次容量估算。这是调用次数验证，不是用户页面加载速度提升百分比。
- 没有执行四端实机互同步、真实浏览器性能录制或真实 WebDAV 服务器端到端测试。CI 成功不能替代这些检查。

## 仍未修复的 Web 风险

### P1：卡片分组金额混合币种和地区

位置：`apps/web/src/components/card/CreditCardCardList.vue` 的 `calculateLimitSum` 和组头模板。

该函数只按银行建立共享额度池，没有按国家/地区、币种拆开；独立额度直接相加；组头统一加 `¥`。例如同组 USD 1,000 与 HKD 2,000 的独立额度，会显示成 `¥3,000`，这不是货币换算，也不是可比较的总额度。同一银行跨地区共享卡还可能被错误取一个最大值。

macOS 的 `apps/macos/Domain/CardCatalog.swift` 已按地区、规范化银行名、币种建立共享池，并返回按币种拆分的金额。本 PR **没有修复 Web 这一计算路径**，不能把该组头数字视为可信的跨币种总额。

后续验收应覆盖：同银行不同地区、同地区不同币种、共享与独立混合、银行别名、空币种、储蓄卡排除；显示各币种独立金额，除非明确提供汇率和日期，否则不输出折算总额。

### P1：本地应用锁不是数据保险库

位置：`apps/web/src/utils/passwordManager.js`、`storage.js`、`indexedDbStorage.js`。

原有密码校验使用固定盐与源码中的固定加密口令；卡片值直接进入 IndexedDB，WebDAV 配置通过 localStorage 管理器保存。修复超时、保存失败和重置遗漏，并不意味着本地数据改成了由用户密码派生密钥保护的密文。

此处需要单独设计本地加密格式、随机盐和密钥派生、解锁生命周期、旧数据迁移、恢复与密码修改策略，以及对本地脚本读取和 XSS 的威胁边界。本 PR 保持原数据/同步格式，没有把界面锁描述为本地强加密。

### P2：大量卡片的渲染和选择成本

位置：`CreditCardTable.vue`、`CreditCardCardList.vue`。

- 表格直接绑定全部筛选结果；卡片视图对展开组逐卡渲染，没有接入窗口化列表。
- 卡片列表多处逐卡调用 `selectedRows.some`，全选判断也嵌套扫描。选择数量大时，判断成本随行数和已选数一起增长。
- 清理选择状态的 deep watch 遍历完整卡片对象，卡片图片等与 ID 是否存在无关的数据也进入依赖遍历。

建议后续用选中 ID 的 Set、只观察卡片 ID、视口内渲染优化；用固定 50/500/2,000 张测试卡分别测量渲染、搜索、全选和图片编辑，不在没有实测时宣称某个速度提升百分比。

### P2：首包和重复业务逻辑

首轮生产构建日志显示 ECharts JS 约 901.80 kB（gzip 277.10 kB）、Element Plus JS 约 852.32 kB（gzip 250.66 kB）。这些是 chunk 体积，不是首屏实际下载量或首屏耗时。`App.vue` 中部分异步弹窗无条件挂载；异步 import 本身不保证首次打开时才加载，应通过网络录制核实，并避免把统计页已经存在的条件挂载误报成缺失。

日期、卡组织识别、排序和共享额度在不同视图/平台有多份实现，需要共用测试样例验证行为，不能只按函数名认定一致。本 PR 未进行这些路径的大规模重构。

## 四端功能对照

### 已存在的共同能力

四端均有信用卡/储蓄卡管理、主要卡片字段、WebDAV V4 同步相关实现、批量修改/删除、统计/优惠用卡/数据异常检测入口。卡片图片是共享模型的一部分。这里的“存在”是源码/界面入口层面的结论，不等同于实机互操作全部通过。

依据：Web `App.vue`、`webdavSyncService.js`；Android `ui/main/MainScreen.kt`、README；iOS `HomeView.swift`、`ToolsView.swift`、`CardModels.swift`、`SettingsView.swift`；macOS `WalletCardsView.swift`、`CardCatalog.swift`、README。

### 已确认的不一致

| 维度 | Android | iOS / iPadOS | macOS | Web |
| --- | --- | --- | --- | --- |
| NFC 录入/核对 | 有前台刷卡与快速核对流程 | 保留源码，但默认 project.yml 排除 NFCCardReader.swift，界面受 ENABLE_NFC_CARD_READER 控制，不能算默认可用 | 本次未确认对等读卡入口，不要求桌面端照搬手机能力 | 本次未确认对等读卡入口，不把浏览器与原生硬件 API 等同 |
| 相机/图片辅助录入 | CameraX + ML Kit 文本识别实现（README） | CardEditView 有相机、PhotosPicker、Vision 扫图入口 | 有卡片图片导入；本次未验证 OCR 同等能力 | 本次未验证 OCR 同等能力 |
| 收藏与只看收藏 | 主列表支持，WalletPreferences 持久化 | 已审查主列表未见对等收藏筛选 | 已审查主列表未见对等收藏筛选 | 已审查列表筛选未见对等收藏入口 |
| 收藏跨设备同步 | 收藏明确是本机 presentation preference，不进入 SyncV4 | 无四端收藏同步闭环 | 无四端收藏同步闭环 | 无四端收藏同步闭环 |
| 搜索字段 | 银行、别名、卡号、备注、卡组织、类别等 | 银行、别名、卡号、等级；没有包含备注/权益/币种的同等首页搜索 | 索引银行、别名、卡号和类别；没有包含备注/权益/币种的同等搜索 | 更广：银行、别名、卡号、等级、币种、地区、权益、备注、额度、类别 |
| 按卡等级分组 | 有 | 有 | 有 | 卡片视图仅无分组、银行、地区、卡组织，缺卡等级分组 |
| 免息期排序 | 主列表支持从长到短 | 模型提供从长到短/从短到长 | 支持从长到短/从短到长 | 卡片视图排序菜单没有免息期排序；提供额度、年费日期、修改时间等 |
| 分组/排序选择保留 | MainScreen 写入 SharedPreferences | HomeView 使用 @State 默认 bank / limitDesc，页面重建后的偏好保留未对齐 | 本次不推断绑定状态的跨启动保留行为 | 卡片视图写入 localStorage |
| 默认深浅色 | 默认 SYSTEM | SettingsView 默认 light，虽提供 system 选项 | 本次不将主题调色板与系统深浅色偏好混为一项 | 本 PR 改为无已存偏好时跟随系统；旧 light/dark 保留 |
| 品牌素材与兜底 | WalletLogoCatalog 等资源体系 | CardBrandIcon 使用单独 SwiftUI 绘制 | CardBrandIcon 明确使用与 Android 共享的离线资源 | PhysicsCard 使用自有 SVG/CSS/文字组合，未统一到 Android/macOS 资源体系 |
| 列表/卡片呈现 | 紧凑列表与卡片偏好 | HomeView 为分组卡片行；不是桌面多列表格 | 列表/网格与检查器 | 表格/3D 卡片、列自定义；平台特有呈现不应强行像素一致 |
| 共享额度口径 | 本次没有完成全部计算路径的交叉测试 | 本次没有完成全部计算路径的交叉测试 | CardCatalog 按地区/银行/币种计算 | 卡片分组头存在前述确定性错误，仍待修复 |

### 关键源码证据

- iOS NFC：`apps/ios/project.yml`、`apps/ios/Features/CardEditView.swift`。不能因为 Domain 目录存在 NFC 文件，就给默认版本标记“支持”。
- Android 收藏/筛选：`apps/android/app/src/main/java/com/example/creditcard/ui/main/MainScreen.kt`、`ui/wallet/WalletPreferences.kt`。
- iOS 搜索、分组和局部状态：`apps/ios/Features/HomeView.swift`；排序选项：`apps/ios/Domain/CardModels.swift`。
- macOS 搜索/额度：`apps/macos/Domain/CardCatalog.swift`；列表入口：`apps/macos/Features/WalletCardsView.swift`。
- Web 搜索：`apps/web/src/App.vue`；分组/排序和汇总：`apps/web/src/components/card/CreditCardCardList.vue`。
- 主题：Android `utils/ThemeManager.kt`；iOS `Features/SettingsView.swift`；Web `src/composables/useTheme.js`。
- 品牌：iOS/macOS 各自 `Features/CardBrandIcon.swift`；Web `CreditCardPhysicsCard.vue`；Android `ui/wallet/WalletLogoCatalog.kt`。

## 建议的补齐顺序

1. 先修金额口径，统一共享额度、币种与日期边界的跨端测试样例；并单列本地加密迁移设计。不要只统一外观而保留金额差异。
2. 统一搜索字段、卡等级分组、免息期双向排序、列表偏好保留；明确收藏是本机偏好还是需要设计版本兼容的同步字段。
3. 将 Android/macOS 的银行与卡组织资源匹配、歧义兜底规范适配到 iOS/Web；不要把“有 Logo”误认为素材已一致。
4. 对 NFC、相机、桌面快捷键和表格列配置采用平台适配；iOS NFC 先确认构建开关与实际部署要求，不能只取消条件编译就宣称可用。
5. 用相同脱敏 fixtures 做四端新增、修改、删除标记、离线修改合并、图片往返、恢复与失败重试验证。统计、提醒和最优用卡都应比较具体输出，而不是仅检查入口是否存在。
