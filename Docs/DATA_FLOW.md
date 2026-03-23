# iOS 数据流

## 1. 总体目标

`iOS` 端的数据流必须围绕统一协议运行，但落地时要区分：

- `SharedCard`
- `ClientMeta`
- `Asset`
- `DerivedView`

## 2. 导入流程

1. 用户选择 JSON 文件
2. `FileImporter` 读取文本内容
3. `JsonParser` 解析顶层对象或旧数组
4. `SchemaMigrator` 根据 `schemaVersion` 迁移
5. `ValueNormalizer` 统一国家、银行、币种、日期、布尔值
6. `ImportValidator` 校验必填字段和格式
7. `SharedCardRepository` 写入主表
8. `ClientMetaRepository` 为新卡补 `createTime`
9. UI 刷新列表

## 3. 落库拆分

### SharedCard

写入 `shared_cards`

### ClientMeta

写入 `card_client_meta`

### Asset

写入 `card_assets`

### DerivedView

不落库，界面层计算

## 4. 展示流程

1. 列表页读取 `SharedCard`
2. 详情页读取 `SharedCard + ClientMeta + Asset`
3. ViewModel 计算 `DerivedView`
4. SwiftUI 渲染

## 5. 编辑流程

1. UI 编辑表单
2. ViewModel 生成更新后的 `SharedCard`
3. 更新 `lastModifyTime`
4. 写回 `shared_cards`
5. 不修改 `ClientMeta`，除非本地专属字段变化

## 6. 导出流程

1. 查询全部 `SharedCard`
2. 组装统一协议对象
3. 写入：
   - `schemaVersion`
   - `exportedAt`
   - `source = ios`
   - `cards`
   - `deletedCardIds`
4. 不导出 `ClientMeta`
5. 不导出 `Asset`
6. 不导出 `DerivedView`

## 7. NFC 与照片

### NFC

- 读取后先写本地 `ClientMeta` 或独立绑定表
- 不直接进入 `SharedCard`

### 照片

- 拍摄或选择后写 `Asset`
- 主卡片对象只保留关联关系

## 8. 冲突处理

1. 按 `id` 匹配
2. 比较 `lastModifyTime`
3. 时间新的覆盖旧的
4. 本地能力字段不参与共享冲突

