# iOS 架构设计

## 目标

- 作为第一优先级原生客户端
- 重点覆盖查看、编辑、拍照、NFC、本地隐私保护
- 与 web 使用统一协议

## 架构分层

### App

- App 生命周期
- 依赖注入
- 路由入口
- 环境配置

### Domain

- `SharedCard`
- `CardAsset`
- `CardClientMeta`
- UseCase
- Repository Protocol

### Data

- SQLite 持久化
- 导入导出
- 同步协议解析
- Migration Pipeline

### Platform

- `CoreNFC`
- `PhotosUI`
- `LocalAuthentication`
- Keychain
- 文件选择器

### Features

- 卡片列表
- 卡片详情
- 卡片编辑
- 导入导出
- 设置
- 统计

## 推荐模块边界

- `Features` 只能依赖 `Domain`
- `Data` 实现 `Domain` 的仓储协议
- `Platform` 由 `Data` 或 `App` 注入

## 初始化阶段目录

- `App/Bootstrap`
- `App/Navigation`
- `Domain/Models`
- `Domain/UseCases`
- `Domain/Repositories`
- `Data/Database`
- `Data/Sync`
- `Data/Migrations`
- `Platform/NFC`
- `Platform/Biometrics`
- `Platform/Photos`
- `Platform/FileIO`
- `Features/CardList`
- `Features/CardDetail`
- `Features/CardEditor`
- `Features/Settings`
- `Features/ImportExport`

