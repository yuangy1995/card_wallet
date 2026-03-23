# credit_card_iOS

原生 `iOS` 客户端初始化目录。

当前阶段只完成：

- 目录骨架
- 架构文档
- 模块划分

当前不包含：

- 业务代码
- Xcode 工程文件
- UI 实现

## 本项目文档

- [MULTI_CLIENT_FOUNDATION.md](/Users/yuangy/Downloads/applist/credit_card_iOS/Docs/MULTI_CLIENT_FOUNDATION.md)
- [SHARED_JSON_PROTOCOL.md](/Users/yuangy/Downloads/applist/credit_card_iOS/Docs/SHARED_JSON_PROTOCOL.md)
- [SHARED_JSON_SCHEMA.json](/Users/yuangy/Downloads/applist/credit_card_iOS/Docs/SHARED_JSON_SCHEMA.json)
- [DATA_FLOW.md](/Users/yuangy/Downloads/applist/credit_card_iOS/Docs/DATA_FLOW.md)
- [AI_DEVELOPMENT_GUIDE.md](/Users/yuangy/Downloads/applist/credit_card_iOS/Docs/AI_DEVELOPMENT_GUIDE.md)
- [ARCHITECTURE.md](/Users/yuangy/Downloads/applist/credit_card_iOS/Docs/ARCHITECTURE.md)

## 推荐技术栈

- `Swift`
- `SwiftUI`
- `SQLite` 或 `GRDB`
- `CryptoKit`
- `LocalAuthentication`
- `CoreNFC`
- `PhotosUI`

## 目录说明

- `Docs`：架构与规范
- `App`：应用入口与依赖装配
- `Domain`：实体、用例、协议
- `Data`：数据库、同步、仓储
- `Platform`：NFC、照片、生物识别、文件系统
- `Features`：按功能拆分的界面模块
- `Resources`：资源与配置
- `Tests`：单元测试与集成测试
