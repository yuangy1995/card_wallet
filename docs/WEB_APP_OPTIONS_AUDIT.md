# Web / App 选项系统对齐审查

本文档用于梳理 `web` 端和 `app` 端在国家、银行、币种、卡等级等选项系统上的差异，并作为后续统一重构的依据。

## 当前结论

当前两端的选项系统存在的不只是“数据量差异”，而是“选项数据结构、显示规则、存储规则、可扩展方式都不同”。

这会直接影响：

- 新增/编辑时的选项选择体验
- 搜索筛选结果一致性
- 同银行/同地区共享额度判断
- 导入导出后的数据一致性
- 后续 NFC、照片、OCR 等能力的挂载稳定性

## 数量差异

### web 端

- 国家：254
- 银行：193
- 卡等级：38
- 币种：19

来源：`/src/config/creditCardOptions.js`

### app 端

- 国家：34
- 银行：23
- 卡等级：27
- 币种：18
- 年费状态：5

来源：`/src/data/referenceData.ts`

## 结构差异

### 1. 国家

#### web

- 结构：`{ name, chineseName }`
- 存储值：`chineseName`
- 展示值：`中文(英文)`
- 数据非常全，但命名并不完全统一

示例：

- `China / 中国`
- `Hong Kong / 香港特别行政区`
- `Taiwan of China / 台湾`
- `United States of America / 美国`

#### app

- 结构：`{ value, englishName, chineseName }`
- 存储值：`value`
- 当前 `value` 是中文
- 数据量明显少于 web

示例：

- `中国 / China`
- `香港 / Hong Kong`
- `美国 / United States`

#### 问题

- 同一个地区的中文值不一致
  - web: `香港特别行政区`
  - app: `香港`
- 英文值也不一致
  - web: `United States of America`
  - app: `United States`
- app 代码里因此额外维护了手工映射逻辑

### 2. 银行

#### web

- 结构：`{ name, chineseName }`
- 实际上 `name` 和 `chineseName` 基本相同
- 数据量多，但部分数据重复或历史名称混杂

可见问题：

- `美国银行` 出现重复
- `法国兴业银行` 出现重复
- 有大量地方性银行，噪音偏多
- 与 app 端英文别名体系完全脱节

#### app

- 结构：`{ value, englishName, chineseName, emoji? }`
- 存储值：中文名
- 额外支持英文名、缩写匹配和热门项

#### 问题

- app 数量太少，不足以覆盖 web 的真实存量
- web 没有英文名标准层
- 两端都允许创建自定义值，但没有统一落库规则

### 3. 币种

#### web

- 配置文件 `currencyList` 是“显示串”
- 例如：`人民币(CNY)`、`美元(USD)`

但在新增/编辑对话框里又被二次覆盖成另一套临时数组：

- label 使用中文
- value 使用代码

这意味着：

- web 配置文件里的币种表不是唯一真实来源
- 同一个字段在不同页面可能有不同的选项来源

#### app

- 结构更合理：`value=币种代码`
- 显示时可渲染为 `人民币 (CNY)` / `Chinese Yuan (CNY)`

#### 问题

- web 的币种模型和 app 不同
- web 搜索筛选和编辑弹窗未必使用同一套值
- `type` 字段语义是币种，但字段名容易误导

### 4. 卡等级

#### web

- 数量更多
- 包含一些 app 没有的等级，如：
  - `银联-黑钻卡`
  - `JCB-御尊卡`
  - 多个 `AE` 系列扩展等级

#### app

- 数量更少
- 英文别名更完整
- 与 web 不完全一致

#### 问题

- 同一张卡在 web 能选到的等级，app 不一定能选到
- 等级值不统一会导致搜索、展示、统计出现偏差

## 行为差异

### web 端

- `el-select` 普遍开启 `allow-create`
- 用户可直接输入任意国家、银行、等级
- 自定义值并不会进入统一选项中心，只是直接落到数据里

### app 端

- `SmartPicker` 支持：
  - 中英文搜索
  - 缩写搜索
  - 热门项
  - 新建项
  - 标准化映射

但 app 的新建规则与 web 并不一致。

## 主要问题清单

### P1. 选项数据源不唯一

- web 端 `creditCardOptions.js` 不是唯一真实来源
- 币种在对话框里又维护了一套临时数组
- app 端则走 `referenceData.ts + ReferenceDataService`

### P1. 存储值规则不统一

- 国家的中文名存在多种写法
- 银行的中文名和英文别名未统一到同一主表
- 币种在 web 有“显示串”和“代码值”混用

### P1. 两端存在大量手工兼容逻辑

- app 为了兼容 web，额外写了国家/银行映射和缩写匹配
- 这些逻辑本质上是在替代缺失的标准选项字典

### P2. web 数据噪音较高

- 银行列表过大
- 有重复项
- 有历史名称和低频名称混杂

### P2. app 数据覆盖不足

- 国家、银行、等级均小于 web
- 实际会造成“web 已有值，app 无法自然选中或归一”

## 统一重构建议

## 目标

建立一个跨端共享的“参考数据字典”，让两端都从同一个规范文件派生选项。

## 推荐统一模型

### 国家

```ts
type CountryOption = {
  code: string
  value: string
  chineseName: string
  englishName: string
  aliases?: string[]
  enabled?: boolean
}
```

建议：

- `code` 使用稳定代码，如 `CN` / `HK` / `US`
- `value` 作为最终存储值，建议固定为中文标准名
- `aliases` 存放历史值和兼容值

### 银行

```ts
type BankOption = {
  code: string
  value: string
  chineseName: string
  englishName: string
  aliases?: string[]
  tags?: string[]
  enabled?: boolean
}
```

建议：

- `value` 作为统一存储值，固定为标准中文名
- `aliases` 收纳英文名、缩写、旧名称
- `code` 作为未来 NFC / OCR / 照片识别后的映射键

### 币种

```ts
type CurrencyOption = {
  code: string
  value: string
  chineseName: string
  englishName: string
  symbol?: string
  aliases?: string[]
}
```

建议：

- 统一存储 `code`
- `type` 字段短期保留，值只允许 `CNY/USD/HKD` 这类代码
- 不再存储 `人民币(CNY)` 这类显示串

### 卡等级

```ts
type CardLevelOption = {
  code: string
  value: string
  chineseName: string
  englishName: string
  aliases?: string[]
}
```

## 分阶段落地方案

### 第一阶段：先统一选项规范，不改业务逻辑

- 新建一份共享字典文档或 JSON
- 明确国家、银行、币种、卡等级的标准值
- 列出兼容别名

### 第二阶段：让 web 和 app 都从统一字典生成选项

- web 不再手写多套币种数组
- app 不再手工维护额外兜底映射

### 第三阶段：补标准化层

- 导入数据时先标准化
- 手工输入时先尝试映射到标准值
- 只有映射失败时才作为自定义值保存

### 第四阶段：重构共享额度判断

同国家、同银行判断不能再靠页面里手写映射，应改为：

- 先把值标准化为 `countryCode` / `bankCode`
- 再比较标准码

## 我对后续代码改造的建议顺序

1. 先抽出共享参考数据 schema
2. 再统一币种存储值为代码
3. 再统一国家/银行标准值与别名映射
4. 最后再动 app 主数据结构重构

原因：

- 选项系统是字段输入入口
- 如果不先统一输入值，后面的数据结构重构只会把旧问题搬到新模型里

## 本阶段结论

在进行 app 主数据结构重构前，应先完成“选项系统统一”，至少要完成以下三件事：

- 定义跨端共享的国家、银行、币种、卡等级字典
- 统一每类选项的存储值规则
- 去掉两端各自散落的临时选项和手工兼容逻辑

