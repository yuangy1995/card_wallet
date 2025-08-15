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

### 2.1 跨平台兼容性要求
**加解密一致性**：
- Web端和移动端必须使用完全相同的加解密算法和实现
- 统一使用AES-256-GCM算法，基于CryptoJS库实现
- 加密前缀标识：`default:`（默认密码）和`encrypted:`（自定义密码）必须保持一致
- 默认密码值在所有平台保持统一：`defAult.@.Password.`

**数据格式兼容性**：
- JSON数据结构必须在所有平台保持一致
- 字段命名采用camelCase格式，与Web端完全一致
- 时间格式统一使用ISO 8601标准（如：2024-12-01）

### 2.2 推荐技术栈
**React Native:**
- 开发语言：TypeScript/JavaScript
- 框架版本：React Native 0.72+
- 架构模式：Redux Toolkit + RTK Query / Zustand
- UI组件库：React Native Elements / NativeBase / Tamagui
- 导航：React Navigation 6+
- 数据库：react-native-sqlite-storage / WatermelonDB
- 本地存储：@react-native-async-storage/async-storage
- 加密库：react-native-crypto-js / crypto-js
- 网络请求：Axios / React Query
- 图表库：react-native-chart-kit / Victory Native
- 文件操作：react-native-fs
- WebDAV：自定义实现或react-native-webdav
- 安全存储：react-native-keychain
- 生物识别：react-native-biometrics

### 2.3 共享组件（React Native）
- **数据加密/解密模块**：使用crypto-js库，与Web端完全一致
- **WebDAV同步模块**：基于react-native-fs和XMLHttpRequest实现
- **统计计算引擎**：使用React Native图表库和计算逻辑
- **导入导出处理器**：支持JSON/CSV格式，使用react-native-share
- **字段兼容性处理器**：TypeScript接口定义，处理版本差异
- **数据完整性保护器**：Redux中间件或Zustand middleware实现
- **本地数据库管理**：SQLite封装层，支持数据迁移
- **安全存储管理**：Keychain封装，统一密钥管理

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
  "createTime": "string",
  "_extensionFields": {
    "version": "1.2.0",
    "fields": {
      "newField1": "value1",
      "newField2": "value2"
    }
  },
  "_unknownFields": {
    // 当前版本不支持但需要保留的字段
  }
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
    is_encrypted INTEGER DEFAULT 0,
    -- 扩展字段支持
    extension_fields TEXT, -- JSON格式存储扩展字段
    unknown_fields TEXT,   -- JSON格式存储未知字段
    data_version TEXT DEFAULT '1.0.0' -- 数据版本标识
);
```

#### 3.2.3 React Native数据库设计

**SQLite实现 (react-native-sqlite-storage)**
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
    is_encrypted INTEGER DEFAULT 0,
    -- 扩展字段支持
    extension_fields TEXT, -- JSON格式存储扩展字段
    unknown_fields TEXT,   -- JSON格式存储未知字段
    data_version TEXT DEFAULT '1.0.0' -- 数据版本标识
);
```

**TypeScript数据模型**
```typescript
interface CreditCard {
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
  equity?: string;
  remark?: string;
  lastModifyTime?: string;
  createTime?: string;
  _extensionFields?: ExtensionFields;
  _unknownFields?: Record<string, any>;
}
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

interface SyncResult {
  success: boolean;
  conflictCount: number;
  preservedFieldsCount: number; // 保留的未知字段数量
  message: string;
}

interface SyncService {
  uploadData(data: CreditCard[], config: WebDAVConfig): Promise<SyncResult>;
  downloadData(config: WebDAVConfig): Promise<CreditCard[]>;
  checkSyncStatus(config: WebDAVConfig): Promise<SyncStatus>;
  // 新增：字段兼容性处理
  mergeWithFieldPreservation(localData: CreditCard[], remoteData: CreditCard[]): CreditCard[];
  validateDataIntegrity(data: CreditCard[]): ValidationResult;
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

### 7.1 数据加密统一标准
#### 7.1.1 加密算法一致性
- **算法标准**：AES-256-GCM，与Web端完全一致
- **实现库**：移动端使用与CryptoJS兼容的加密库
  - Android：使用Java Crypto API或CryptoJS的Java实现
  - iOS：使用CommonCrypto或CryptoJS的Swift/Objective-C实现
- **加密格式**：`prefix:encryptedData`格式与Web端保持一致
  - 默认加密：`default:加密内容`
  - 自定义密码：`encrypted:加密内容`
- **默认密码**：所有平台使用相同默认密码：`defAult.@.Password.`

#### 7.1.2 加密兼容性测试
- **跨平台测试**：确保Web端加密的数据在移动端能正确解密
- **反向测试**：确保移动端加密的数据在Web端能正确解密
- **密钥一致性验证**：定期验证各平台加密密钥的一致性

#### 7.1.3 密钥管理统一
- **本地存储**：使用系统安全存储（Android Keystore / iOS Keychain）
- **传输安全**：HTTPS通信，证书验证
- **密码同步**：支持自定义密码在设备间同步

### 7.2 身份认证
- **应用锁**：密码、图案、生物识别
- **权限管理**：敏感操作二次确认
- **会话管理**：自动锁定，会话超时

### 7.3 隐私保护
- **数据最小化**：只收集必要信息
- **防泄露**：截屏保护、复制限制、后台模糊
- **日志安全**：不记录敏感信息

## 8. 数据兼容性处理

### 8.1 字段扩展处理流程
#### 8.1.1 新字段添加流程
1. **版本标识**：在数据中添加版本号标识
2. **字段映射**：建立新旧字段的映射关系
3. **默认值处理**：为新字段提供合理的默认值
4. **向下兼容**：确保旧版本能安全忽略新字段

#### 8.1.2 数据迁移策略
```typescript
interface FieldMigration {
  fromVersion: string;
  toVersion: string;
  migrations: FieldMapping[];
}

interface FieldMapping {
  oldField?: string;
  newField: string;
  defaultValue: any;
  transform?: (oldValue: any) => any;
}
```

#### 8.1.3 兼容性检查
- **启动检查**：应用启动时检查数据版本兼容性
- **同步检查**：数据同步前进行版本兼容性验证
- **降级处理**：高版本数据在低版本设备上的安全处理

### 8.2 实际应用场景
#### 8.2.1 场景1：Web端新增字段
- Web端添加新字段（如：`creditScore: number`）
- 移动端同步时将新字段存入`_unknownFields`
- 移动端修改数据后同步，保留新字段不丢失
- Web端接收数据后能正常显示新字段内容

#### 8.2.2 场景2：移动端独有功能
- 移动端支持某些Web端不支持的字段（如：`gpsLocation`）
- 数据同步到Web端时，Web端将其存入`_unknownFields`
- Web端修改数据后同步，移动端独有字段不丢失

#### 8.2.3 场景3：版本降级
- 用户从新版本降级到旧版本
- 旧版本能安全处理新版本的数据
- 重要数据不丢失，待升级后可恢复

## 9. 性能要求

### 9.1 响应时间
- 应用启动：冷启动≤3秒，热启动≤1秒
- 页面切换：≤500毫秒
- 数据查询：本地查询≤100毫秒
- 同步操作：平均≤10秒

### 9.2 资源使用
- 基础内存：≤50MB
- 峰值内存：≤100MB
- 存储优化：数据压缩、缓存策略
- 电池优化：限制后台活动、智能同步

## 10. 开发实施指导

### 10.1 React Native加密模块实现

#### 安装依赖
```bash
npm install crypto-js
npm install react-native-keychain
# 或者
yarn add crypto-js
yarn add react-native-keychain
```

#### 加密管理器实现
```typescript
import CryptoJS from 'crypto-js';
import * as Keychain from 'react-native-keychain';

class CryptoManager {
  private static readonly DEFAULT_PASSWORD = 'defAult.@.Password.';
  private static readonly KEYCHAIN_SERVICE = 'CreditCardApp';

  static encrypt(data: string, password: string = this.DEFAULT_PASSWORD): string {
    try {
      const jsonString = JSON.stringify(data);
      const encrypted = CryptoJS.AES.encrypt(jsonString, password).toString();
      const prefix = password === this.DEFAULT_PASSWORD ? 'default:' : 'encrypted:';
      return `${prefix}${encrypted}`;
    } catch (error) {
      throw new Error('加密失败');
    }
  }

  static decrypt(encryptedData: string, password?: string): string {
    try {
      if (!encryptedData.startsWith('encrypted:') && !encryptedData.startsWith('default:')) {
        throw new Error('不是有效的加密数据');
      }
      
      const isDefaultEncryption = encryptedData.startsWith('default:');
      const actualPassword = isDefaultEncryption ? this.DEFAULT_PASSWORD : password;
      
      if (!isDefaultEncryption && !password) {
        throw new Error('请输入解密密码');
      }
      
      const prefixLength = isDefaultEncryption ? 8 : 10;
      const actualEncryptedData = encryptedData.substring(prefixLength);
      
      const decrypted = CryptoJS.AES.decrypt(actualEncryptedData, actualPassword!);
      const jsonString = decrypted.toString(CryptoJS.enc.Utf8);
      
      if (!jsonString) {
        throw new Error('解密失败，请检查密码是否正确');
      }
      
      return JSON.parse(jsonString);
    } catch (error) {
      throw new Error('解密失败，请检查密码是否正确');
    }
  }

  // 安全存储自定义密码
  static async storeCustomPassword(password: string): Promise<void> {
    await Keychain.setInternetCredentials(this.KEYCHAIN_SERVICE, 'customPassword', password);
  }

  // 获取自定义密码
  static async getCustomPassword(): Promise<string | null> {
    try {
      const credentials = await Keychain.getInternetCredentials(this.KEYCHAIN_SERVICE);
      if (credentials && credentials.password) {
        return credentials.password;
      }
      return null;
    } catch (error) {
      return null;
    }
  }
}

export default CryptoManager;
```

### 10.2 React Native数据兼容性处理

#### 数据库服务实现
```typescript
import SQLite from 'react-native-sqlite-storage';

class DatabaseService {
  private db: SQLite.SQLiteDatabase | null = null;

  async initialize(): Promise<void> {
    this.db = await SQLite.openDatabase(
      { name: 'CreditCards.db', location: 'default' },
      () => console.log('Database opened'),
      error => console.error('Database error:', error)
    );
    
    await this.createTables();
  }

  private async createTables(): Promise<void> {
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS credit_cards (
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
        is_encrypted INTEGER DEFAULT 0,
        extension_fields TEXT,
        unknown_fields TEXT,
        data_version TEXT DEFAULT '1.0.0'
      )
    `;
    
    await this.db?.executeSql(createTableQuery);
  }
}

// 数据兼容性处理器
class DataCompatibilityHandler {
  static processIncomingData(rawData: any): CreditCard {
    const knownFields: Partial<CreditCard> = {
      id: rawData.id,
      country: rawData.country,
      bank: rawData.bank,
      cardNumber: rawData.cardNumber,
      // ... 其他已知字段
    };

    // 处理未知字段
    const unknownFields: Record<string, any> = {};
    Object.keys(rawData).forEach(key => {
      if (!(key in knownFields) && !key.startsWith('_')) {
        unknownFields[key] = rawData[key];
      }
    });

    return {
      ...knownFields,
      _unknownFields: Object.keys(unknownFields).length > 0 ? unknownFields : undefined
    } as CreditCard;
  }

  static prepareOutgoingData(creditCard: CreditCard): any {
    const { _unknownFields, _extensionFields, ...knownData } = creditCard;
    
    return {
      ...knownData,
      ...(_unknownFields || {}),
      ...(_extensionFields?.fields || {})
    };
  }

  static mergeUnknownFields(local: CreditCard, remote: any): CreditCard {
    const remoteUnknown = this.extractUnknownFields(remote);
    const localUnknown = local._unknownFields || {};
    
    return {
      ...local,
      _unknownFields: { ...localUnknown, ...remoteUnknown }
    };
  }

  private static extractUnknownFields(data: any): Record<string, any> {
    const knownFieldNames = [
      'id', 'country', 'bank', 'cardNumber', 'alias', 'level', 'type',
      'limit', 'cvv', 'valid', 'annualFee', 'isQualified', 
      'nextAnnualFeeCollectionTime', 'lastTime', 'accountBillDate',
      'dueDate', 'equity', 'remark', 'lastModifyTime', 'createTime'
    ];
    
    const unknownFields: Record<string, any> = {};
    Object.keys(data).forEach(key => {
      if (!knownFieldNames.includes(key) && !key.startsWith('_')) {
        unknownFields[key] = data[key];
      }
    });
    
    return unknownFields;
  }
}
```

### 10.3 React Native测试策略

#### 单元测试（Jest + React Native Testing Library）
```bash
npm install --save-dev @testing-library/react-native jest
```

```typescript
// __tests__/CryptoManager.test.ts
import CryptoManager from '../src/services/CryptoManager';

describe('CryptoManager', () => {
  test('encrypt and decrypt with default password', () => {
    const testData = { test: 'data' };
    const encrypted = CryptoManager.encrypt(JSON.stringify(testData));
    const decrypted = CryptoManager.decrypt(encrypted);
    expect(JSON.parse(decrypted)).toEqual(testData);
  });

  test('cross-platform compatibility', () => {
    // 使用Web端加密的数据进行测试
    const webEncryptedData = 'default:U2FsdGVkX1...';
    const decrypted = CryptoManager.decrypt(webEncryptedData);
    expect(decrypted).toBeDefined();
  });
});
```

#### E2E测试（Detox）
```bash
npm install --save-dev detox
```

#### 测试覆盖重点
1. **加密兼容性测试**：与Web端CryptoJS的互操作性
2. **数据库操作测试**：SQLite CRUD操作和数据迁移
3. **字段扩展测试**：模拟版本升级和降级场景
4. **WebDAV同步测试**：网络请求和数据完整性
5. **UI组件测试**：关键界面和用户交互
6. **安全存储测试**：Keychain操作和密码管理

---

**文档版本**：v3.0  
**更新时间**：基于React Native技术栈调整  
**更新内容**：
- 将原生开发方案调整为React Native跨平台开发
- 更新技术栈推荐和依赖库选择
- 提供React Native特定的加密实现方案
- 调整数据库方案为SQLite + TypeScript
- 更新测试策略以适应React Native开发
- 保持与Web端的完全兼容性设计

**适用平台**：React Native（Android、iOS跨平台应用）
**Node.js版本要求**：16.x以上  
**React Native版本要求**：0.72以上
