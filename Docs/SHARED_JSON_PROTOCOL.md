# 统一 JSON 协议说明

## 1. 为什么需要单独协议文件

多端分别开发时，真正必须统一的不是 UI，而是：

- 字段定义
- 存储值
- 导入导出结构
- 迁移策略

这个文件只描述“文件怎么长”，不描述界面怎么做。

## 2. 协议版本

当前版本：

- `schemaVersion = 2.0.0`

## 3. 顶层结构

```json
{
  "schemaVersion": "2.0.0",
  "exportedAt": "2026-03-23 16:00:00",
  "source": "web",
  "cards": [],
  "deletedCardIds": []
}
```

## 4. 顶层字段说明

| 字段名 | 类型 | 必填 | 含义 |
| --- | --- | --- | --- |
| `schemaVersion` | `string` | 是 | 当前文件所使用的协议版本 |
| `exportedAt` | `string` | 是 | 导出时间 |
| `source` | `string` | 是 | 导出来源，允许 `web/ios/macos/android/windows` |
| `cards` | `array` | 是 | 卡片主数据数组 |
| `deletedCardIds` | `array` | 否 | 已删除卡片 ID 列表 |

## 5. cards[] 结构

`cards[]` 中每一项都必须是 `SharedCard`。

```json
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
```

## 6. 明确禁止写入的字段

下面这些字段不能进入共享协议：

- `showCardNumber`
- `countryRowSpan`
- `showCountry`
- `bankRowSpan`
- `showBank`
- `limitRowSpan`
- `showLimit`
- `interestFreePeriod`
- `createTime`
- `_unknownFields`
- `_extensionFields`
- 平台本地文件路径
- NFC 原始 Tag 数据
- 生物识别配置

## 7. 向后兼容要求

所有端导入时都必须兼容：

1. 旧数组格式

```json
[
  { "id": "1", "country": "中国", "bank": "招商银行", "cardNumber": "6222" }
]
```

2. 新协议对象格式

```json
{
  "schemaVersion": "2.0.0",
  "exportedAt": "2026-03-23 16:00:00",
  "source": "web",
  "cards": []
}
```

导出时统一只导出新协议对象格式。

## 8. 建议的实现方式

每一端都要有独立的：

- `JsonParser`
- `SchemaMigrator`
- `ValueNormalizer`
- `ImportValidator`
- `ExportSerializer`

但它们都要遵守同一份协议文档。

