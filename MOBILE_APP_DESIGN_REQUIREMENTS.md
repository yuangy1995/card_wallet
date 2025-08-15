# 信用卡管理移动应用设计需求文档

## 目录
1. [项目概述](#1-项目概述)
2. [技术架构](#2-技术架构)
3. [数据模型](#3-数据模型)
4. [API接口设计](#4-api接口设计)
5. [用户界面设计](#5-用户界面设计)
6. [功能模块详细设计](#6-功能模块详细设计)
7. [安全与隐私](#7-安全与隐私)
8. [性能要求](#8-性能要求)

## 1. 项目概述

### 1.1 项目背景
基于现有Vue 3信用卡管理Web应用，开发Android和iOS原生移动应用，提供完整的信用卡信息管理、统计分析、数据导入导出等功能。

### 1.2 目标用户
- 个人用户：管理多张信用卡的基本信息、额度、有效期等
- 专业用户：需要详细统计分析信用卡使用情况的用户

### 1.3 核心功能
- 信用卡信息管理（增删改查）
- 数据统计与可视化分析
- 数据导入导出（支持加密）
- 本地数据存储和云端同步
- 智能提醒功能（年费、有效期等）

## 2. 技术架构

### 2.1 推荐技术栈
**Android:**
- 开发语言：Kotlin
- 架构模式：MVVM + Repository Pattern
- UI框架：Jetpack Compose
- 数据库：Room + SQLite
- 网络请求：Retrofit + OkHttp
- 依赖注入：Dagger Hilt
- 图表库：MPAndroidChart

**iOS:**
- 开发语言：Swift
- 架构模式：MVVM + Repository Pattern
- UI框架：SwiftUI
- 数据库：Core Data
- 网络请求：URLSession
- 图表库：Charts

### 2.2 共享组件
- 数据加密/解密模块
- WebDAV同步模块
- 统计计算引擎
- 导入导出处理器

## 3. 数据模型

### 3.1 核心数据结构

#### 信用卡实体 (CreditCard)
```json
{
  "id": "string",
  "country": "string",
  "bank": "string", 
  "cardNumber": "string",
  "alias": "string",
  "level": "string",
  "type": "string",
  "limit": "number",
  "cvv": "string",
  "valid": "string",
  "annualFee": "number",
  "isQualified": "string",
  "nextAnnualFeeCollectionTime": "string",
  "lastTime": "string",
  "accountBillDate": "string",
  "dueDate": "string", 
  "equity": "string",
  "remark": "string",
  "lastModifyTime": "string",
  "createTime": "string"
}
```

### 3.2 本地数据库设计

```sql
CREATE TABLE credit_cards (
    id TEXT PRIMARY KEY,
    country TEXT NOT NULL,
    bank TEXT NOT NULL,
    card_number TEXT NOT NULL,
    alias TEXT,
    level TEXT,
    type TEXT,
    credit_limit REAL,
    cvv TEXT,
    valid_date TEXT,
    annual_fee REAL,
    is_qualified TEXT,
    next_annual_fee_time TEXT,
    last_raise_time TEXT,
    account_bill_date TEXT,
    due_date TEXT,
    equity TEXT,
    remark TEXT,
    last_modify_time TEXT,
    create_time TEXT,
    is_encrypted INTEGER DEFAULT 0
);
```

## 4. API接口设计

### 4.1 数据同步接口
```typescript
interface WebDAVConfig {
  url: string;
  username: string;
  password: string;
  directory: string;
}

interface SyncService {
  uploadData(data: CreditCard[], config: WebDAVConfig): Promise<SyncResult>;
  downloadData(config: WebDAVConfig): Promise<CreditCard[]>;
  checkSyncStatus(config: WebDAVConfig): Promise<SyncStatus>;
}
```

### 4.2 信用卡数据接口
```typescript
interface CreditCardService {
  getAllCards(): Promise<CreditCard[]>;
  getCardById(id: string): Promise<CreditCard>;
  createCard(card: Partial<CreditCard>): Promise<CreditCard>;
  updateCard(id: string, card: Partial<CreditCard>): Promise<CreditCard>;
  deleteCard(id: string): Promise<void>;
  deleteCards(ids: string[]): Promise<void>;
  searchCards(query: SearchQuery): Promise<CreditCard[]>;
}
```

## 5. 用户界面设计

### 5.1 设计原则
- **简洁直观**：界面简洁清晰，操作流程直观
- **安全优先**：敏感信息默认隐藏，支持多级权限控制
- **响应式设计**：适配不同屏幕尺寸和方向
- **无障碍访问**：支持语音朗读、高对比度等无障碍功能

### 5.2 主界面结构
```
┌─────────────────────────────────┐
│           顶部导航栏             │
├─────────────────────────────────┤
│                                │
│           主内容区              │
│                                │
├─────────────────────────────────┤
│          底部标签栏             │
│   [卡片] [统计] [设置] [更多]    │
└─────────────────────────────────┘
```

### 5.3 信用卡列表界面设计
```
┌─────────────────────────────────┐
│  🔍 [搜索框]           [筛选] ➕  │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 🏦 招商银行                  │ │
│ │ 🎴 全币种国际芯片卡 - 金卡    │ │
│ │ 💳 **** **** **** 1234      │ │
│ │ 📅 2025-08  💰 ¥50,000     │ │
│ │ 📊 已达标   ⏰ 30天后收费    │ │
│ └─────────────────────────────┘ │
│                                │
│ ┌─────────────────────────────┐ │
│ │ 🏦 中国银行                  │ │
│ │ 🎴 Visa白金信用卡           │ │
│ │ 💳 **** **** **** 5678      │ │
│ │ 📅 2024-12  💰 $10,000     │ │
│ │ ⚠️  未达标   ⏰ 即将到期     │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

## 6. 功能模块详细设计

### 6.1 信用卡管理模块
- **卡片列表**：支持列表和卡片视图，排序筛选搜索
- **卡片操作**：添加、编辑、删除、复制卡片
- **敏感信息**：卡号CVV默认遮罩，支持一键显示/隐藏
- **批量操作**：支持批量删除、修改达标状态

### 6.2 统计分析模块
- **基础统计**：总卡数、总额度、银行数、年费统计
- **分布分析**：银行、等级、国家、币种分布图表
- **时间分析**：到期提醒、年费提醒、提额历史
- **报表导出**：PDF报告、Excel导出、图表保存

### 6.3 数据管理模块
- **导入功能**：支持JSON、CSV、Excel格式，数据验证
- **导出功能**：多格式导出，支持加密和字段选择
- **备份恢复**：自动备份、手动备份、云端备份
- **同步管理**：WebDAV同步，冲突解决，状态显示

### 6.4 设置管理模块
- **应用设置**：主题、安全、通知、数据设置
- **表格自定义**：列显示、排序、宽度调整
- **提醒设置**：年费、到期提醒的时间和方式设置

## 7. 安全与隐私

### 7.1 数据加密
- **本地加密**：AES-256-GCM算法加密敏感字段
- **传输加密**：HTTPS通信，证书验证
- **密钥管理**：安全的密钥生成和存储

### 7.2 身份认证
- **应用锁**：密码、图案、生物识别
- **权限管理**：敏感操作二次确认
- **会话管理**：自动锁定，会话超时

### 7.3 隐私保护
- **数据最小化**：只收集必要信息
- **防泄露**：截屏保护、复制限制、后台模糊
- **日志安全**：不记录敏感信息

## 8. 性能要求

### 8.1 响应时间
- 应用启动：冷启动≤3秒，热启动≤1秒
- 页面切换：≤500毫秒
- 数据查询：本地查询≤100毫秒
- 同步操作：平均≤10秒

### 8.2 资源使用
- 基础内存：≤50MB
- 峰值内存：≤100MB
- 存储优化：数据压缩、缓存策略
- 电池优化：限制后台活动、智能同步

---

**文档版本**：v1.0  
**创建时间**：基于现有Web项目分析  
**适用平台**：Android、iOS移动应用
