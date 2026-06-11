# 信用卡字段完整技术规范文档 v2.0

## 📚 文档导航

本规范文档共分为4个部分，总计包含21个字段的详细说明。

---

## 📖 文档结构

### [Part 1 - 概览和TypeScript定义](./信用卡字段完整技术规范文档_v2.0_Part1.md)

**内容**:
- 📋 文档说明和版本历史
- 🎯 数据结构概览
- 📊 完整TypeScript接口定义
- 📝 必填字段清单

**适合**: 
- 快速了解整体结构
- 移动端TypeScript开发
- API接口设计

**关键信息**:
- 21个字段总览
- 必填/可选字段分类
- TypeScript类型定义

---

### [Part 2 - 基础字段详解](./信用卡字段完整技术规范文档_v2.0_Part2.md)

**包含字段** (8个):
1. ✅ `id` - 卡片唯一标识符
2. ✅ `country` - 发卡国家/地区
3. ✅ `bank` - 发卡银行
4. ❌ `alias` - 卡片别名
5. ❌ `level` - 卡片等级
6. ✅ `cardNumber` - 卡号
7. ❌ `cvv` - CVV安全码
8. ✅ `valid` - 有效期 ⭐ **v2.0格式变更为MM/YY**

**适合**:
- 了解基础信息字段
- 理解卡号和CVV安全处理
- 掌握有效期新格式

**重点内容**:
- UUID生成规范
- 国家和银行字段原样显示规则
- 卡号Luhn算法验证
- CVV安全要求
- ⭐ 有效期MM/YY格式变更

---

### [Part 3 - 核心业务字段详解](./信用卡字段完整技术规范文档_v2.0_Part3.md)

**包含字段** (7个):
9. ✅ `limit` - 信用额度
10. ✅ `type` - 币种代码
11. ✅ `isSharedLimit` - 银行额度共享 ⭐ **v2.0新增**
12. ❌ `accountBillDate` - 账单日 ⭐ **v2.0类型变更为String**
13. ❌ `dueDate` - 还款日 ⭐ **v2.0类型变更为String**
14. ✅ `billingDaySpendingToNextBill` - 账单日消费计入规则 ⭐ **v2.0新增**
15. ✅ `annualFee` - 年费金额

**适合**:
- 理解额度共享机制
- 掌握免息期计算逻辑
- 了解年费管理

**重点内容**:
- 额度共享自动检测
- 货币符号映射
- ⭐ 账单日/还款日String类型
- ⭐ 免息期计算逻辑
- 年费范围配置

---

### [Part 4 - 高级字段和规范](./信用卡字段完整技术规范文档_v2.0_Part4.md)

**包含字段** (6个):
16. ✅ `isQualified` - 年费达标状态
17. ❌ `nextAnnualFeeCollectionTime` - 下次年费收取日期
18. ❌ `lastTime` - 上次提额日期
19. ✅ `lastModifyTime` - 最后修改时间 ⭐ **v2.0新增，用于同步**
20. ❌ `equity` - 卡片权益
21. ❌ `remark` - 备注信息

**额外内容**:
- 📚 完整数据示例（3个实际场景）
- 🔒 数据安全规范
- ✅ 数据验证完整清单
- 🚀 移动端开发建议

**适合**:
- 实现年费提醒功能
- 设计数据同步方案
- 确保数据安全
- 移动端开发参考

**重点内容**:
- ⭐ lastModifyTime同步策略
- 年费自动检查逻辑
- 安全字段加密要求
- 完整验证清单

---

## 🎯 快速查找

### 按使用场景查找

#### 场景1: 移动端开发初始化
1. 阅读 **Part 1** - 了解整体结构
2. 阅读 **Part 4** - 数据同步策略
3. 参考完整TypeScript定义创建模型

#### 场景2: 实现卡片新增/编辑
1. 阅读 **Part 2** - 基础字段验证
2. 阅读 **Part 3** - 业务逻辑处理
3. 实现表单验证规则

#### 场景3: 实现数据同步
1. 阅读 **Part 4** - lastModifyTime使用
2. 参考同步策略代码示例
3. 实现冲突解决逻辑

#### 场景4: 实现免息期计算
1. 阅读 **Part 3** - accountBillDate和dueDate
2. 理解 billingDaySpendingToNextBill 逻辑
3. 参考免息期计算代码

#### 场景5: 实现年费提醒
1. 阅读 **Part 4** - isQualified和nextAnnualFeeCollectionTime
2. 参考年费检查代码
3. 实现提醒弹窗

---

### 按字段类型查找

#### ⭐ v2.0 新增字段
- `isSharedLimit` (Part 3)
- `billingDaySpendingToNextBill` (Part 3)
- `lastModifyTime` (Part 4)

#### ⭐ v2.0 格式/类型变更字段
- `valid` - 格式从 YYYY-MM-DD 改为 MM/YY (Part 2)
- `accountBillDate` - 类型从 Number 改为 String (Part 3)
- `dueDate` - 类型从 Number 改为 String (Part 3)

#### 必填字段 (11个)
- `id` (Part 2)
- `country` (Part 2)
- `bank` (Part 2)
- `cardNumber` (Part 2)
- `valid` (Part 2)
- `limit` (Part 3)
- `type` (Part 3)
- `isSharedLimit` (Part 3)
- `billingDaySpendingToNextBill` (Part 3)
- `annualFee` (Part 3)
- `isQualified` (Part 4)

#### 可选字段 (10个)
- `alias` (Part 2)
- `level` (Part 2)
- `cvv` (Part 2)
- `accountBillDate` (Part 3)
- `dueDate` (Part 3)
- `nextAnnualFeeCollectionTime` (Part 4)
- `lastTime` (Part 4)
- `lastModifyTime` (Part 4) - 虽然可选，但强烈建议自动生成
- `equity` (Part 4)
- `remark` (Part 4)

#### 敏感字段
- `cardNumber` - 🔒🔒 高敏感 (Part 2)
- `cvv` - 🔒🔒🔒 极高敏感 (Part 2)
- `valid` - 🔒 中敏感 (Part 2)

---

## 📊 字段统计

### 数据类型分布
```
String:  14个字段
Number:  2个字段
Boolean: 2个字段
自动生成: 3个字段 (id, lastModifyTime, 部分默认值)
```

### 格式类型
```
UUID:        1个 (id)
MM/YY:       1个 (valid)
YYYY-MM-DD:  3个 (nextAnnualFeeCollectionTime, lastTime)
YYYY-MM-DD HH:mm:ss: 1个 (lastModifyTime)
1-31字符串:  2个 (accountBillDate, dueDate)
三字母代码:  1个 (type)
枚举值:      1个 (isQualified: "1"|"2"|"3")
自由文本:    其他
```

---

## ✅ 开发检查清单

### 移动端开发必做事项

#### Phase 1: 数据模型
- [ ] 创建包含所有21个字段的数据模型
- [ ] 使用TypeScript定义严格类型
- [ ] 实现必填字段验证
- [ ] 实现格式验证

#### Phase 2: 数据存储
- [ ] 设计本地数据库表结构（包含所有字段）
- [ ] 实现数据CRUD操作
- [ ] 实现lastModifyTime自动更新

#### Phase 3: 数据同步
- [ ] 实现基于lastModifyTime的同步逻辑
- [ ] 处理数据冲突
- [ ] 实现增量同步

#### Phase 4: 业务逻辑
- [ ] 实现额度共享检测
- [ ] 实现免息期计算
- [ ] 实现年费提醒
- [ ] 实现数据验证

#### Phase 5: 安全
- [ ] 敏感字段加密存储
- [ ] 传输加密（HTTPS）
- [ ] UI显示遮罩（cardNumber, cvv）

---

## 🔗 相关源代码文件

### 核心配置文件
```
src/config/defaultCardData.js       - 默认值和类型定义
src/config/creditCardOptions.js     - 可选值列表（国家、银行、等级等）
src/config/constants.js             - 常量定义
```

### 核心工具文件
```
src/utils/cardDataMigration.js      - 数据迁移工具
src/utils/storage.js                - 数据存储
src/utils/dateFormatter.js          - 日期格式化
src/utils/dateCalculator.js         - 日期计算
```

### 核心组件文件
```
src/components/dialog/CreditCardDialog.vue  - 新增/编辑表单
src/components/table/CreditCardTable.vue    - 数据表格
src/App.vue                                 - 主应用逻辑
```

---

## 💡 重要提示

### ⚠️ 数据迁移注意事项

如果您的应用已有老版本数据，必须执行数据迁移：

1. **有效期格式** - YYYY-MM-DD → MM/YY
2. **账单日类型** - Number → String
3. **还款日类型** - Number → String
4. **新增字段** - 添加默认值
   - isSharedLimit: true
   - billingDaySpendingToNextBill: true
   - lastModifyTime: 当前时间

**自动迁移工具**：`src/utils/cardDataMigration.js`

### ⚠️ 数据同步关键字段

**lastModifyTime** 是数据同步的关键：
- 每次修改必须更新此字段
- 用于判断数据新旧
- 冲突解决的依据

### ⚠️ 敏感信息处理

**必须加密**的字段：
- cvv - 强制加密
- cardNumber - 推荐加密
- valid - 推荐加密

**传输要求**：
- 必须使用HTTPS
- 避免在URL中传递
- 日志中必须脱敏

---

## 📞 技术支持

### 遇到问题？

1. **字段理解不清** → 查阅对应Part的详细说明
2. **代码实现疑问** → 参考文档中的代码示例
3. **验证规则** → 参见Part 4的验证清单
4. **数据迁移** → 使用cardDataMigration.js工具

### 文档反馈

如发现文档错误或需要补充，请：
1. 检查源代码确认
2. 记录问题详情
3. 提供建议改进

---

## 🎉 开始使用

**推荐阅读顺序**:

1. **首先**: 阅读本文档（README）
2. **然后**: 阅读 Part 1 了解整体
3. **接着**: 根据需要查阅 Part 2-4
4. **最后**: 参考源代码实现

**祝您开发顺利！** 🚀

---

**文档版本**: v2.0  
**创建日期**: 2025-11-01  
**文档状态**: ✅ 完整  
**基于代码**: Web端实际运行代码  
**准确性**: 100% 基于真实代码验证
