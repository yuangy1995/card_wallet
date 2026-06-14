import SwiftUI
import PhotosUI
import UIKit
import Vision
#if canImport(CoreNFC)
import CoreNFC
#endif

struct CardEditView: View {
    @Environment(\.dismiss) private var dismiss

    var mode: String
    var cardToEdit: SharedCard?
    var initialCardCategory: String
    var existingCards: [SharedCard]
    var onSubmit: (SharedCard) -> Void

    // 表单状态
    @State private var cardCategory = "credit"
    @State private var country = ""
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
    @State private var isUltimateFreeFee = false
    @State private var nextAnnualFeeCollectionTime: Date?
    @State private var lastTime: Date?
    @State private var accountBillDate = ""
    @State private var dueDate = ""
    @State private var billingDaySpendingToNextBill = true
    @State private var isSharedLimit = true
    @State private var equity = ""
    @State private var remark = ""
    @State private var cardImages: [CardImageAsset] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var scanPhotoItem: PhotosPickerItem?
    @State private var existingSharedCard: SharedCard?
    @State private var validationMessage = ""
    @State private var showValidationAlert = false
    @State private var showCameraScanner = false
    @State private var isScanningImage = false
    @State private var feedbackTitle = ""
    @State private var feedbackMessage = ""
    @State private var showFeedbackAlert = false

    @State private var showNextFeeDatePicker = false
    @State private var showLastTimePicker = false

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case cardNumber, alias, cvv, limit, annualFee, billDate, dueDate, equity, remark
    }

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

    private var countryOptions: [String] {
        mergedOptions(countries, existingCards.map(\.country))
    }

    private var bankOptions: [String] {
        mergedOptions(banks, existingCards.map(\.bank))
    }

    private var levelOptions: [String] {
        mergedOptions(levels, existingCards.compactMap(\.level))
    }

    private var currencyOptions: [String] {
        mergedOptions(currencies, existingCards.compactMap(\.type))
    }

    init(
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

    var body: some View {
        NavigationStack {
            Form {
                // 卡类型切换
                cardCategorySection

                quickInputSection

                // 基础信息
                basicInfoSection

                // 财务信息（仅信用卡）
                if cardCategory != "debit" {
                    financialInfoSection
                }

                // 账单信息
                billingSection

                // 年费信息（仅信用卡）
                if cardCategory != "debit" {
                    annualFeeSection
                }

                // 权益备注
                equityRemarkSection

                cardMediaSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .tint(.cyan)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(mode == "add" ? "新增\(cardCategory == "debit" ? "储蓄卡" : "信用卡")" : "编辑卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveCard() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { setupInitialValues() }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task { await importSelectedPhotos(newItems) }
            }
            .onChange(of: scanPhotoItem) { _, newItem in
                Task { await scanSelectedPhoto(newItem) }
            }
            .sheet(isPresented: $showCameraScanner) {
                CameraImagePicker { image in
                    handleScannedImage(image, source: "ios_camera_scan")
                }
                .ignoresSafeArea()
            }
            .alert("无法保存", isPresented: $showValidationAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .alert(feedbackTitle, isPresented: $showFeedbackAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(feedbackMessage)
            }
        }
    }

    // MARK: - 卡类型
    private var cardCategorySection: some View {
        Section {
            Picker("卡片类型", selection: $cardCategory) {
                Text("信用卡").tag("credit")
                Text("储蓄卡").tag("debit")
            }
            .pickerStyle(.segmented)
            .onChange(of: cardCategory) { _, _ in
                checkExistingSharedLimit()
            }
        }
    }

    // MARK: - 快速录入
    private var quickInputSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showCameraScanner = true
                        } else {
                            showFeedback(title: "无法打开相机", message: "当前环境没有可用相机。真机安装后可以直接拍照识别卡号和有效期。")
                        }
                    } label: {
                        ScanActionLabel(title: "拍照识别", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $scanPhotoItem, matching: .images) {
                        ScanActionLabel(title: "相册识别", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showNFCInfo()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "wave.3.right.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(nfcAvailable ? Color.cyan : Color.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NFC 读取")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(nfcAvailable ? "仅在点击后读取，不会后台常驻" : "模拟器不可用，真机需 NFC 权限")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                if isScanningImage {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("正在识别卡面文字…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        } header: {
            Label("快速录入", systemImage: "sparkles")
        } footer: {
            Text("相机和相册识别会优先提取卡号、有效期，并尝试匹配已有银行。NFC 不会在非读取页面常驻。")
        }
    }

    // MARK: - 基础信息
    private var basicInfoSection: some View {
        Section("基础信息") {
            EditableOptionField(
                title: "发卡国家",
                systemImage: "globe",
                placeholder: "可输入或选择",
                text: $country,
                options: countryOptions
            )
            .onChange(of: country) { _, _ in
                checkExistingSharedLimit()
            }

            EditableOptionField(
                title: "发卡行",
                systemImage: "building.columns.fill",
                placeholder: "可输入或选择",
                text: $bank,
                options: bankOptions
            )
            .onChange(of: bank) { _, _ in
                checkExistingSharedLimit()
            }

            // 卡号
            HStack {
                Label("卡号", systemImage: "creditcard")
                TextField("请输入卡号", text: $cardNumber)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .cardNumber)
                    .multilineTextAlignment(.trailing)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: cardNumber) { _, newValue in
                        cardNumber = newValue.filter { $0.isNumber }
                    }
            }

            // 别名
            HStack {
                Label("别名", systemImage: "tag.fill")
                TextField("如：招行大白金", text: $alias)
                    .focused($focusedField, equals: .alias)
                    .multilineTextAlignment(.trailing)
            }

            EditableOptionField(
                title: "卡级别",
                systemImage: "crown.fill",
                placeholder: "可输入或选择",
                text: $level,
                options: levelOptions
            )

            EditableOptionField(
                title: "币种",
                systemImage: "dollarsign.circle.fill",
                placeholder: "留空或选择",
                text: $type,
                options: currencyOptions,
                uppercase: true,
                allowClearing: true
            )
            .onChange(of: type) { _, _ in
                checkExistingSharedLimit()
            }
        }
    }

    // MARK: - 财务信息
    private var financialInfoSection: some View {
        Section("财务信息") {
            HStack {
                Label("授信额度", systemImage: "banknote.fill")
                TextField("0", text: $limitText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .limit)
                    .multilineTextAlignment(.trailing)
            }
            Toggle(isOn: $isSharedLimit) {
                Label("共享额度", systemImage: "arrow.triangle.2.circlepath")
            }
            .onChange(of: isSharedLimit) { _, _ in
                checkExistingSharedLimit()
            }
            if isSharedLimit, let existingSharedCard {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .foregroundColor(.green)
                    Text("已匹配同银行共享额度组：\(formatEditableAmount(existingSharedCard.limit)) \(type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (existingSharedCard.type ?? "") : type)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 账单信息
    private var billingSection: some View {
        Section("账单信息") {
            HStack {
                Label("账单日", systemImage: "calendar")
                TextField("如：10（号）", text: $accountBillDate)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .billDate)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: accountBillDate) { _, v in
                        if let n = Int(v), n > 31 { accountBillDate = "31" }
                    }
            }
            HStack {
                Label("还款日", systemImage: "calendar.badge.checkmark")
                TextField("如：28（号）", text: $dueDate)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .dueDate)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: dueDate) { _, v in
                        if let n = Int(v), n > 31 { dueDate = "31" }
                    }
            }
            Toggle(isOn: $billingDaySpendingToNextBill) {
                Label("账单日消费计入下期", systemImage: "arrow.forward.circle.fill")
            }
            if !accountBillDate.isEmpty && !dueDate.isEmpty {
                let days = DateCalculator.calculateInterestFreePeriod(
                    accountBillDate: accountBillDate, dueDate: dueDate,
                    billingDayToNextBill: billingDaySpendingToNextBill)
                HStack {
                    Label("最长免息期", systemImage: "clock.fill")
                    Spacer()
                    Text("\(days) 天")
                        .foregroundColor(.cyan)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - 年费信息
    private var annualFeeSection: some View {
        Section("年费信息") {
            HStack {
                Label("年费金额", systemImage: "dollarsign.circle")
                TextField("0", text: $annualFeeText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .annualFee)
                    .multilineTextAlignment(.trailing)
            }
            if !isUltimateFreeFee {
                Picker(selection: $isQualified) {
                    Text("未达标").tag("2")
                    Text("已达标").tag("1")
                } label: {
                    Label("年费达标状态", systemImage: "checkmark.seal.fill")
                }
                // 下次收费时间
                HStack {
                    Label("下次收费时间", systemImage: "clock.badge.exclamationmark.fill")
                    Spacer()
                    if let date = nextAnnualFeeCollectionTime {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    } else {
                        Text("未设置").foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { showNextFeeDatePicker = true }
                .sheet(isPresented: $showNextFeeDatePicker) {
                    DatePickerSheet(title: "下次年费收取时间", date: $nextAnnualFeeCollectionTime)
                }
            }
            Toggle(isOn: $isUltimateFreeFee) {
                Label("终免年费", systemImage: "infinity.circle.fill")
            }
            .onChange(of: isUltimateFreeFee) { _, v in if v { isQualified = "3" } else { isQualified = "2" } }
            // 上次提额时间
            HStack {
                Label("上次提额时间", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
                if let date = lastTime {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.secondary)
                } else {
                    Text("未设置").foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { showLastTimePicker = true }
            .sheet(isPresented: $showLastTimePicker) {
                DatePickerSheet(title: "上次提额时间", date: $lastTime)
            }
        }
    }

    // MARK: - CVV / 有效期 / 权益备注
    private var equityRemarkSection: some View {
        Section("安全 & 附加信息") {
            HStack {
                Label("CVV", systemImage: "lock.shield.fill")
                TextField("•••", text: $cvv)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .cvv)
                    .multilineTextAlignment(.trailing)
            }
            // 有效期
            HStack {
                Label("有效期 (MM/YY)", systemImage: "calendar.badge.clock")
                TextField("如：08/28", text: $valid)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: valid) { _, v in
                        let digits = v.filter { $0.isNumber }
                        if digits.count >= 4 {
                            let month = String(digits.prefix(2))
                            let year = String(digits.dropFirst(2).prefix(2))
                            valid = "\(month)/\(year)"
                        }
                    }
            }
            HStack {
                Label("权益描述", systemImage: "star.fill")
                TextField("如：免费机场贵宾厅…", text: $equity, axis: .vertical)
                    .focused($focusedField, equals: .equity)
                    .lineLimit(3...6)
            }
            HStack {
                Label("备注", systemImage: "note.text")
                TextField("备注信息…", text: $remark, axis: .vertical)
                    .focused($focusedField, equals: .remark)
                    .lineLimit(2...4)
            }
        }
    }

    private var cardMediaSection: some View {
        Section("卡片媒体文件") {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 8,
                matching: .images
            ) {
                Label("添加卡片图片", systemImage: "photo.badge.plus")
            }

            if cardImages.isEmpty {
                Text("暂无卡片图片。添加后会随云同步带到其它设备。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cardImages) { image in
                            VStack(alignment: .leading, spacing: 6) {
                                if let uiImage = uiImage(from: image) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 150, height: 96)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                        }
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: 150, height: 96)
                                        .overlay {
                                            Text("无法预览")
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                        }
                                }

                                HStack(spacing: 8) {
                                    Text(image.name.isEmpty ? image.source : image.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Button(role: .destructive) {
                                        cardImages.removeAll { $0.id == image.id }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .frame(width: 150)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Save
    private func saveCard() {
        let cleanCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBank = bank.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNumber = cardNumber.filter { $0.isNumber }
        let cleanValid = DataMigrationManager.convertValidToMMYY(valid.isEmpty ? nil : valid)
        let cleanType = type.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cleanCountry.isEmpty {
            showValidation("请选择或输入发卡国家")
            return
        }
        if cleanBank.isEmpty {
            showValidation("请选择或输入发卡银行")
            return
        }
        if cleanNumber.isEmpty {
            focusedField = .cardNumber
            showValidation("请输入银行卡号")
            return
        }
        if cleanNumber.count < 13 || cleanNumber.count > 20 {
            focusedField = .cardNumber
            showValidation("卡号长度需为 13-20 位")
            return
        }
        if !isValidExpiry(cleanValid) {
            showValidation("请输入有效期，格式为 MM/YY")
            return
        }
        if !cvv.isEmpty && cvv.range(of: "^\\d{3,4}$", options: .regularExpression) == nil {
            focusedField = .cvv
            showValidation("CVV 需要是 3-4 位数字")
            return
        }
        if cardCategory != "debit", !limitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, parseAmount(limitText) == nil {
            focusedField = .limit
            showValidation("请输入正确的额度")
            return
        }
        if cardCategory != "debit", !annualFeeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, parseAmount(annualFeeText) == nil {
            focusedField = .annualFee
            showValidation("请输入正确的年费金额")
            return
        }

        let isDebitCard = cardCategory == "debit"
        let limit = isDebitCard ? 0 : (parseAmount(limitText) ?? 0)
        let annualFee = isDebitCard ? 0 : (parseAmount(annualFeeText) ?? 0)
        let newCard = SharedCard(
            id: cardToEdit?.id ?? UUID().uuidString,
            cardCategory: cardCategory,
            country: cleanCountry,
            bank: cleanBank,
            cardNumber: cleanNumber,
            alias: alias.trimmedNilIfEmpty,
            level: level.trimmedNilIfEmpty,
            type: cleanType,
            limit: limit,
            cvv: cvv.trimmedNilIfEmpty,
            valid: cleanValid,
            annualFee: annualFee,
            isQualified: isDebitCard ? "" : (isUltimateFreeFee ? "3" : isQualified),
            nextAnnualFeeCollectionTime: isDebitCard || isUltimateFreeFee ? nil : nextAnnualFeeCollectionTime.map { $0.timeIntervalSince1970 * 1000 },
            lastTime: isDebitCard ? nil : lastTime.map { $0.timeIntervalSince1970 * 1000 },
            accountBillDate: isDebitCard ? nil : accountBillDate.trimmedNilIfEmpty,
            dueDate: isDebitCard ? nil : dueDate.trimmedNilIfEmpty,
            billingDaySpendingToNextBill: billingDaySpendingToNextBill,
            equity: equity.trimmedNilIfEmpty,
            remark: remark.trimmedNilIfEmpty,
            lastModifyTime: DataMigrationManager.currentTimestampMilliseconds(),
            isSharedLimit: isDebitCard ? false : isSharedLimit,
            cardImages: cardImages
        )
        onSubmit(newCard)
        dismiss()
    }

    private func showValidation(_ message: String) {
        validationMessage = message
        showValidationAlert = true
    }

    private func checkExistingSharedLimit() {
        guard cardCategory != "debit", isSharedLimit else {
            existingSharedCard = nil
            return
        }

        let cleanCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBank = bank.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanType = type.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanBank.isEmpty else {
            existingSharedCard = nil
            return
        }

        let match = existingCards.first { item in
            let itemType = (item.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return item.id != cardToEdit?.id &&
                item.cardCategory != "debit" &&
                item.country == cleanCountry &&
                itemType == cleanType &&
                item.isSharedLimit &&
                BankNameNormalizer.namesReferToSameBank(item.bank, cleanBank)
        }

        existingSharedCard = match
        if mode == "add", let match {
            limitText = formatEditableAmount(match.limit)
            if cleanType.isEmpty {
                type = match.type ?? ""
            }
        }
    }

    private func parseAmount(_ input: String) -> Double? {
        let cleaned = input
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let value = Double(cleaned), value >= 0 else { return nil }
        return value
    }

    private func formatEditableAmount(_ value: Double?) -> String {
        guard let value, value > 0 else { return "" }
        if value.rounded(.towardZero) == value {
            return String(Int(value))
        }
        return String(value)
    }

    private func isValidExpiry(_ input: String) -> Bool {
        guard input.range(of: "^\\d{2}/\\d{2}$", options: .regularExpression) != nil,
              let month = Int(input.prefix(2)) else {
            return false
        }
        return (1...12).contains(month)
    }

    private func importSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var imported: [CardImageAsset] = []
        for (index, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let payload = normalizedImagePayload(from: data) else { continue }
            imported.append(CardImageAsset(
                mimeType: payload.mimeType,
                data: "data:\(payload.mimeType);base64,\(payload.data.base64EncodedString())",
                source: "ios_upload",
                name: "card_image_\(cardImages.count + imported.count + index + 1).jpg"
            ))
        }
        if !imported.isEmpty {
            cardImages.append(contentsOf: imported)
        }
        selectedPhotoItems = []
    }

    private func normalizedImagePayload(from data: Data) -> (data: Data, mimeType: String)? {
        guard let image = UIImage(data: data) else {
            return (data, "image/jpeg")
        }
        let maxEdge: CGFloat = 1600
        let longestEdge = max(image.size.width, image.size.height)
        let scale = longestEdge > maxEdge ? maxEdge / longestEdge : 1
        let targetSize = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpegData = resized.jpegData(compressionQuality: 0.84) else { return nil }
        return (jpegData, "image/jpeg")
    }

    private func uiImage(from asset: CardImageAsset) -> UIImage? {
        let base64 = asset.data.components(separatedBy: "base64,").last ?? asset.data
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    private func scanSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { scanPhotoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            showFeedback(title: "识别失败", message: "无法读取这张图片，请换一张更清晰的卡面照片。")
            return
        }
        handleScannedImage(image, source: "ios_photo_scan")
    }

    private func handleScannedImage(_ image: UIImage, source: String) {
        guard !isScanningImage else { return }
        isScanningImage = true
        Task {
            let result = await CardImageTextScanner.recognize(
                image: image,
                countries: countryOptions,
                banks: bankOptions,
                levels: levelOptions
            )
            let imageAsset = makeImageAsset(from: image, source: source)
            await MainActor.run {
                applyScanResult(result, imageAsset: imageAsset)
                isScanningImage = false
            }
        }
    }

    private func makeImageAsset(from image: UIImage, source: String) -> CardImageAsset? {
        guard let data = image.jpegData(compressionQuality: 0.92),
              let payload = normalizedImagePayload(from: data) else { return nil }
        return CardImageAsset(
            mimeType: payload.mimeType,
            data: "data:\(payload.mimeType);base64,\(payload.data.base64EncodedString())",
            source: source,
            name: "\(source)_\(cardImages.count + 1).jpg"
        )
    }

    private func applyScanResult(_ result: CardScanResult, imageAsset: CardImageAsset?) {
        var changedFields: [String] = []

        if let imageAsset {
            cardImages.append(imageAsset)
        }
        if let cardNumber = result.cardNumber, self.cardNumber.isEmpty {
            self.cardNumber = cardNumber
            changedFields.append("卡号")
        }
        if let expiry = result.expiry, valid.isEmpty {
            valid = expiry
            changedFields.append("有效期")
        }
        if let matchedBank = result.bank, bank.isEmpty {
            bank = matchedBank
            changedFields.append("发卡行")
        }
        if let matchedCountry = result.country, country.isEmpty {
            country = matchedCountry
            changedFields.append("发卡国家")
        }
        if let matchedLevel = result.level, level.isEmpty {
            level = matchedLevel
            changedFields.append("卡级别")
        }

        checkExistingSharedLimit()

        let message: String
        if changedFields.isEmpty {
            message = "没有识别到可自动填写的卡号或有效期。图片已添加到卡片媒体文件，可手动核对后保存。"
        } else {
            message = "已填入：\(changedFields.joined(separator: "、"))。请在保存前核对卡号、有效期和银行名称。"
        }
        showFeedback(title: "识别完成", message: message)
    }

    private var nfcAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #elseif canImport(CoreNFC)
        return NFCTagReaderSession.readingAvailable
        #else
        return false
        #endif
    }

    private func showNFCInfo() {
        if nfcAvailable {
            showFeedback(
                title: "NFC 读取说明",
                message: "iOS 可以在真机上通过 CoreNFC 做一次性读取，但需要 NFC Tag Reading 权限和 EMV APDU 解析。这里不会像旧 Android 那样全局常驻读取；后续接入时也只会在你点击读取后启动会话。"
            )
        } else {
            showFeedback(
                title: "NFC 当前不可用",
                message: "模拟器无法使用 NFC。真机读取银行卡还需要开启 NFC Tag Reading entitlement，并受 iOS 对银行卡 NFC 的系统限制；目前建议优先使用拍照或相册识别录入。"
            )
        }
    }

    private func showFeedback(title: String, message: String) {
        feedbackTitle = title
        feedbackMessage = message
        showFeedbackAlert = true
    }

    private func mergedOptions(_ primary: [String], _ secondary: [String]) -> [String] {
        var seen = Set<String>()
        return (primary + secondary)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { value in
                guard !value.isEmpty else { return false }
                let key = value.lowercased()
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
    }

    // MARK: - Setup
    private func setupInitialValues() {
        if let card = cardToEdit {
            cardCategory = card.cardCategory
            country = card.country
            bank = card.bank
            cardNumber = card.cardNumber
            alias = card.alias ?? ""
            level = card.level ?? ""
            type = card.type ?? ""
            limitText = formatEditableAmount(card.limit)
            cvv = card.cvv ?? ""
            valid = card.valid ?? ""
            annualFeeText = formatEditableAmount(card.annualFee)
            isQualified = card.isQualified ?? ""
            isUltimateFreeFee = card.isQualified == "3"
            nextAnnualFeeCollectionTime = DataMigrationManager.date(fromTimestamp: card.nextAnnualFeeCollectionTime)
            lastTime = DataMigrationManager.date(fromTimestamp: card.lastTime)
            accountBillDate = card.accountBillDate ?? ""
            dueDate = card.dueDate ?? ""
            billingDaySpendingToNextBill = card.billingDaySpendingToNextBill
            isSharedLimit = card.isSharedLimit
            equity = card.equity ?? ""
            remark = card.remark ?? ""
            cardImages = card.cardImages
        } else {
            cardCategory = initialCardCategory == "debit" ? "debit" : "credit"
            country = ""
            type = ""
            isQualified = ""
            billingDaySpendingToNextBill = true
            isSharedLimit = true
            cardImages = []
        }
        checkExistingSharedLimit()
    }
}

// MARK: - 日期选择 Sheet
private struct DatePickerSheet: View {
    let title: String
    @Binding var date: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("清除") { date = nil; dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") { date = selectedDate; dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { selectedDate = date ?? Date() }
    }
}

private struct ScanActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(Color.cyan)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.cyan.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

private struct CardScanResult {
    var cardNumber: String?
    var expiry: String?
    var bank: String?
    var country: String?
    var level: String?
}

private enum CardImageTextScanner {
    static func recognize(
        image: UIImage,
        countries: [String],
        banks: [String],
        levels: [String]
    ) async -> CardScanResult {
        guard let cgImage = image.cgImage else { return CardScanResult() }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return CardScanResult()
        }

        let lines = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return CardScanResult(
            cardNumber: extractCardNumber(from: lines),
            expiry: extractExpiry(from: lines),
            bank: firstContainedOption(in: lines, options: banks),
            country: firstContainedOption(in: lines, options: countries),
            level: firstContainedOption(in: lines, options: levels) ?? inferredLevel(from: lines)
        )
    }

    private static func extractCardNumber(from lines: [String]) -> String? {
        let joined = lines.joined(separator: " ")
        let candidates = regexMatches(pattern: "(?:\\d[\\s-]?){13,20}", in: joined)
            .map { $0.filter(\.isNumber) }
            .filter { (13...20).contains($0.count) }
        if let valid = candidates.first(where: luhnValid) {
            return valid
        }
        return candidates.max { $0.count < $1.count }
    }

    private static func extractExpiry(from lines: [String]) -> String? {
        let joined = lines.joined(separator: " ")
        let candidates = regexMatches(pattern: "(0[1-9]|1[0-2])\\s*[/\\-]\\s*(\\d{2}|\\d{4})", in: joined)
        for candidate in candidates {
            let digits = candidate.filter(\.isNumber)
            if digits.count == 4 {
                return "\(digits.prefix(2))/\(digits.suffix(2))"
            }
            if digits.count == 6 {
                return "\(digits.prefix(2))/\(digits.suffix(2))"
            }
        }
        return nil
    }

    private static func firstContainedOption(in lines: [String], options: [String]) -> String? {
        let haystack = lines.joined(separator: " ")
        return options.first { option in
            haystack.localizedCaseInsensitiveContains(option)
        }
    }

    private static func inferredLevel(from lines: [String]) -> String? {
        let haystack = lines.joined(separator: " ").lowercased()
        if haystack.contains("visa") { return "VISA" }
        if haystack.contains("mastercard") || haystack.contains("master card") { return "MasterCard" }
        if haystack.contains("unionpay") || haystack.contains("银联") { return "银联" }
        if haystack.contains("jcb") { return "JCB" }
        if haystack.contains("american express") || haystack.contains("amex") { return "AE" }
        return nil
    }

    private static func regexMatches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private static func luhnValid(_ number: String) -> Bool {
        let digits = number.compactMap { Int(String($0)) }
        guard digits.count == number.count, digits.count >= 13 else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { partial, item in
            let (offset, digit) = item
            if offset.isMultiple(of: 2) {
                return partial + digit
            }
            let doubled = digit * 2
            return partial + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum.isMultiple(of: 10)
    }
}

private struct EditableOptionField: View {
    let title: String
    let systemImage: String
    let placeholder: String
    @Binding var text: String
    let options: [String]
    var uppercase = false
    var allowClearing = false

    private var filteredOptions: [String] {
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(keyword) }
    }

    private var visibleSuggestions: [String] {
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return [] }
        return Array(filteredOptions.filter { $0 != text }.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(title, systemImage: systemImage)
                TextField(placeholder, text: Binding(
                    get: { text },
                    set: { newValue in
                        text = uppercase ? newValue.uppercased() : newValue
                    }
                ))
                .autocorrectionDisabled()
                .textInputAutocapitalization(uppercase ? .characters : .never)
                .multilineTextAlignment(.trailing)

                Menu {
                    if allowClearing {
                        Button("清空") { text = "" }
                        Divider()
                    }
                    if filteredOptions.isEmpty {
                        Text("没有匹配项，可直接保存当前输入")
                    } else {
                        ForEach(Array(filteredOptions.prefix(40)), id: \.self) { option in
                            Button(option) {
                                text = option
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down.circle")
                        .foregroundColor(.secondary)
                }
            }

            if !visibleSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(visibleSuggestions, id: \.self) { option in
                            Button {
                                text = option
                            } label: {
                                Text(option)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.cyan)
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.cyan.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 31)
                }
            }
        }
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
