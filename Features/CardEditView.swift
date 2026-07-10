import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct CardEditView: View {
    @Environment(\.dismiss) var dismiss
    
    // 监听自动锁定状态
    @State private var lockManager = AutoLockManager.shared
    
    public var mode: String // "add" 或 "edit"
    public var cardToEdit: SharedCard?
    public var initialCardCategory: String
    public var existingCards: [SharedCard]
    
    public var onSubmit: (SharedCard) -> Void
    
    // 💡 表单数据绑定 (对齐 SharedCard)
    @State private var country = ""
    @State private var cardCategory = "credit"
    @State private var bank = ""
    @State private var cardNumber = ""
    @State private var alias = ""
    @State private var level = ""
    @State private var type = ""
    @State private var limitText = ""
    @State private var cvv = ""
    @State private var valid = ""
    @State private var annualFeeText = ""
    @State private var isQualified = ""
    @State private var nextAnnualFeeCollectionTime: Date?
    @State private var isUltimateFreeFee = false // 终免年费开关
    @State private var lastTime: Date?
    @State private var accountBillDate = ""
    @State private var dueDate = ""
    @State private var billingDaySpendingToNextBill = true
    @State private var equity = ""
    @State private var remark = ""
    @State private var isSharedLimit = true
    @State private var cardImages: [CardImageAsset] = []
    @State private var isImportingImages = false
    
    // 💡 焦点流动状态，符合人类的 Tab 键操作逻辑
    enum Field: Hashable {
        case cardNumber, alias, cvv, limit, annualFee, billDate, dueDate, equity, remark
    }
    @FocusState private var focusedField: Field?
    
    // 💡 共享额度联动提示
    @State private var existingSharedCard: SharedCard? = nil
    @State private var isLimitFeeSectionExpanded = false
    @State private var isBenefitSectionExpanded = false
    
    // 预置选项参考数据 (100% 完美同步 Vue 3 Web 端 referenceData.js 定义)
    let countries = [
        "中国", "香港特别行政区", "澳门特别行政区", "台湾", "美国", "英国", "新加坡",
        "德国", "日本", "韩国", "澳大利亚", "加拿大", "法国", "意大利", "西班牙",
        "荷兰", "瑞士", "泰国", "马来西亚", "印度尼西亚", "菲律宾", "越南", "印度",
        "巴西", "阿根廷", "墨西哥", "俄罗斯", "南非", "土耳其", "沙特阿拉伯", "阿联酋",
        "以色列", "埃及", "新西兰"
    ]
    let banks = [
        "工商银行", "建设银行", "农业银行", "中国银行", "交通银行", "邮储银行",
        "招商银行", "中信银行", "光大银行", "华夏银行", "民生银行", "平安银行",
        "兴业银行", "浦发银行", "广发银行", "北京银行", "上海银行", "江苏银行",
        "宁波银行", "南京银行", "杭州银行", "成都银行", "重庆银行", "徽商银行",
        "浙商银行", "渤海银行", "上海农商银行", "重庆农商银行", "微众银行", "网商银行",
        "汇丰银行", "恒生银行", "中银香港", "渣打银行", "东亚银行", "花旗银行",
        "星展银行", "华侨银行", "众安银行", "招商永隆银行", "Mox Bank", "大西洋银行",
        "澳门商业银行", "大丰银行", "澳门国际银行", "中国信托银行", "国泰世华银行", "兆丰国际商业银行",
        "台北富邦银行", "玉山银行", "台新银行", "台湾银行", "第一银行", "华南银行",
        "合作金库银行", "摩根大通银行", "美国银行", "富国银行", "U.S. Bank", "Capital One",
        "PNC Bank", "Truist Bank", "美国运通", "Discover Bank", "加拿大皇家银行", "TD Bank",
        "加拿大丰业银行", "蒙特利尔银行", "加拿大帝国商业银行", "加拿大国民银行", "Desjardins", "巴克莱银行",
        "Lloyds Bank", "NatWest", "Santander UK", "Nationwide Building Society", "Halifax", "Monzo Bank",
        "Starling Bank", "德意志银行", "德国商业银行", "Sparkasse", "ING Germany", "Deutsche Kreditbank",
        "HypoVereinsbank", "N26 Bank", "法国巴黎银行", "法国农业信贷银行", "法国兴业银行", "Groupe BPCE",
        "Crédit Mutuel", "La Banque Postale", "裕信银行", "联合圣保罗银行", "Banco BPM", "Banca Monte dei Paschi di Siena",
        "桑坦德银行", "西班牙对外银行", "CaixaBank", "Banco Sabadell", "Bankinter", "ING Bank",
        "荷兰合作银行", "荷兰银行", "bunq", "瑞银", "Raiffeisen Switzerland", "Zürcher Kantonalbank",
        "PostFinance", "瑞士宝盛银行", "三菱日联银行", "三井住友银行", "瑞穗银行", "日本邮政银行",
        "Resona Bank", "Rakuten Bank", "SBI Sumishin Net Bank", "Sony Bank", "KB国民银行", "新韩银行",
        "韩亚银行", "友利银行", "NH NongHyup Bank", "IBK Industrial Bank of Korea", "KakaoBank", "Toss Bank",
        "澳大利亚联邦银行", "西太平洋银行", "澳大利亚国民银行", "澳新银行", "麦格理银行", "Bendigo and Adelaide Bank",
        "Bank of New Zealand", "Kiwibank", "ASB Bank", "TSB New Zealand", "大华银行", "马来亚银行",
        "联昌国际银行", "大众银行", "兴业银行（马来西亚）", "丰隆银行", "Alliance Bank Malaysia", "盘谷银行",
        "开泰银行", "Siam Commercial Bank", "Krungthai Bank", "Krungsri", "ttb bank", "Bank Mandiri",
        "Bank Rakyat Indonesia", "Bank Central Asia", "Bank Negara Indonesia", "Bank Syariah Indonesia", "Bank Tabungan Negara", "BDO Unibank",
        "Bank of the Philippine Islands", "Metrobank", "Land Bank of the Philippines", "Philippine National Bank", "UnionBank of the Philippines", "Security Bank",
        "Vietcombank", "BIDV", "VietinBank", "Agribank", "Techcombank", "MB Bank",
        "VPBank", "Asia Commercial Bank", "State Bank of India", "HDFC Bank", "ICICI Bank", "Axis Bank",
        "Kotak Mahindra Bank", "Punjab National Bank", "Bank of Baroda", "Canara Bank", "Itaú Unibanco", "Banco do Brasil",
        "Bradesco", "Caixa Econômica Federal", "Santander Brasil", "Nubank", "BTG Pactual", "Banco Nación",
        "Banco Galicia", "Santander Argentina", "BBVA Argentina", "Banco Macro", "BBVA México", "Banorte",
        "Santander México", "Banamex", "HSBC México", "Scotiabank México", "Banco Inbursa", "Sberbank",
        "VTB Bank", "Gazprombank", "Alfa-Bank", "Rosselkhozbank", "T-Bank", "Sovcombank",
        "Standard Bank", "FirstRand Bank", "Absa Bank", "Nedbank", "Capitec Bank", "Investec Bank",
        "Ziraat Bank", "Türkiye İş Bankası", "Garanti BBVA", "Akbank", "Halkbank", "VakıfBank",
        "Yapı Kredi", "Saudi National Bank", "Al Rajhi Bank", "Riyad Bank", "Saudi Awwal Bank", "Saudi Investment Bank",
        "Banque Saudi Fransi", "First Abu Dhabi Bank", "Emirates NBD", "Abu Dhabi Commercial Bank", "Mashreq", "Dubai Islamic Bank",
        "Abu Dhabi Islamic Bank", "RAKBANK", "Bank Hapoalim", "Bank Leumi", "Mizrahi-Tefahot Bank", "Israel Discount Bank",
        "First International Bank of Israel", "National Bank of Egypt", "Banque Misr", "Commercial International Bank", "QNB Alahli", "Banque du Caire",
        "Arab African International Bank"
    ]
    let levels = CardLevelGroup.allValues
    let currencies = [
        "CNY", "CNH", "USD", "EUR", "GBP", "JPY", "HKD", "MOP", "TWD", "SGD",
        "AUD", "CAD", "CHF", "SEK", "DKK", "NOK", "NZD", "KRW", "THB", "MYR",
        "IDR", "VND", "PHP", "INR"
    ]
    
    public init(
        mode: String,
        cardToEdit: SharedCard? = nil,
        initialCardCategory: String = "credit",
        existingCards: [SharedCard],
        onSubmit: @escaping (SharedCard) -> Void
    ) {
        self.mode = mode
        self.cardToEdit = cardToEdit
        self.initialCardCategory = initialCardCategory == "debit" ? "debit" : "credit"
        self.existingCards = existingCards
        self.onSubmit = onSubmit
    }
    
    private var isDebitCard: Bool {
        cardCategory == "debit"
    }
    
    private var cardCategoryTitle: String {
        isDebitCard ? "储蓄卡" : "信用卡"
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
                        // Section 1: 四个核心字段必填，其余字段可留空
                        Section(header: Text("核心信息")) {
                            Picker("卡类别", selection: $cardCategory) {
                                Text("信用卡").tag("credit")
                                Text("储蓄卡").tag("debit")
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: cardCategory) { _, _ in
                                checkExistingSharedLimit()
                            }
                            
                            EditableOptionField(
                                title: "国家/地区 *",
                                text: $country,
                                options: countries
                            )
                            .onChange(of: country) { _, _ in
                                checkExistingSharedLimit()
                            }
                            
                            EditableOptionField(
                                title: "发卡银行 *",
                                text: $bank,
                                options: banks
                            )
                            .onChange(of: bank) { _, _ in
                                checkExistingSharedLimit()
                            }
                            
                            HStack {
                                TextField("银行卡号 *", text: $cardNumber, prompt: Text("输入 13-19 位银行卡号"))
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
                            
                            TextField("有效期 *", text: $valid, prompt: Text("MM/YY 格式 (例如 08/29)"))
                                .onChange(of: valid) { _, newValue in
                                    self.valid = String(newValue.prefix(5))
                                }
                            
                            SecureField("CVV 安全码", text: $cvv, prompt: Text("3-4位数字"))
                                .focused($focusedField, equals: .cvv)
                                .onChange(of: cvv) { _, newValue in
                                    self.cvv = String(newValue.replacingOccurrences(of: "\\D", with: "", options: .regularExpression).prefix(4))
                                }
                            
                            CardLevelPickerField(level: $level)
                            
                            if isDebitCard {
                                EditableOptionField(
                                    title: "币种",
                                    text: $type,
                                    options: currencies
                                )
                                .onChange(of: type) { _, _ in
                                    checkExistingSharedLimit()
                                }
                            }
                        }
                        
                        if !isDebitCard {
                            DisclosureGroup("额度与年费", isExpanded: $isLimitFeeSectionExpanded) {
                                EditableOptionField(
                                    title: "币种",
                                    text: $type,
                                    options: currencies
                                )
                                
                                Toggle("共享该行额度", isOn: $isSharedLimit)
                                    .toggleStyle(.checkbox)
                                    .onChange(of: isSharedLimit) { _, newValue in
                                        if newValue {
                                            checkExistingSharedLimit()
                                        } else {
                                            existingSharedCard = nil
                                        }
                                    }
                                
                                HStack {
                                    Text("额度")
                                    Spacer()
                                    TextField("额度", text: $limitText)
                                        .focused($focusedField, equals: .limit)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 140)
                                        .onChange(of: limitText) { _, newValue in
                                            limitText = filterAmountInput(newValue)
                                        }
                                }
                                
                                if isSharedLimit && existingSharedCard != nil {
                                    Text("共享联动：保存此额度时，同银行共享组中的其他信用卡也会一并自动同步更新该额度。")
                                        .font(.system(size: 10))
                                        .foregroundColor(.cyan)
                                }
                                
                                HStack {
                                    Text("年费金额")
                                    Spacer()
                                    TextField("年费", text: $annualFeeText)
                                        .focused($focusedField, equals: .annualFee)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 140)
                                        .onChange(of: annualFeeText) { _, newValue in
                                            annualFeeText = filterAmountInput(newValue)
                                        }
                                }
                                
                                Picker("年费减免政策", selection: $isQualified) {
                                    Text("未选择").tag("")
                                    Text("未达标").tag("2")
                                    Text("已达标").tag("1")
                                    Text("终免年费").tag("3")
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: isQualified) { _, newValue in
                                    isUltimateFreeFee = (newValue == "3")
                                    if newValue == "3" {
                                        nextAnnualFeeCollectionTime = nil
                                    }
                                }
                                
                                if !isUltimateFreeFee {
                                    OptionalDatePickerRow(
                                        title: "下次年费收取日",
                                        date: $nextAnnualFeeCollectionTime
                                    )
                                }
                                
                                OptionalDatePickerRow(
                                    title: "上次提额时间",
                                    date: $lastTime
                                )
                            }
                        }
                        
                        DisclosureGroup("权益与备注", isExpanded: $isBenefitSectionExpanded) {
                            if !isDebitCard {
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
                            
                            TextField(isDebitCard ? "卡片权益说明" : "核心卡片权益说明", text: $equity, axis: .vertical)
                                .focused($focusedField, equals: .equity)
                                .lineLimit(3...5)
                            
                            TextField("个人专属备注", text: $remark, axis: .vertical)
                                .focused($focusedField, equals: .remark)
                                .lineLimit(2...4)
                        }

                        Section(header: Text("🖼️ 卡片媒体文件")) {
                            HStack {
                                Button {
                                    isImportingImages = true
                                } label: {
                                    Label("上传图片", systemImage: "photo.badge.plus")
                                }
                                Spacer()
                                Text("\(cardImages.count) 张 · 总大小 \(formatFileSize(cardImages.reduce(0) { $0 + imageByteSize($1) }))")
                                    .foregroundStyle(.secondary)
                            }

                            if cardImages.isEmpty {
                                Text("暂无卡片图片。上传后，其他设备也可以查看这些图片。")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(cardImages) { image in
                                            VStack(alignment: .leading, spacing: 6) {
                                                if let nsImage = nsImage(from: image) {
                                                    Image(nsImage: nsImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 170, height: 108)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .stroke(.secondary.opacity(0.25), lineWidth: 1)
                                                        )
                                                } else {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(.secondary.opacity(0.15))
                                                        .frame(width: 170, height: 108)
                                                        .overlay(Text("无法预览").font(.footnote).foregroundStyle(.secondary))
                                                }

                                                HStack {
                                                    Text(image.name.isEmpty ? image.source : image.name)
                                                        .font(.caption)
                                                        .lineLimit(1)
                                                        .truncationMode(.middle)
                                                    Spacer()
                                                    Button(role: .destructive) {
                                                        cardImages.removeAll { $0.id == image.id }
                                                    } label: {
                                                        Image(systemName: "trash")
                                                    }
                                                    .buttonStyle(.borderless)
                                                }
                                                .frame(width: 170)

                                                Text("上传时间 \(formatImageUploadTime(image.createdAt))")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                Text("文件大小 \(formatFileSize(imageByteSize(image)))")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .navigationTitle((mode == "edit" || cardToEdit != nil) ? "编辑\(cardCategoryTitle)信息" : "新增\(cardCategoryTitle)")
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
                    .fileImporter(
                        isPresented: $isImportingImages,
                        allowedContentTypes: [.image],
                        allowsMultipleSelection: true
                    ) { result in
                        if case let .success(urls) = result {
                            importImageFiles(urls)
                        }
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
            cardCategory = initialCardCategory
            checkExistingSharedLimit()
            return
        }
        
        cardCategory = card.cardCategory == "debit" ? "debit" : "credit"
        country = card.country
        bank = card.bank
        cardNumber = card.cardNumber
        alias = card.alias ?? ""
        level = CardLevelGroup.normalize(card.level ?? "")
        type = card.type ?? ""
        limitText = formatEditableAmount(card.limit)
        cvv = card.cvv ?? ""
        valid = card.valid ?? ""
        annualFeeText = formatEditableAmount(card.annualFee)
        isQualified = card.isQualified ?? ""
        isUltimateFreeFee = (isQualified == "3")
        
        if let date = DateCalculator.date(fromTimestamp: card.nextAnnualFeeCollectionTime) {
            nextAnnualFeeCollectionTime = date
        } else {
            nextAnnualFeeCollectionTime = nil
        }
        if let date = DateCalculator.date(fromTimestamp: card.lastTime) {
            lastTime = date
        } else {
            lastTime = nil
        }
        
        accountBillDate = card.accountBillDate ?? ""
        dueDate = card.dueDate ?? ""
        billingDaySpendingToNextBill = card.billingDaySpendingToNextBill
        equity = card.equity ?? ""
        remark = card.remark ?? ""
        isSharedLimit = card.isSharedLimit
        cardImages = card.cardImages
        
        checkExistingSharedLimit()
    }
    
    /// 检查并自动匹配同银行已有的共享额度
    private func checkExistingSharedLimit() {
        guard !isDebitCard, isSharedLimit else {
            existingSharedCard = nil
            return
        }
        
        let cleanType = type.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let match = existingCards.first { item in
            let itemType = (item.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return item.country == country &&
                   item.cardCategory != "debit" &&
                   BankNameNormalizer.namesReferToSameBank(item.bank, bank) &&
                   itemType == cleanType &&
                   item.isSharedLimit &&
                   item.id != cardToEdit?.id
        }
        
        if let shared = match {
            existingSharedCard = shared
            // 如果是新增，自动应用已有额度和币种
            if mode == "add" {
                limitText = formatEditableAmount(shared.limit)
                if type.isEmpty {
                    type = shared.type ?? ""
                }
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

    private func filterAmountInput(_ input: String) -> String {
        var result = ""
        var hasDot = false
        for char in input.replacingOccurrences(of: ",", with: "") {
            if char.isNumber {
                result.append(char)
            } else if char == "." && !hasDot {
                result.append(char)
                hasDot = true
            }
        }
        return result
    }

    private func parseAmount(_ input: String) -> Double? {
        let cleaned = input.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let value = Double(cleaned), value >= 0 else { return nil }
        return value
    }

    private func formatEditableAmount(_ value: Double?) -> String {
        guard let value else { return "" }
        if value.rounded(.towardZero) == value {
            return String(Int(value))
        }
        return String(value)
    }

    private func isValidExpiry(_ input: String) -> Bool {
        let pattern = #"^\d{2}/\d{2}$"#
        guard input.range(of: pattern, options: .regularExpression) != nil else { return false }
        guard let month = Int(input.prefix(2)) else { return false }
        return (1...12).contains(month)
    }
    
    private func saveCard() {
        guard !country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard !bank.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // 卡号基本验证
        let cleanNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        guard cleanNumber.count >= 13 && cleanNumber.count <= 19 else {
            focusedField = .cardNumber
            return
        }
        guard isValidExpiry(valid) else {
            return
        }
        guard isDebitCard || limitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parseAmount(limitText) != nil else {
            focusedField = .limit
            return
        }
        guard isDebitCard || annualFeeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parseAmount(annualFeeText) != nil else {
            focusedField = .annualFee
            return
        }
        
        let feeTimeTimestamp = isDebitCard || isUltimateFreeFee ? nil : nextAnnualFeeCollectionTime.map { DateCalculator.timestamp(from: $0) }
        let lastTimeTimestamp = isDebitCard ? nil : lastTime.map { DateCalculator.timestamp(from: $0) }
        let lastModifyTimestamp = DateCalculator.timestamp(from: Date())
        let parsedLimit: Double? = isDebitCard ? 0.0 : parseAmount(limitText)
        let parsedAnnualFee: Double? = isDebitCard ? 0.0 : parseAmount(annualFeeText)
        
        let finalCard = SharedCard(
            id: cardToEdit?.id ?? UUID().uuidString,
            cardCategory: cardCategory,
            country: country.trimmingCharacters(in: .whitespacesAndNewlines),
            bank: bank.trimmingCharacters(in: .whitespacesAndNewlines),
            cardNumber: cleanNumber,
            alias: alias.trimmingCharacters(in: .whitespacesAndNewlines),
            level: level.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type.trimmingCharacters(in: .whitespacesAndNewlines),
            limit: parsedLimit,
            cvv: cvv.trimmingCharacters(in: .whitespacesAndNewlines),
            valid: valid.trimmingCharacters(in: .whitespacesAndNewlines),
            annualFee: parsedAnnualFee,
            isQualified: isDebitCard ? "" : isQualified.trimmingCharacters(in: .whitespacesAndNewlines),
            nextAnnualFeeCollectionTime: feeTimeTimestamp,
            lastTime: lastTimeTimestamp,
            accountBillDate: isDebitCard ? "" : accountBillDate.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: isDebitCard ? "" : dueDate.trimmingCharacters(in: .whitespacesAndNewlines),
            billingDaySpendingToNextBill: billingDaySpendingToNextBill,
            equity: equity.trimmingCharacters(in: .whitespacesAndNewlines),
            remark: remark.trimmingCharacters(in: .whitespacesAndNewlines),
            lastModifyTime: lastModifyTimestamp,
            isSharedLimit: isDebitCard ? false : isSharedLimit,
            cardImages: cardImages
        )
        
        onSubmit(finalCard)
        dismiss()
    }

    private func importImageFiles(_ urls: [URL]) {
        let imported = urls.compactMap { makeCardImageAsset(from: $0) }
        guard !imported.isEmpty else { return }
        cardImages.append(contentsOf: imported)
    }

    private func makeCardImageAsset(from url: URL) -> CardImageAsset? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let payload = normalizedImagePayload(from: url) else { return nil }
        return CardImageAsset(
            mimeType: payload.mimeType,
            data: "data:\(payload.mimeType);base64,\(payload.data.base64EncodedString())",
            source: "mac_upload",
            name: url.lastPathComponent
        )
    }

    private func normalizedImagePayload(from url: URL) -> (data: Data, mimeType: String)? {
        guard let image = NSImage(contentsOf: url) else {
            guard let raw = try? Data(contentsOf: url) else { return nil }
            return (raw, UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/jpeg")
        }

        let maxEdge: CGFloat = 1600
        let scale = min(1, maxEdge / max(image.size.width, image.size.height))
        let targetSize = NSSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1)
        resized.unlockFocus()

        guard
            let tiff = resized.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.84])
        else {
            return nil
        }
        return (jpeg, "image/jpeg")
    }

    private func nsImage(from asset: CardImageAsset) -> NSImage? {
        let base64 = asset.data.components(separatedBy: "base64,").last ?? asset.data
        guard let data = Data(base64Encoded: base64) else { return nil }
        return NSImage(data: data)
    }

    private func imageByteSize(_ asset: CardImageAsset) -> Int64 {
        let base64 = asset.data.components(separatedBy: "base64,").last ?? asset.data
        return Int64(Data(base64Encoded: base64, options: .ignoreUnknownCharacters)?.count ?? 0)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }

    private func formatImageUploadTime(_ timestamp: Double) -> String {
        guard timestamp > 0 else { return "未知" }
        let seconds = timestamp < 1_000_000_000_000 ? timestamp : timestamp / 1000
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: seconds))
    }
}

private struct CardLevelGroup {
    let brand: String
    let levels: [String]

    static let all = [
        CardLevelGroup(brand: "银联", levels: ["普卡", "金卡", "白金卡", "钻石卡", "黑钻卡"]),
        CardLevelGroup(brand: "Visa", levels: ["普卡", "金卡", "白金卡", "御玺卡", "无限卡"]),
        CardLevelGroup(brand: "万事达", levels: ["普卡", "金卡", "白金卡", "钛金卡", "世界卡", "世界之极卡"]),
        CardLevelGroup(brand: "JCB", levels: ["普卡", "金卡", "白金卡", "御尊卡"]),
        CardLevelGroup(brand: "美国运通", levels: ["绿卡", "金卡", "白金卡", "黑金卡"])
    ]

    static let allValues = all.flatMap { group in
        group.levels.map { "\(group.brand)-\($0)" }
    }

    static func normalize(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }
        if allValues.contains(cleaned) { return cleaned }
        if cleaned.hasPrefix("MasterCard-") || cleaned.hasPrefix("Mastercard-") {
            return cleaned.replacingOccurrences(
                of: "^Master[Cc]ard-",
                with: "万事达-",
                options: .regularExpression
            )
        }
        if cleaned.hasPrefix("VISA-") {
            return cleaned.replacingOccurrences(of: "^VISA-", with: "Visa-", options: .regularExpression)
        }
        let legacyAmericanExpressLevels = [
            "AE-经典-绿卡": "美国运通-绿卡",
            "AE-经典-金卡": "美国运通-金卡",
            "AE-经典-新贵白金卡": "美国运通-白金卡",
            "AE-经典-百夫长白金卡": "美国运通-白金卡",
            "AE-经典-百夫长黑金卡": "美国运通-黑金卡"
        ]
        return legacyAmericanExpressLevels[cleaned] ?? cleaned
    }

    static func selection(for value: String) -> (brand: String, level: String)? {
        let normalized = normalize(value)
        for group in all {
            let prefix = "\(group.brand)-"
            guard normalized.hasPrefix(prefix) else { continue }
            let level = String(normalized.dropFirst(prefix.count))
            if group.levels.contains(level) {
                return (group.brand, level)
            }
        }
        return nil
    }
}

private struct CardLevelPickerField: View {
    @Binding var level: String

    private var selection: (brand: String, level: String)? {
        CardLevelGroup.selection(for: level)
    }

    private var selectedGroup: CardLevelGroup? {
        CardLevelGroup.all.first { $0.brand == selection?.brand }
    }

    private var brandBinding: Binding<String> {
        Binding(
            get: { selection?.brand ?? "" },
            set: { brand in
                guard let group = CardLevelGroup.all.first(where: { $0.brand == brand }) else {
                    level = ""
                    return
                }
                let selectedLevel = selection?.level
                let nextLevel = selectedLevel.flatMap { group.levels.contains($0) ? $0 : nil }
                    ?? group.levels.first
                    ?? ""
                level = nextLevel.isEmpty ? "" : "\(brand)-\(nextLevel)"
            }
        )
    }

    private var levelBinding: Binding<String> {
        Binding(
            get: { selection?.level ?? "" },
            set: { selectedLevel in
                guard let brand = selection?.brand, !selectedLevel.isEmpty else { return }
                level = "\(brand)-\(selectedLevel)"
            }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("卡片等级")
            Spacer()
            Picker("卡组织", selection: brandBinding) {
                Text("请选择卡组织").tag("")
                ForEach(CardLevelGroup.all, id: \.brand) { group in
                    Text(group.brand).tag(group.brand)
                }
            }
            .labelsHidden()
            .frame(width: 120)

            Picker("等级", selection: levelBinding) {
                Text("请选择等级").tag("")
                ForEach(selectedGroup?.levels ?? [], id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 120)
            .disabled(selectedGroup == nil)

            Text(level.isEmpty ? "预览：—" : "预览：\(level)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
                .lineLimit(1)
        }
    }
}

private struct EditableOptionField: View {
    let title: String
    @Binding var text: String
    let options: [String]

    private var filteredOptions: [String] {
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(keyword) }
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("可输入或选择", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            Menu {
                if filteredOptions.isEmpty {
                    Text("没有匹配项，可直接保存当前输入")
                } else {
                    ForEach(Array(filteredOptions.prefix(30)), id: \.self) { option in
                        Button(option) {
                            text = option
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.down.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

private struct OptionalDatePickerRow: View {
    let title: String
    @Binding var date: Date?

    var body: some View {
        if date == nil {
            HStack {
                Text(title)
                Spacer()
                Button("选择日期") {
                    date = Date()
                }
            }
        } else {
            DatePicker(
                title,
                selection: Binding(
                    get: { date ?? Date() },
                    set: { date = $0 }
                ),
                displayedComponents: .date
            )
            Button("清除") {
                date = nil
            }
        }
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
