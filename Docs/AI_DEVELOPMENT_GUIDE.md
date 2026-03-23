# iOS 开工文档

## 1. 项目目标

本项目是 `iOS` 原生客户端，必须使用：

- `Swift`
- `SwiftUI`
- 原生 iOS 能力

禁止改成：

- React Native
- Flutter
- UIKit 为主的新工程

## 2. 开发总原则

1. 先遵守文档，再写代码
2. 共享数据只围绕 `SharedCard`
3. 平台能力不允许污染共享模型
4. UI 层不能直接操作数据库
5. 导入导出必须遵守 `SHARED_JSON_PROTOCOL.md`

## 3. 目录职责

- `App`：应用入口、依赖注入、导航壳
- `Features`：页面和对应 ViewModel
- `Domain`：实体、协议、用例
- `Data`：数据库、仓储、同步、迁移
- `Platform`：NFC、照片、生物识别、文件系统
- `Resources`：plist、资源、字符串
- `Tests`：单测和集成测试

## 4. 必须遵守的架构约束

### 4.1 依赖方向

- `Features -> Domain`
- `Data -> Domain`
- `Platform -> Data/Domain`
- `App -> 所有模块`

禁止：

- `Domain` 依赖 `SwiftUI`
- `Features` 直接写 SQL
- `Platform` 直接修改 View 状态

### 4.2 模型约束

- `SharedCard` 只放共享字段
- `ClientMeta` 不导出到共享 JSON
- `Asset` 不直接塞进 `SharedCard`
- `DerivedView` 不落库

### 4.3 时间和格式

- 时间：`YYYY-MM-DD HH:mm:ss`
- 日期：`YYYY-MM-DD`
- 有效期：`MM/YY`
- 卡号：内部建议纯数字

## 5. 开发顺序

1. 建立 `Domain` 模型和协议
2. 建立 JSON 导入导出解析器
3. 建立 SQLite 层
4. 建立列表页
5. 建立详情页
6. 建立编辑页
7. 接入文件导入导出
8. 最后接 NFC、照片、生物识别

## 6. 导入开发要求

- 必须支持旧数组格式
- 必须支持新协议对象格式
- 必须有 `parse / normalize / migrate / validate`
- 导入失败必须给出可读错误

## 7. 导出开发要求

- 只能导出统一协议
- `source` 固定写 `ios`
- 不导出平台本地字段
- 不导出 UI 派生字段

## 8. UI 开发要求

- 先保证信息结构正确，再做视觉优化
- 表单页必须显式标注必填项
- 敏感字段提供显示/隐藏控制
- 颜色和状态要和数据语义对应

## 9. 代码风格要求

- 优先小文件、小类型
- 一个文件只做一件核心事
- 不写超大 View
- 不把业务逻辑塞进 SwiftUI View

## 10. 后续 AI 编码要求

- 任何改动先看 `Docs` 目录
- 先补模型和协议，再补界面
- 不允许自行新增共享字段而不更新协议文档
- 不允许把临时调试字段写进共享 JSON

