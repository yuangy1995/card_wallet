# 统一字段规范基线

本文档作为 `web` 端与 `app` 端后续重构的数据字段基线。

## 原则

- `web` 端是唯一主数据源
- `app` 端以查看为主，字段结构必须向 `web` 端靠拢
- 只有跨端共享、需要同步的字段，才能进入主卡片模型
- 派生字段不落库
- app 专属能力字段不进入主卡片模型顶层

## 字段分类

- `shared`: 跨端共享主模型字段
- `derived`: 派生字段，只计算不存储
- `client_meta`: 客户端本地元数据，不进入共享模型
- `transport_only`: 仅兼容旧传输结构，重构后应移除

## 统一字段表

| 字段名 | 类型 | 分类 | 跨端同步 | web 主模型 | app 保留方式 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `id` | `string` | `shared` | 是 | 是 | 主模型保留 | UUID 主键 |
| `country` | `string` | `shared` | 是 | 是 | 主模型保留 | 国家/地区 |
| `bank` | `string` | `shared` | 是 | 是 | 主模型保留 | 银行名称 |
| `alias` | `string` | `shared` | 是 | 是 | 主模型保留 | 卡片别名 |
| `level` | `string` | `shared` | 是 | 是 | 主模型保留 | 卡片等级 |
| `cardNumber` | `string` | `shared` | 是 | 是 | 主模型保留 | 卡号 |
| `cvv` | `string` | `shared` | 是 | 是 | 主模型保留 | 安全码 |
| `valid` | `string` | `shared` | 是 | 是 | 主模型保留 | 建议统一为 `MM/YY` |
| `limit` | `number` | `shared` | 是 | 是 | 主模型保留 | 信用额度 |
| `type` | `string` | `shared` | 是 | 是 | 主模型保留 | 历史字段名，当前实际表示币种代码 |
| `isSharedLimit` | `boolean` | `shared` | 是 | 是 | 主模型保留 | 是否共享额度 |
| `accountBillDate` | `string` | `shared` | 是 | 是 | 主模型保留 | 账单日，统一字符串 |
| `dueDate` | `string` | `shared` | 是 | 是 | 主模型保留 | 还款日，统一字符串 |
| `billingDaySpendingToNextBill` | `boolean` | `shared` | 是 | 是 | 主模型保留 | 账单日消费归属规则 |
| `annualFee` | `number` | `shared` | 是 | 是 | 主模型保留 | 年费 |
| `isQualified` | `string` | `shared` | 是 | 是 | 主模型保留 | 年费达标状态 |
| `nextAnnualFeeCollectionTime` | `string` | `shared` | 是 | 是 | 主模型保留 | 下次年费收取时间 |
| `lastTime` | `string` | `shared` | 是 | 是 | 主模型保留 | 上次提额时间 |
| `lastModifyTime` | `string` | `shared` | 是 | 是 | 主模型保留 | 最后修改时间 |
| `equity` | `string` | `shared` | 是 | 是 | 主模型保留 | 权益说明 |
| `remark` | `string` | `shared` | 是 | 是 | 主模型保留 | 备注 |
| `createTime` | `string` | `client_meta` | 否 | 否 | 本地元数据 | 如需保留，放 `CardAppMeta` |
| `interestFreePeriod` | `number` | `derived` | 否 | 否 | 不存储 | 由账单日、还款日、记账规则计算 |
| `_unknownFields` | `object` | `transport_only` | 兼容期 | 否 | 重构后移除 | 旧兼容兜底字段 |
| `_extensionFields` | `object` | `transport_only` | 兼容期 | 否 | 重构后移除 | 旧扩展字段容器 |

## 重构后的推荐模型

### 1. SharedCard

跨端同步、真正进入主数据模型的字段。

```ts
export interface SharedCard {
  id: string;
  country: string;
  bank: string;
  cardNumber: string;
  alias?: string;
  level?: string;
  type?: string;
  limit?: number;
  cvv?: string;
  valid?: string;
  annualFee?: number;
  isQualified?: string;
  nextAnnualFeeCollectionTime?: string;
  lastTime?: string;
  accountBillDate?: string;
  dueDate?: string;
  billingDaySpendingToNextBill: boolean;
  equity?: string;
  remark?: string;
  lastModifyTime: string;
  isSharedLimit: boolean;
}
```

### 2. CardAppMeta

只属于 app 端、本地能力或设备能力相关的元数据。

```ts
export interface CardAppMeta {
  cardId: string;
  createTime?: string;
  nfcTagId?: string;
  hasNfcBinding?: boolean;
  localFlags?: Record<string, unknown>;
}
```

### 3. CardAsset

银行卡照片、附件、缩略图等资源数据。

```ts
export interface CardAsset {
  id: string;
  cardId: string;
  type: 'bank_card_photo' | 'attachment';
  uri: string;
  thumbnailUri?: string;
  mimeType?: string;
  createdAt: string;
}
```

### 4. CardComputedView

只用于 UI 展示的派生视图字段。

```ts
export interface CardComputedView {
  interestFreePeriod?: number;
}
```

## 后续执行建议

### app 端

- 删除 `CreditCard` 中的 `interestFreePeriod`、`_unknownFields`、`_extensionFields`
- `createTime` 从主表移到本地 `meta` 结构
- 所有同步、导入、导出只围绕 `SharedCard`
- 时间格式统一跟随 `web`
- 默认值统一跟随 `web`

### 未来功能扩展

- NFC 绑定信息放 `CardAppMeta` 或独立 `CardNfcBinding`
- 银行卡照片放 `CardAsset`
- 不要把照片、NFC 原始数据直接塞进主卡片对象

