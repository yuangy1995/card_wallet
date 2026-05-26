import SwiftUI

public struct CardEditView: View {
    @Environment(\.dismiss) var dismiss
    
    // 监听自动锁定状态
    @State private var lockManager = AutoLockManager.shared
    
    public var mode: String // "add" 或 "edit"
    public var cardToEdit: SharedCard?
    public var existingCards: [SharedCard]
    
    public var onSubmit: (SharedCard) -> Void
    
    // 💡 表单数据绑定 (对齐 SharedCard)
    @State private var country = "中国"
    @State private var bank = "招商银行"
    @State private var cardNumber = ""
    @State private var alias = ""
    @State private var level = "银联-金卡"
    @State private var type = "CNY"
    @State private var limit = 0.0
    @State private var cvv = ""
    @State private var valid = ""
    @State private var annualFee = 0.0
    @State private var isQualified = "2" // 默认未达标
    @State private var nextAnnualFeeCollectionTime = Date()
    @State private var isUltimateFreeFee = false // 终身免年费开关
    @State private var lastTime = Date()
    @State private var accountBillDate = "10"
    @State private var dueDate = "28"
    @State private var billingDaySpendingToNextBill = true
    @State private var equity = ""
    @State private var remark = ""
    @State private var isSharedLimit = true
    
    // 💡 焦点流动状态，符合人类的 Tab 键操作逻辑
    enum Field: Hashable {
        case cardNumber, alias, cvv, limit, annualFee, billDate, dueDate, equity, remark
    }
    @FocusState private var focusedField: Field?
    
    // 💡 共享额度联动提示
    @State private var existingSharedCard: SharedCard? = nil
    
    // 预置选项参考数据 (100% 完美同步 Vue 3 Web 端 referenceData.js 定义)
    let countries = [
        "中国", "香港特别行政区", "澳门特别行政区", "台湾", "美国", "英国", "新加坡",
        "德国", "日本", "韩国", "澳大利亚", "加拿大", "法国", "意大利", "西班牙",
        "荷兰", "瑞士", "泰国", "马来西亚", "印度尼西亚", "菲律宾", "越南", "印度",
        "巴西", "阿根廷", "墨西哥", "俄罗斯", "南非", "土耳其", "沙特阿拉伯", "阿联酋",
        "以色列", "埃及", "新西兰"
    ]
    let banks = [
        "工商银行", "建设银行", "农业银行", "中国银行", "交通银行", "邮储银行", "招商银行",
        "中信银行", "光大银行", "华夏银行", "民生银行", "平安银行", "兴业银行", "浦发银行",
        "广发银行", "北京银行", "宁波银行", "江苏银行", "汇丰银行", "渣打银行", "花旗银行",
        "东亚银行", "恒生银行", "星展银行", "美国银行", "摩根大通银行", "德意志银行",
        "华侨银行", "众安银行", "招商永隆银行"
    ]
    let levels = [
        "银联-普卡", "银联-金卡", "银联-白金卡", "银联-钻石卡", "银联-黑钻卡",
        "银联 + VISA", "银联 + MasterCard", "银联 + JCB", "银联 + AE",
        "VISA-普卡", "VISA-金卡", "VISA-白金卡", "VISA-御玺卡", "VISA-无限卡",
        "MasterCard-普卡", "MasterCard-金卡", "MasterCard-白金卡", "MasterCard-钛金卡",
        "MasterCard-世界卡", "MasterCard-世界之极卡",
        "JCB-普卡", "JCB-金卡", "JCB-白金卡", "JCB-御尊卡",
        "AE-经典-绿卡", "AE-经典-红卡", "AE-经典-金卡", "AE-经典-蓝卡",
        "AE-经典-新贵白金卡", "AE-经典-clear卡", "AE-经典-Explorer卡",
        "AE-经典-Cash Magnet卡", "AE-经典-百夫长白金卡", "AE-经典-百夫长黑金卡",
        "AE-蓝盒子-MEMBER卡", "AE-蓝盒子-SELECT卡", "AE-蓝盒子-MAX卡", "AE-蓝盒子-ICON卡"
    ]
    let currencies = [
        "CNY", "CNH", "USD", "EUR", "GBP", "JPY", "HKD", "MOP", "TWD", "SGD",
        "AUD", "CAD", "CHF", "SEK", "DKK", "NOK", "NZD", "KRW", "THB", "MYR",
        "IDR", "VND", "PHP", "INR"
    ]
    
    public init(
        mode: String,
        cardToEdit: SharedCard? = nil,
        existingCards: [SharedCard],
        onSubmit: @escaping (SharedCard) -> Void
    ) {
        self.mode = mode
        self.cardToEdit = cardToEdit
        self.existingCards = existingCards
        self.onSubmit = onSubmit
    }
    
    public var body: some View {
        ZStack {
            if lockManager.isLocked {
                // 💡 超时防窥锁屏罩层 (Sheet 内部屏障，防止 Sheet 浮在主锁屏之上导致数据泄露)
                LockScreenView()
                    .transition(.opacity)
            } else {
                NavigationStack {
                    Form {
                        // Section 1: 🌏 国家与银行
                        Section(header: Text("🌏 基础属性")) {
                            Picker("国家/地区", selection: $country) {
                                ForEach(countries, id: \.self) { c in
                                    Text(c).tag(c)
                                }
                            }
                            .pickerStyle(.menu)
                            
                            Picker("发卡银行", selection: $bank) {
                                ForEach(banks, id: \.self) { b in
                                    Text(b).tag(b)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: bank) { _, _ in
                                checkExistingSharedLimit()
                            }
                            
                            Picker("卡片等级", selection: $level) {
                                ForEach(levels, id: \.self) { l in
                                    Text(l).tag(l)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // Section 2: 💳 卡号与防窥
                        Section(header: Text("💳 卡号安全")) {
                            HStack {
                                TextField("信用卡号", text: $cardNumber, prompt: Text("输入 13-19 位信用卡号"))
                                    .focused($focusedField, equals: .cardNumber)
                                    .onChange(of: cardNumber) { _, newValue in
                                        let cleaned = newValue.replacingOccurrences(of: " ", with: "")
                                        let digitsOnly = String(cleaned.prefix(19)).replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                                        self.cardNumber = formatCardNumber(digitsOnly)
                                        checkExistingSharedLimit()
                                    }
                                
                                CardBrandIcon(brand: CardBrand.detect(from: cardNumber, level: level))
                                    .frame(width: 48)
                            }
                            
                            TextField("卡片别名", text: $alias, prompt: Text("例如：网购卡/差旅卡"))
                                .focused($focusedField, equals: .alias)
                            
                            SecureField("CVV 安全码", text: $cvv, prompt: Text("3-4位数字"))
                                .focused($focusedField, equals: .cvv)
                                .onChange(of: cvv) { _, newValue in
                                    self.cvv = String(newValue.replacingOccurrences(of: "\\D", with: "", options: .regularExpression).prefix(4))
                                }
                            
                            TextField("有效期", text: $valid, prompt: Text("MM/YY 格式 (例如 08/29)"))
                                .onChange(of: valid) { _, newValue in
                                    self.valid = String(newValue.prefix(5))
                                }
                        }
                        
                        // Section 3: 💰 额度、共享与年费
                        Section(header: Text("💰 额度与年费")) {
                            HStack {
                                Picker("币种", selection: $type) {
                                    ForEach(currencies, id: \.self) { curr in
                                        Text(curr).tag(curr)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Toggle("共享该行额度", isOn: $isSharedLimit)
                                    .toggleStyle(.checkbox)
                                    .onChange(of: isSharedLimit) { _, newValue in
                                        if newValue {
                                            checkExistingSharedLimit()
                                        } else {
                                            existingSharedCard = nil
                                        }
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("信用额度")
                                    Spacer()
                                    TextField("额度", value: $limit, format: .number)
                                        .focused($focusedField, equals: .limit)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                }
                                
                                if isSharedLimit && existingSharedCard != nil {
                                    Text("💡 共享联动：保存此额度时，同银行共享组中的其他卡片也会一并自动同步更新该额度。")
                                        .font(.system(size: 10))
                                        .foregroundColor(.cyan)
                                }
                            }
                            
                            HStack {
                                Text("年费金额")
                                Spacer()
                                TextField("年费", value: $annualFee, format: .number)
                                    .focused($focusedField, equals: .annualFee)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            // 年费达标管理
                            Picker("年费达标状态", selection: $isQualified) {
                                Text("未达标").tag("2")
                                Text("已达标").tag("1")
                                Text("终身免年费").tag("3")
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: isQualified) { _, newValue in
                                isUltimateFreeFee = (newValue == "3")
                            }
                            
                            if !isUltimateFreeFee {
                                DatePicker("下次年费收取日", selection: $nextAnnualFeeCollectionTime, displayedComponents: .date)
                            }
                            
                            DatePicker("上次提额时间", selection: $lastTime, displayedComponents: .date)
                        }
                        
                        // Section 4: 💸 账单日与还款日
                        Section(header: Text("💸 账单还款周期")) {
                            HStack(spacing: 8) {
                                Text("账单日")
                                TextField("", text: $accountBillDate, prompt: Text("1-31"))
                                    .focused($focusedField, equals: .billDate)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                    .multilineTextAlignment(.center)
                                    .labelsHidden()
                                Text("号")
                                
                                Spacer()
                                
                                Text("还款日")
                                TextField("", text: $dueDate, prompt: Text("1-31"))
                                    .focused($focusedField, equals: .dueDate)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                    .multilineTextAlignment(.center)
                                    .labelsHidden()
                                Text("号")
                            }
                            .onChange(of: accountBillDate) { _, newValue in
                                self.accountBillDate = validateDateInput(newValue)
                            }
                            .onChange(of: dueDate) { _, newValue in
                                self.dueDate = validateDateInput(newValue)
                            }
                            
                            Picker("账单日当天消费计入", selection: $billingDaySpendingToNextBill) {
                                Text("下期账单(享受超长免息)").tag(true)
                                Text("当期账单(适合尽快还款)").tag(false)
                            }
                            .pickerStyle(.radioGroup)
                        }
                        
                        // Section 5: 🎁 权益与备注
                        Section(header: Text("🎁 权益与备注")) {
                            TextField("核心卡片权益说明", text: $equity, axis: .vertical)
                                .focused($focusedField, equals: .equity)
                                .lineLimit(3...5)
                            
                            TextField("个人专属备注", text: $remark, axis: .vertical)
                                .focused($focusedField, equals: .remark)
                                .lineLimit(2...4)
                        }
                    }
                    .formStyle(.grouped)
                    .navigationTitle((mode == "edit" || cardToEdit != nil) ? "编辑信用卡信息" : "新增信用卡")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                dismiss()
                            }
                            .keyboardShortcut(.cancelAction)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("确定") {
                                saveCard()
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                    .onAppear {
                        loadInitialData()
                        focusedField = .cardNumber // 打开时默认激活卡号焦点，顺手！
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: lockManager.isLocked)
        .frame(minWidth: 550, minHeight: 650)
    }
    
    // 初始化加载数据
    private func loadInitialData() {
        guard let card = cardToEdit else {
            checkExistingSharedLimit()
            return
        }
        
        country = card.country
        bank = card.bank
        cardNumber = card.cardNumber
        alias = card.alias ?? ""
        level = card.level ?? "金卡"
        type = card.type ?? "CNY"
        limit = card.limit ?? 0.0
        cvv = card.cvv ?? ""
        valid = card.valid ?? ""
        annualFee = card.annualFee ?? 0.0
        isQualified = card.isQualified ?? "2"
        isUltimateFreeFee = (isQualified == "3")
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        if let feeTime = card.nextAnnualFeeCollectionTime, let date = df.date(from: feeTime) {
            nextAnnualFeeCollectionTime = date
        }
        if let raiseTime = card.lastTime, let date = df.date(from: raiseTime) {
            lastTime = date
        }
        
        accountBillDate = card.accountBillDate ?? "10"
        dueDate = card.dueDate ?? "28"
        billingDaySpendingToNextBill = card.billingDaySpendingToNextBill
        equity = card.equity ?? ""
        remark = card.remark ?? ""
        isSharedLimit = card.isSharedLimit
        
        checkExistingSharedLimit()
    }
    
    /// 检查并自动匹配同银行已有的共享额度
    private func checkExistingSharedLimit() {
        guard isSharedLimit else {
            existingSharedCard = nil
            return
        }
        
        let cleanBank = bank.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        
        let match = existingCards.first { item in
            let itemBank = item.bank.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            return item.country == country &&
                   itemBank == cleanBank &&
                   item.isSharedLimit &&
                   item.id != cardToEdit?.id
        }
        
        if let shared = match {
            existingSharedCard = shared
            // 如果是新增，自动应用已有额度和币种
            if mode == "add" {
                limit = shared.limit ?? 0.0
                type = shared.type ?? "CNY"
            }
        } else {
            existingSharedCard = nil
        }
    }
    
    private func formatCardNumber(_ number: String) -> String {
        var formatted = ""
        for (index, char) in number.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted.append(char)
        }
        return formatted
    }
    
    private func validateDateInput(_ input: String) -> String {
        let digits = input.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        guard let day = Int(digits) else { return "" }
        let bound = min(max(day, 1), 31)
        return String(bound)
    }
    
    private func saveCard() {
        // 卡号基本验证
        let cleanNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        guard cleanNumber.count >= 13 && cleanNumber.count <= 19 else {
            focusedField = .cardNumber
            return
        }
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        
        let feeTimeStr = isUltimateFreeFee ? "" : df.string(from: nextAnnualFeeCollectionTime)
        let lastTimeStr = df.string(from: lastTime)
        
        let lastModifyTimeStr = DateFormatter.iso8601String(from: Date())
        
        let finalCard = SharedCard(
            id: cardToEdit?.id ?? UUID().uuidString,
            country: country,
            bank: bank,
            cardNumber: cleanNumber,
            alias: alias,
            level: level,
            type: type,
            limit: limit,
            cvv: cvv,
            valid: valid,
            annualFee: annualFee,
            isQualified: isQualified,
            nextAnnualFeeCollectionTime: feeTimeStr,
            lastTime: lastTimeStr,
            accountBillDate: accountBillDate,
            dueDate: dueDate,
            billingDaySpendingToNextBill: billingDaySpendingToNextBill,
            equity: equity,
            remark: remark,
            lastModifyTime: lastModifyTimeStr,
            isSharedLimit: isSharedLimit
        )
        
        onSubmit(finalCard)
        dismiss()
    }
}

// 辅助占位文本修饰符
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            
            ZStack(alignment: alignment) {
                placeholder().opacity(shouldShow ? 1 : 0)
                self
            }
        }
    
    func placeholder(_ text: String, when shouldShow: Bool) -> some View {
        placeholder(when: shouldShow) {
            Text(text).foregroundColor(.gray.opacity(0.5))
        }
    }
}

// ISO8601 日期序列化辅助
extension DateFormatter {
    static func iso8601String(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df.string(from: date)
    }
}
