import SwiftUI
import UIKit

struct CardDetailView: View {
    let card: SharedCard
    var onEdit: (SharedCard) -> Void
    var onDelete: (SharedCard) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var isShowingNumber = false
    @State private var isShowingCVV = false
    @State private var remainingShowSeconds = 5.0
    @State private var countdownTimer: Timer?
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedPreviewImage: CardImageAsset?
    @State private var showCopiedToast = false
    @State private var copiedToastToken = UUID()

    private var brand: CardBrand {
        CardBrand.detect(from: card.cardNumber, level: card.level)
    }

    private var interestFreeDays: Int {
        DateCalculator.calculateInterestFreePeriod(
            accountBillDate: card.accountBillDate ?? "",
            dueDate: card.dueDate ?? "",
            billingDayToNextBill: card.billingDaySpendingToNextBill
        )
    }

    private var remainingRepayDays: Int {
        DateCalculator.calculateRemainingDaysForPreviousBill(
            accountBillDate: card.accountBillDate ?? "",
            dueDate: card.dueDate ?? ""
        )
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // 大卡片展示
                    cardHeroSection

                    // 敏感信息防窥区
                    sensitiveInfoSection

                    // 卡片图片媒体文件
                    if !card.cardImages.isEmpty {
                        mediaSection
                    }

                    // 账单信息
                    billingSection

                    // 年费信息
                    if card.cardCategory != "debit" {
                        annualFeeSection
                    }

                    // 权益与备注
                    if let equity = card.equity, !equity.isEmpty {
                        equitySection(equity)
                    }
                    if let remark = card.remark, !remark.isEmpty {
                        remarkSection(remark)
                    }

                    // 修改时间
                    Text("最后修改：\(DateCalculator.formatTimestampDateTime(card.lastModifyTime))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .navigationTitle(card.bank)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { onEdit(card) } label: { Label("编辑", systemImage: "pencil") }
                    Divider()
                    Button(role: .destructive) { showDeleteAlert = true } label: { Label("删除", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { onDelete(card); dismiss() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后将无法恢复，确认删除\"\(card.bank)\"吗？")
        }
        .sheet(item: $selectedPreviewImage) { asset in
            ImagePreviewView(asset: asset)
        }
    }

    // MARK: - 大卡片
    private var cardHeroSection: some View {
        CreditCardView(card: card, onCopyCardNumber: copyCardNumber)
    }

    // MARK: - 敏感信息
    private var sensitiveInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "卡片信息", icon: "creditcard.fill", color: .cyan)
            VStack(spacing: 0) {
                infoRow(label: "完整卡号") {
                    HStack(spacing: 8) {
                        Button {
                            copyCardNumber()
                        } label: {
                            Text(isShowingNumber ? formattedFullNumber : maskedCardNumber)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("复制完整卡号")
                        Button { toggleNumber() } label: {
                            Image(systemName: isShowingNumber ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        if isShowingNumber {
                            ZStack {
                                Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1.5).frame(width: 16, height: 16)
                                Circle()
                                    .trim(from: 0, to: CGFloat(remainingShowSeconds / 5.0))
                                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                                    .frame(width: 16, height: 16)
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                    }
                }
                Divider().padding(.leading, 16)
                infoRow(label: "CVV / CVC") {
                    HStack(spacing: 8) {
                        Text(isShowingCVV ? (card.cvv ?? "—") : "•••")
                            .font(.system(.body, design: .monospaced))
                        Button { withAnimation(.spring(duration: 0.2)) { isShowingCVV.toggle() } } label: {
                            Image(systemName: isShowingCVV ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider().padding(.leading, 16)
                infoRow(label: "有效期", value: card.valid ?? "—")
                Divider().padding(.leading, 16)
                infoRow(label: "卡级别", value: card.level ?? "—")
                Divider().padding(.leading, 16)
                infoRow(label: "发卡国家", value: card.country)
                Divider().padding(.leading, 16)
                infoRow(label: "币种", value: displayCurrency(card.type))
                if let limit = card.limit, limit > 0, card.cardCategory != "debit" {
                    Divider().padding(.leading, 16)
                    infoRow(label: "授信额度", value: formatCurrency(limit, currency: card.type ?? ""))
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 账单信息
    private var billingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "账单信息", icon: "calendar.badge.clock", color: .orange)
            VStack(spacing: 0) {
                if let billDate = card.accountBillDate, !billDate.isEmpty {
                    infoRow(label: "账单日", value: "每月 \(billDate) 号")
                    Divider().padding(.leading, 16)
                }
                if let dueDate = card.dueDate, !dueDate.isEmpty {
                    let fullDueDate = DateCalculator.completeDueDate(
                        accountBillDate: card.accountBillDate ?? "",
                        dueDate: dueDate
                    )
                    infoRow(label: "本期还款日") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("每月 \(dueDate) 号").font(.system(.body))
                            if !fullDueDate.isEmpty {
                                Text("本期: \(fullDueDate)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Divider().padding(.leading, 16)
                }
                if interestFreeDays > 0 {
                    infoRow(label: "最长免息期") {
                        HStack(spacing: 4) {
                            Text("\(interestFreeDays) 天")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundColor(.cyan)
                            if remainingRepayDays > 0 {
                                Capsule()
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 60, height: 22)
                                    .overlay(
                                        Text("还剩\(remainingRepayDays)天")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.green)
                                    )
                            }
                        }
                    }
                    Divider().padding(.leading, 16)
                }
                infoRow(label: "账单日消费", value: card.billingDaySpendingToNextBill ? "计入下期" : "计入当期")
                Divider().padding(.leading, 16)
                infoRow(label: "共享额度", value: card.isSharedLimit ? "是" : "否")
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 年费信息
    private var annualFeeSection: some View {
        let qualifiedText: String
        let qualifiedColor: Color
        switch card.isQualified {
        case "1": qualifiedText = "已达标"; qualifiedColor = .green
        case "3": qualifiedText = "终免年费"; qualifiedColor = .cyan
        default:  qualifiedText = "未达标"; qualifiedColor = .orange
        }

        return VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "年费信息", icon: "dollarsign.circle.fill", color: .yellow)
            VStack(spacing: 0) {
                if let annualFee = card.annualFee, annualFee > 0 {
                    infoRow(label: "年费金额", value: formatCurrency(annualFee, currency: card.type ?? ""))
                    Divider().padding(.leading, 16)
                }
                infoRow(label: "年费状态") {
                    Text(qualifiedText)
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(qualifiedColor)
                }
                if let nextFeeTime = card.nextAnnualFeeCollectionTime {
                    Divider().padding(.leading, 16)
                    let info = DateCalculator.getDaysFromNow(nextFeeTime)
                    infoRow(label: "下次收费") {
                        HStack(spacing: 6) {
                            Text(DateCalculator.formatTimestampDate(nextFeeTime))
                            Capsule()
                                .fill((info.days <= 60 ? Color.orange : Color.secondary).opacity(0.15))
                                .frame(height: 22)
                                .overlay(
                                    Text("\(info.text)\(info.days)天")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(info.days <= 60 ? .orange : .secondary)
                                        .padding(.horizontal, 8)
                                )
                                .fixedSize()
                        }
                    }
                }
                if let lastTime = card.lastTime {
                    Divider().padding(.leading, 16)
                    infoRow(label: "上次提额", value: DateCalculator.formatTimestampDate(lastTime))
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 权益 & 备注
    private func equitySection(_ equity: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "卡片权益", icon: "star.fill", color: Color(hex: "#FFD700"))
            Text(equity)
                .font(.system(.body))
                .foregroundColor(.primary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func remarkSection(_ remark: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "备注", icon: "note.text", color: .secondary)
            Text(remark)
                .font(.system(.body))
                .foregroundColor(.primary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 通用行
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.body))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func infoRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(.body))
                .foregroundColor(.secondary)
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
            Text(title)
                .font(.system(.footnote, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    private var copiedToast: some View {
        VStack {
            Label("卡号已复制", systemImage: "checkmark.circle.fill")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.72), in: Capsule())
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
            Spacer()
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Helpers
    private var cleanCardNumber: String {
        card.cardNumber.filter { $0.isNumber }
    }

    private var maskedCardNumber: String {
        "•••• •••• •••• \(String(cleanCardNumber.suffix(4)))"
    }

    private var formattedFullNumber: String {
        var result = ""
        for (index, char) in cleanCardNumber.enumerated() {
            if index > 0 && index % 4 == 0 { result += " " }
            result.append(char)
        }
        return result
    }

    private func copyCardNumber() {
        guard !cleanCardNumber.isEmpty else { return }

        UIPasteboard.general.string = cleanCardNumber
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        let token = UUID()
        copiedToastToken = token
        withAnimation(.spring(duration: 0.25, bounce: 0.2)) {
            showCopiedToast = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard copiedToastToken == token else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedToast = false
            }
        }
    }

    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let normalizedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCurrency.isEmpty else {
            return "\(Int(amount).formatted())"
        }
        let symbol: String
        switch normalizedCurrency {
        case "CNY", "CNH": symbol = "¥"
        case "USD": symbol = "$"
        case "HKD": symbol = "HK$"
        case "EUR": symbol = "€"
        case "JPY": symbol = "JP¥"
        case "GBP": symbol = "£"
        default: symbol = normalizedCurrency + " "
        }
        return "\(symbol)\(Int(amount).formatted())"
    }

    private func displayCurrency(_ currency: String?) -> String {
        let value = (currency ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return value.isEmpty ? "未设置" : value
    }

    private func toggleNumber() {
        countdownTimer?.invalidate()
        isShowingNumber.toggle()
        if isShowingNumber {
            remainingShowSeconds = 5.0
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    remainingShowSeconds -= 0.1
                    if remainingShowSeconds <= 0 {
                        countdownTimer?.invalidate()
                        withAnimation { isShowingNumber = false }
                    }
                }
            }
        }
    }

    // MARK: - 媒体文件预览
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "卡片图片", icon: "photo.on.rectangle.angled", color: .blue)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(card.cardImages) { asset in
                        if let uiImage = uiImage(from: asset) {
                            Button {
                                selectedPreviewImage = asset
                            } label: {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
    }

    private func uiImage(from asset: CardImageAsset) -> UIImage? {
        let base64 = asset.data.components(separatedBy: "base64,").last ?? asset.data
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

struct ImagePreviewView: View {
    let asset: CardImageAsset
    @Environment(\.dismiss) private var dismiss

    private var uiImage: UIImage? {
        let base64 = asset.data.components(separatedBy: "base64,").last ?? asset.data
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let uiImage = uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    Text("无法加载图片")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle(asset.name.isEmpty ? "图片预览" : asset.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
