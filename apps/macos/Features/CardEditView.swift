import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct CardEditView: View {
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletAnimation) private var walletAnimation
    @State private var didLoad = false
    @State private var originalDraft: [String] = []
    @State private var validationMessage = ""
    @State private var imageImportError = ""
    @State private var showingDiscardConfirmation = false
    @State private var isImportingPhotoData = false
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var importTask: Task<Void, Never>?
    @Environment(\.dismiss) var dismiss
    
    // 监听自动锁定状态
    @Environment(\.walletIsLocked) private var isLocked
    
    public var mode: String // "add" 或 "edit"
    public var cardToEdit: SharedCard?
    public var initialCardCategory: String
    public var existingCards: [SharedCard]
    
    public var onSubmit: @MainActor (SharedCard) async throws -> Void
    
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
        onSubmit: @escaping @MainActor (SharedCard) async throws -> Void
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
    
    @Environment(\.walletSheetSize) private var sheetSize

    public var body: some View {
        Group {
            if isLocked {
                LockScreenView()
            } else {
                VStack(spacing: 0) {
                    WalletSheetHeader(title: mode == "edit" ? "编辑卡片" : "添加卡片",
                                      subtitle: String(localized: "先填基本信息，其余内容可随时补充。"), icon: "creditcard") {
                        Button(action: requestDismiss) { Image(systemName: "xmark") }
                            .buttonStyle(.plain).help("关闭").accessibilityLabel("关闭")
                    }
                    ScrollView {
                        VStack(spacing: 16) {
                            basicFields
                            if !isDebitCard {
                                limitFields
                                billingFields
                            }
                            noteFields
                            imageFields
                        }
                        .padding(22)
                    }
                    .scrollContentBackground(.hidden)
                    editorFooter
                }
                .onAppear {
                    if !didLoad {
                        loadInitialData()
                        originalDraft = draftSnapshot
                        didLoad = true
                        focusedField = .cardNumber
                    }
                }
                .fileImporter(isPresented: $isImportingImages, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
                    if case let .success(urls) = result { importImageFiles(urls) }
                }
            }
        }
        .disabled(isSaving)
        .modifier(WalletThemeModifier())
        .animation(walletAnimation, value: isLocked)
        .interactiveDismissDisabled(hasUnsavedChanges || isSaving)
        .alert("放弃这次修改？", isPresented: $showingDiscardConfirmation) {
            Button("继续编辑", role: .cancel) {}
            Button("放弃修改", role: .destructive) { dismiss() }
        } message: { Text("尚未保存的内容将丢失，已有卡片不会改变。") }
        .onChange(of: draftSnapshot) { _, _ in validationMessage = "" }
        .onDisappear { importTask?.cancel(); saveTask?.cancel() }
        .frame(width: sheetSize.width, height: sheetSize.height)
    }

    private var basicFields: some View {
        WalletFormSection(title: "基本信息", icon: "creditcard") {
            WalletChoiceBar(title: "卡类别", selection: $cardCategory, choices: [
                WalletChoice(value: "credit", title: "信用卡"), WalletChoice(value: "debit", title: "储蓄卡")
            ])
            .onChange(of: cardCategory) { _, _ in checkExistingSharedLimit() }

            HStack(alignment: .top, spacing: 18) {
                EditableOptionField(title: "国家/地区 *", text: $country, options: countries)
                    .onChange(of: country) { _, _ in checkExistingSharedLimit() }
                EditableOptionField(title: "发卡银行 *", text: $bank, options: banks)
                    .onChange(of: bank) { _, _ in checkExistingSharedLimit() }
            }
            if let previous = cardToEdit, bank != previous.bank,
               existingCards.contains(where: { $0.id != previous.id && BankNameNormalizer.namesReferToSameBank($0.bank, previous.bank) }) {
                Text("保存后，同银行的其他卡片也会使用这个银行名称。").font(.caption).foregroundStyle(palette.warning)
            }
            WalletFormField(title: "银行卡号 *") {
                HStack(spacing: 10) {
                    TextField("银行卡号", text: $cardNumber, prompt: Text("输入 13–19 位银行卡号"))
                        .focused($focusedField, equals: .cardNumber)
                        .onChange(of: cardNumber) { _, newValue in
                            cardNumber = formatCardNumber(String(newValue.filter(\.isNumber).prefix(19)))
                            checkExistingSharedLimit()
                        }
                    CardBrandIcon(brand: CardBrand.detect(from: cardNumber, level: level)).frame(width: 40)
                }
            }
            HStack(alignment: .top, spacing: 18) {
                WalletFormField(title: "卡片别名") {
                    TextField("卡片别名", text: $alias, prompt: Text("例如：日常消费卡"))
                        .focused($focusedField, equals: .alias)
                }
                WalletFormField(title: "有效期 *") {
                    TextField("有效期", text: $valid, prompt: Text("MM/YY，例如 08/29"))
                        .onChange(of: valid) { _, newValue in valid = String(newValue.prefix(5)) }
                }
                WalletFormField(title: "CVV 安全码") {
                    SecureField("CVV 安全码", text: $cvv, prompt: Text("3–4 位数字"))
                        .focused($focusedField, equals: .cvv)
                        .onChange(of: cvv) { _, newValue in cvv = String(newValue.filter(\.isNumber).prefix(4)) }
                }
            }
            CardLevelPickerField(level: $level)
            if isDebitCard {
                EditableOptionField(title: "币种", text: $type, options: currencies)
            }
        }
    }

    private var limitFields: some View {
        WalletFormSection(title: "额度与年费", icon: "yensign.circle") {
            HStack(alignment: .top, spacing: 18) {
                EditableOptionField(title: "币种", text: $type, options: currencies)
                    .onChange(of: type) { _, _ in checkExistingSharedLimit() }
                WalletFormField(title: "信用额度") {
                    TextField("信用额度", text: $limitText, prompt: Text("选填"))
                        .focused($focusedField, equals: .limit)
                        .onChange(of: limitText) { _, value in limitText = filterAmountInput(value) }
                }
                if !isUltimateFreeFee { WalletFormField(title: "年费金额") {
                    TextField("年费金额", text: $annualFeeText, prompt: Text("选填"))
                        .focused($focusedField, equals: .annualFee)
                        .onChange(of: annualFeeText) { _, value in annualFeeText = filterAmountInput(value) }
                } }
            }
            Toggle("共享该行额度", isOn: $isSharedLimit)
                .toggleStyle(.checkbox)
                .onChange(of: isSharedLimit) { _, _ in checkExistingSharedLimit() }
            if isSharedLimit && existingSharedCard != nil {
                Text("保存后，同银行、地区和币种的共享卡片会一起更新额度。").font(.caption).foregroundStyle(palette.accent)
            }
            WalletChoiceBar(title: "年费减免政策", selection: $isQualified, choices: [
                WalletChoice(value: "", title: "未选择"), WalletChoice(value: "2", title: "未达标"),
                WalletChoice(value: "1", title: "已达标"), WalletChoice(value: "3", title: "终免年费")
            ], showsTitle: true)
            .onChange(of: isQualified) { _, value in
                isUltimateFreeFee = value == "3"
                if isUltimateFreeFee { nextAnnualFeeCollectionTime = nil }
            }
            HStack(alignment: .top, spacing: 18) {
                if !isUltimateFreeFee {
                    OptionalDatePickerRow(title: "下次年费收取日", date: $nextAnnualFeeCollectionTime)
                }
                OptionalDatePickerRow(title: "上次提额时间", date: $lastTime)
            }
        }
    }

    private var billingFields: some View {
        WalletFormSection(title: "账单与还款", icon: "calendar") {
            HStack(alignment: .top, spacing: 18) {
                WalletFormField(title: "账单日") {
                    TextField("账单日", text: $accountBillDate, prompt: Text("每月 1–31 日"))
                        .focused($focusedField, equals: .billDate)
                        .onChange(of: accountBillDate) { _, value in accountBillDate = validateDateInput(value) }
                }
                WalletFormField(title: "还款日") {
                    TextField("还款日", text: $dueDate, prompt: Text("每月 1–31 日"))
                        .focused($focusedField, equals: .dueDate)
                        .onChange(of: dueDate) { _, value in dueDate = validateDateInput(value) }
                }
            }
            WalletChoiceBar(title: "账单日当天消费计入", selection: $billingDaySpendingToNextBill, choices: [
                WalletChoice(value: true, title: "下一期账单"), WalletChoice(value: false, title: "当期账单")
            ], showsTitle: true)
        }
    }

    private var noteFields: some View {
        WalletFormSection(title: "权益与备注", icon: "text.alignleft") {
            WalletFormField(title: "卡片权益") {
                TextField("卡片权益", text: $equity, prompt: Text("例如：积分、出行礼遇"), axis: .vertical)
                    .focused($focusedField, equals: .equity).lineLimit(2...4)
            }
            WalletFormField(title: "个人备注") {
                TextField("个人备注", text: $remark, prompt: Text("记录使用习惯或注意事项"), axis: .vertical)
                    .focused($focusedField, equals: .remark).lineLimit(2...4)
            }
        }
    }

    private var imageFields: some View {
        WalletFormSection(title: "卡片图片", icon: "photo.on.rectangle") {
            HStack {
                Text("\(cardImages.count) 张 · 总大小 \(formatFileSize(cardImages.reduce(0) { $0 + imageByteSize($1) }))")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { isImportingImages = true } label: {
                    Label(isImportingPhotoData ? "正在添加图片" : "添加图片", systemImage: "photo.badge.plus")
                }.disabled(isImportingPhotoData)
            }
            if cardImages.isEmpty {
                Text("可以添加卡片照片，方便日后查看。").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cardImages) { image in
                            VStack(alignment: .leading, spacing: 6) {
                                CardImageView(asset: image, pixels: 340).frame(width: 150, height: 94)
                                HStack {
                                    Text(image.name.isEmpty ? String(localized: "卡片图片") : image.name)
                                        .font(.caption).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Button(role: .destructive) { cardImages.removeAll { $0.id == image.id } } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless).help("移除图片").accessibilityLabel("移除图片")
                                }.frame(width: 150)
                                Text(formatFileSize(imageByteSize(image))).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var editorFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !validationMessage.isEmpty || !imageImportError.isEmpty {
                Label(validationMessage.isEmpty ? imageImportError : validationMessage, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(validationMessage.isEmpty ? palette.warning : .red)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            HStack {
                Label("仅在保存后更新卡片", systemImage: "lock").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("取消", action: requestDismiss).keyboardShortcut(.cancelAction)
                Button(action: saveCard) {
                    if isSaving { ProgressView().controlSize(.small).accessibilityLabel("保存卡片") }
                    else { Text("保存卡片") }
                }
                    .buttonStyle(.borderedProminent).disabled(isImportingPhotoData || isSaving).keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
        .background(palette.surface.opacity(0.4))
        .overlay(alignment: .top) { palette.line.frame(height: 1) }
    }

    private var draftSnapshot: [String] {
        [country, cardCategory, bank, cardNumber, alias, level, type, limitText, cvv, valid, annualFeeText, isQualified,
         nextAnnualFeeCollectionTime.map { String(Calendar.current.startOfDay(for: $0).timeIntervalSince1970) } ?? "", lastTime.map { String(Calendar.current.startOfDay(for: $0).timeIntervalSince1970) } ?? "",
         accountBillDate, dueDate, String(billingDaySpendingToNextBill), equity, remark, String(isSharedLimit)] + cardImages.map(\.id)
    }
    private var hasUnsavedChanges: Bool { didLoad && draftSnapshot != originalDraft }
    private func requestDismiss() {
        guard !isSaving else { return }
        if hasUnsavedChanges { showingDiscardConfirmation = true } else { dismiss() }
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
        cardNumber = formatCardNumber(String(card.cardNumber.filter(\.isNumber).prefix(19)))
        alias = card.alias ?? ""
        level = CardLevelGroup.normalize(card.level ?? "")
        type = card.type ?? ""
        limitText = formatEditableAmount(card.limit)
        cvv = String((card.cvv ?? "").filter(\.isNumber).prefix(4))
        valid = String((card.valid ?? "").prefix(5))
        annualFeeText = formatEditableAmount(card.annualFee)
        isQualified = card.isQualified ?? ""
        isUltimateFreeFee = (isQualified == "3")
        
        if !isUltimateFreeFee, let date = DateCalculator.date(fromTimestamp: card.nextAnnualFeeCollectionTime) {
            nextAnnualFeeCollectionTime = date
        } else {
            nextAnnualFeeCollectionTime = nil
        }
        if let date = DateCalculator.date(fromTimestamp: card.lastTime) {
            lastTime = date
        } else {
            lastTime = nil
        }
        
        accountBillDate = validateDateInput(card.accountBillDate ?? "")
        dueDate = validateDateInput(card.dueDate ?? "")
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
        guard !isSaving, !isLocked else { return }
        guard !country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = String(localized: "请填写国家或地区。")
            return
        }
        guard !bank.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = String(localized: "请填写发卡银行。")
            return
        }
        
        // 卡号基本验证
        let cleanNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        guard cleanNumber.count >= 13 && cleanNumber.count <= 19 else {
            validationMessage = String(localized: "请填写十三到十九位银行卡号。")
            focusedField = .cardNumber
            return
        }
        guard isValidExpiry(valid) else {
            validationMessage = String(localized: "请按月月/年年填写有效期，例如 08/29。")
            return
        }
        guard isDebitCard || limitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parseAmount(limitText) != nil else {
            validationMessage = String(localized: "请填写有效的信用额度。")
            focusedField = .limit
            return
        }
        guard isDebitCard || annualFeeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parseAmount(annualFeeText) != nil else {
            validationMessage = String(localized: "请填写有效的年费金额。")
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
            cardImages: cardImages,
            extraFields: cardToEdit?.extraFields ?? [:]
        )
        
        isSaving = true
        saveTask = Task { @MainActor in
            defer { isSaving = false }
            do {
                try Task.checkCancellation()
                guard !isLocked else { throw CancellationError() }
                try await onSubmit(finalCard)
                guard !isLocked, !Task.isCancelled else { return }
                dismiss()
            } catch is CancellationError { }
            catch { if !isLocked { validationMessage = String(localized: "未能保存卡片，请重试；已有数据没有被更改") } }
        }
    }

    private func importImageFiles(_ urls: [URL]) {
        guard CardImagePolicy.canAppend(existing: cardImages.count, incoming: urls.count) else {
            imageImportError = String(localized: "每张卡最多添加20张图片，原有图片不受影响。")
            return
        }
        isImportingPhotoData = true
        imageImportError = ""
        importTask?.cancel()
        importTask = Task {
            let imported = await Task.detached(priority: .utility) { CardImageImporter.read(urls) }.value
            guard !Task.isCancelled else { return }
            guard CardImagePolicy.canAppend(existing: cardImages.count, incoming: imported.count) else {
                isImportingPhotoData = false
                imageImportError = String(localized: "图片未能添加，请检查数量、格式及大小。")
                return
            }
            cardImages.append(contentsOf: imported)
            isImportingPhotoData = false
            if imported.count != urls.count { imageImportError = String(localized: "部分图片未能添加，请检查文件后重试。") }
        }
    }

    private func imageByteSize(_ asset: CardImageAsset) -> Int64 {
        CardImageView.byteCount(asset)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
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
        WalletFormField(title: "卡片等级") {
          HStack(spacing: 12) {
            Picker("卡组织", selection: brandBinding) {
                Text("请选择卡组织").tag("")
                ForEach(CardLevelGroup.all, id: \.brand) { group in
                    Text(group.brand).tag(group.brand)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Picker("等级", selection: levelBinding) {
                Text("请选择等级").tag("")
                ForEach(selectedGroup?.levels ?? [], id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .disabled(selectedGroup == nil)

          }
          if !level.isEmpty { Text(level).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct EditableOptionField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let options: [String]

    private var filteredOptions: [String] {
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(keyword) }
    }

    var body: some View {
        WalletFormField(title: title) {
          HStack(spacing: 8) {
            TextField(title, text: $text, prompt: Text("可输入或选择"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()

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
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(title)
          }
        }
    }
}

private struct OptionalDatePickerRow: View {
    let title: LocalizedStringKey
    @Binding var date: Date?

    var body: some View {
        WalletFormField(title: title) {
            HStack {
                if date == nil {
                    Button("选择日期") { date = Date() }
                } else {
                    DatePicker(title, selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: .date)
                        .labelsHidden()
                    Button("清除") { date = nil }.buttonStyle(.borderless)
                }
                Spacer(minLength: 0)
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
