# 信用卡多端原生方案基础规范

## 1. 目标

- `web` 保持现状，继续作为主端
- `iOS / macOS / Android / Windows` 分别原生开发
- 各端 UI、平台能力、发布节奏独立
- 数据结构、导入导出协议、迁移规则统一
- 5 端都能读取同一份 JSON 文件

## 2. 核心原则

1. 共享协议只定义业务主数据，不混入平台能力字段
2. 平台本地能力单独落到本地扩展层
3. 所有客户端都必须支持旧版本导入迁移
4. 所有客户端都必须能导出统一协议 JSON
5. `schemaVersion` 必须始终存在
6. `SharedCard` 是唯一跨端真源数据
7. 任何端都不能把平台专属字段直接写进 `cards[].xxx`

## 3. 数据分层

### 3.1 SharedCard

跨端同步主模型，只放核心业务字段。

### 3.2 ClientMeta

客户端本地元数据，不要求跨端共享。

### 3.3 Asset

图片、附件、OCR 结果、NFC 绑定结果等资源或扩展能力。

### 3.4 DerivedView

只计算不存储的字段。

## 4. 统一字段规范

### 4.1 SharedCard 字段表

| 字段名 | 类型 | 必填 | 示例 | 含义 | 备注 |
| --- | --- | --- | --- | --- | --- |
| `id` | `string` | 是 | `643fbfae3881` | 卡片唯一主键 | 全端唯一，不允许重复 |
| `country` | `string` | 是 | `中国` | 发卡国家/地区 | 使用标准中文值 |
| `bank` | `string` | 是 | `广发银行` | 银行标准名称 | 不带英文附加名 |
| `alias` | `string` | 否 | `京东卡` | 用户自定义别名 | 可为空 |
| `level` | `string` | 否 | `银联-白金卡` | 卡等级或品牌等级 | 走统一选项 |
| `cardNumber` | `string` | 是 | `6226222233334444` | 卡号 | 存储时建议纯数字 |
| `cvv` | `string` | 否 | `123` | 安全码 | 3 或 4 位 |
| `valid` | `string` | 否 | `08/33` | 有效期 | 固定 `MM/YY` |
| `limit` | `number` | 否 | `50000` | 授信额度 | 不带货币符号 |
| `type` | `string` | 否 | `CNY` | 币种代码 | 历史字段名，实际是 currency code |
| `isSharedLimit` | `boolean` | 是 | `true` | 是否共享额度 | 默认跟 web 一致 |
| `accountBillDate` | `string` | 否 | `23` | 账单日 | 统一存字符串 `1-31` |
| `dueDate` | `string` | 否 | `12` | 还款日 | 统一存字符串 `1-31` |
| `billingDaySpendingToNextBill` | `boolean` | 是 | `true` | 账单日消费是否记入下期 | `true` 表示下期 |
| `annualFee` | `number` | 否 | `800` | 年费金额 | 不带货币符号 |
| `isQualified` | `string` | 否 | `1` | 年费达标状态 | 只允许 `1/2/3` |
| `nextAnnualFeeCollectionTime` | `string` | 否 | `2026-09-06` | 下次年费收取日期 | 固定 `YYYY-MM-DD` |
| `lastTime` | `string` | 否 | `2025-12-24` | 上次提额日期 | 固定 `YYYY-MM-DD` |
| `lastModifyTime` | `string` | 是 | `2026-03-23 16:00:00` | 最后修改时间 | 冲突判断核心字段 |
| `equity` | `string` | 否 | `机场贵宾厅` | 权益说明 | 可多行文本 |
| `remark` | `string` | 否 | `消费6笔免年费` | 备注 | 可多行文本 |

### 4.2 枚举值约束

#### `type`

- `CNY`
- `CNH`
- `USD`
- `HKD`
- `MOP`
- `TWD`
- `EUR`
- `GBP`
- `JPY`
- `SGD`
- `AUD`
- `CAD`
- `CHF`
- `THB`

#### `isQualified`

- `1`: 已达标
- `2`: 未达标
- `3`: 终免年费

### 4.3 ClientMeta 字段表

| 字段名 | 类型 | 跨端同步 | 含义 |
| --- | --- | --- | --- |
| `cardId` | `string` | 否 | 对应 `SharedCard.id` |
| `createTime` | `string` | 否 | 本端创建时间 |
| `localFlags` | `object` | 否 | 本地状态位 |
| `hasBiometricProtection` | `boolean` | 否 | 本端是否启用生物识别保护 |
| `hasNfcBinding` | `boolean` | 否 | 本端是否存在 NFC 绑定 |
| `lastViewedAt` | `string` | 否 | 本端最后查看时间 |

### 4.4 Asset 字段表

| 字段名 | 类型 | 跨端同步 | 含义 |
| --- | --- | --- | --- |
| `id` | `string` | 可选 | 资源主键 |
| `cardId` | `string` | 可选 | 对应卡片 ID |
| `type` | `string` | 可选 | 资源类型 |
| `uri` | `string` | 否 | 本地文件 URI 或远程资源地址 |
| `thumbnailUri` | `string` | 否 | 缩略图地址 |
| `mimeType` | `string` | 否 | 文件类型 |
| `createdAt` | `string` | 否 | 创建时间 |

建议 `Asset` 初期不跨端同步，只由各端本地使用。

### 4.5 DerivedView 字段表

| 字段名 | 类型 | 存储 | 含义 |
| --- | --- | --- | --- |
| `interestFreePeriod` | `number` | 否 | 免息期天数 |
| `daysUntilDue` | `number` | 否 | 距离还款日剩余天数 |
| `daysUntilAnnualFee` | `number` | 否 | 距离年费收取剩余天数 |
| `isExpiringSoon` | `boolean` | 否 | 是否即将过期 |

## 5. 统一存储值规则

- 国家：标准中文值
- 银行：标准中文值
- 币种：统一存代码，例如 `CNY/USD/HKD`
- 年费状态：统一存 `1/2/3`
- 时间：统一存 `YYYY-MM-DD HH:mm:ss`
- 日期：统一存 `YYYY-MM-DD`
- 有效期：统一存 `MM/YY`
- 卡号：建议统一存纯数字，显示时由各端自行格式化

## 6. 5 端如何共用同一份 JSON

### 6.1 统一 JSON 文件目标

同一份 JSON 必须满足：

- `web` 可以导出
- `iOS` 可以导入
- `macOS` 可以导入
- `Android` 可以导入
- `Windows` 可以导入
- 任一端导出后，其他 4 端仍可读取

### 6.2 统一协议格式

```json
{
  "schemaVersion": "2.0.0",
  "exportedAt": "2026-03-23 16:00:00",
  "source": "web",
  "cards": [
    {
      "id": "643fbfae3881",
      "country": "中国",
      "bank": "广发银行",
      "alias": "京东卡",
      "level": "银联-白金卡",
      "cardNumber": "6226222233334444",
      "cvv": "123",
      "valid": "08/33",
      "limit": 50000,
      "type": "CNY",
      "isSharedLimit": true,
      "accountBillDate": "23",
      "dueDate": "12",
      "billingDaySpendingToNextBill": true,
      "annualFee": 800,
      "isQualified": "1",
      "nextAnnualFeeCollectionTime": "2026-09-06",
      "lastTime": "2025-12-24",
      "lastModifyTime": "2026-03-23 16:00:00",
      "equity": "机场贵宾厅",
      "remark": "消费6笔免年费"
    }
  ],
  "deletedCardIds": []
}
```

### 6.3 文件中允许出现什么

允许：

- `schemaVersion`
- `exportedAt`
- `source`
- `cards`
- `deletedCardIds`

不建议出现：

- 平台本地 UI 字段
- 表格行合并字段
- 显示控制字段
- 本地缓存标记
- 本地照片路径
- 本地 NFC 原始数据

### 6.4 5 端共用同一份 JSON 的实现规则

#### web

- 导出时只写 `SharedCard`
- 导入时只认 `cards`
- 允许兼容旧数组格式，但新格式必须优先采用协议对象

#### iOS

- 导入统一协议后，写入 `SharedCard`
- `ClientMeta` 本地生成，不回写进 JSON
- `Asset` 本地管理，不写进 `cards`

#### macOS

- 规则与 `iOS` 相同
- 支持文件拖拽导入导出

#### Android

- 规则与 `iOS` 相同
- NFC、相机、权限状态只落本地

#### Windows

- 规则与 `macOS` 类似
- 先保证查看和导入导出兼容

### 6.5 文件读写责任

所有端都必须实现：

1. `parse file`
2. `detect schemaVersion`
3. `migrate to current schema`
4. `normalize values`
5. `validate cards`
6. `write local database`

### 6.6 谁能改 JSON

- `web`：可以编辑并导出
- `iOS`：可以轻编辑并导出
- `macOS`：可以编辑并导出
- `Android`：可以编辑并导出
- `Windows`：可以查看、编辑并导出

重点不是哪一端“地位高”，而是任何端导出都必须遵守同一份协议。

## 7. 冲突与同步规则

### 7.1 主键规则

- `id` 为唯一主键
- 新建卡片时，各端自行生成唯一 ID
- 导入时如果 `id` 已存在，则进入冲突判断

### 7.2 冲突判断规则

- 以 `lastModifyTime` 为主
- 时间较新的覆盖时间较旧的
- 如果时间相同，保持本地版本

### 7.3 删除规则

- 短期可不实现跨端删除同步
- 中期建议使用 `deletedCardIds`
- 长期可升级为 tombstone 机制

## 8. 迁移规则

所有端都必须有这 4 步：

1. `parse`
2. `normalize`
3. `migrate`
4. `validate`

### 8.1 normalize 要做什么

- 国家旧值映射成标准值
- 银行旧值映射成标准值
- 币种显示值映射成代码
- 日期格式统一
- 布尔值统一成真正布尔类型
- 数字字符串转 number

### 8.2 validate 至少检查什么

- `id` 是否存在
- `country` 是否存在
- `bank` 是否存在
- `cardNumber` 是否存在
- `valid` 格式是否为 `MM/YY`
- `type` 是否为允许的币种代码
- `isQualified` 是否为 `1/2/3`
- `lastModifyTime` 是否存在

## 9. 平台能力边界

- NFC：平台本地能力，不进入 `SharedCard`
- 照片：进入 `Asset`
- 生物识别：进入 `ClientMeta`
- 推送提醒：平台本地能力
- WebDAV / 文件导入导出：同步层能力

## 10. 每端允许负责什么

### web

- 主字段维护
- 大批量编辑
- 大量筛选与统计
- 协议参考实现

### iOS

- 主力移动查看
- 轻编辑
- NFC
- 照片采集
- 生物识别保护

### macOS

- 主力桌面管理
- 文件拖拽
- 高密度表格查看

### Android

- 补充移动端
- NFC
- 拍照
- 导入导出

### Windows

- 补充桌面端
- 查看
- 筛选
- 导入导出

## 11. 推荐开发顺序

1. `iOS`
2. `macOS`
3. `Android`
4. `Windows`

