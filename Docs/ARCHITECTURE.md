# macOS 架构设计

## 目标

- 作为你常用桌面端
- 优先提供高效率管理与同步能力
- 兼容后续多窗口、侧边栏、拖拽导入

## 分层

### App

- Scene 管理
- Menu Commands
- 快捷键
- 依赖注入

### Domain

- 与 iOS 同概念模型
- 保持协议和字段完全一致

### Data

- SQLite
- 导入导出
- WebDAV / 本地文件同步
- Migration

### Platform

- 文件拖拽
- Finder 集成
- 安全范围书签
- 菜单栏能力

### Features

- 主表格页
- 详情侧栏
- 编辑弹窗
- 导入导出页
- 设置页
- 统计页

## 初始化目录建议

- `App/Bootstrap`
- `App/Commands`
- `App/Navigation`
- `Domain/Models`
- `Data/Database`
- `Data/Sync`
- `Platform/FileAccess`
- `Features/Dashboard`
- `Features/CardTable`
- `Features/CardEditor`
- `Features/Settings`

