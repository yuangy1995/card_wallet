# macOS 数据流

## 1. 总体目标

`macOS` 端是高效率桌面管理端，数据流必须接近 `web`，但内部仍严格区分：

- `SharedCard`
- `ClientMeta`
- `Asset`
- `DerivedView`

## 2. 导入流程

1. 用户拖拽或选择 JSON 文件
2. `FileAccessService` 读取内容
3. `JsonParser` 解析顶层协议
4. `SchemaMigrator` 迁移旧版本
5. `ValueNormalizer` 统一字段值
6. `ImportValidator` 校验格式
7. 写入 `shared_cards`
8. 写入本地 `card_client_meta`
9. 刷新主表格

## 3. 展示流程

1. 主表读取 `SharedCard`
2. 侧栏或详情弹窗补充 `ClientMeta` 与 `Asset`
3. ViewModel 计算派生字段
4. SwiftUI 或 AppKit 补充控件渲染

## 4. 编辑流程

1. 表格行编辑或弹窗编辑
2. 生成新的 `SharedCard`
3. 更新 `lastModifyTime`
4. 写回数据库
5. 触发统计与分组刷新

## 5. 导出流程

1. 查询全部 `SharedCard`
2. 组装统一协议
3. `source = macos`
4. 导出到用户选择目录

## 6. 本地扩展能力

### 文件拖拽

- 仅改变导入入口
- 不改变共享协议

### 快捷键

- 仅改变触发方式
- 不改变数据流

## 7. 冲突处理

1. 按 `id` 匹配
2. 比较 `lastModifyTime`
3. 新版本覆盖旧版本
4. 本地扩展数据保持本地

