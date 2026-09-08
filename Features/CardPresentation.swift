import SwiftUI
import AppKit
import ImageIO

struct WalletAnnualBadge: View {
    let card: SharedCard
    @Environment(\.walletPalette) private var palette
    private var label: LocalizedStringKey {
        if card.cardCategory == "debit" { return "储蓄卡" }
        switch card.isQualified {
        case "1": return "已达标"
        case "2": return "待确认"
        case "3": return "终免年费"
        default: return "未填写"
        }
    }
    private var color: Color {
        card.cardCategory == "debit" ? .secondary : card.isQualified == "2" ? palette.warning : palette.accent
    }
    var body: some View {
        HStack(spacing: 4) {
            if card.cardCategory != "debit" {
                Image(systemName: card.isQualified == "3" ? "infinity" : card.isQualified == "1" ? "checkmark" : "clock")
                    .accessibilityHidden(true)
            }
            Text(label)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(color).padding(.horizontal, 6).padding(.vertical, 4)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        .fixedSize()
    }
}

struct WalletCardFace: View {
    let card: SharedCard
    @Environment(\.walletPalette) private var palette
    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: palette.cardGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.16), lineWidth: 1).frame(width: 220, height: 220).offset(x: 93, y: -105)
                        Circle().stroke(.white.opacity(0.12), lineWidth: 1).frame(width: 220, height: 220).offset(x: 65, y: -128)
                    }
                    .allowsHitTesting(false).accessibilityHidden(true)
                }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(card.bank).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "wave.3.right").font(.system(size: 13))
                }
                Text(card.level?.isEmpty == false ? card.level! : (card.cardCategory == "debit" ? String(localized: "储蓄卡") : String(localized: "信用卡")))
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 10)
                Text("••••   ••••   \(String(card.cardNumber.suffix(4)))")
                    .font(.system(size: 14, weight: .medium, design: .monospaced)).tracking(1)
                Spacer(minLength: 6)
                HStack {
                    Text(card.valid ?? "—").font(.system(size: 10, design: .monospaced))
                    Spacer()
                    Text(brandName).font(.system(size: 11, weight: .medium)).tracking(0.8)
                }
            }
            .padding(17)
            .foregroundStyle(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.28), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(card.bank)，尾号 \(String(card.cardNumber.suffix(4)))"))
    }
    private var brandName: String {
        switch CardBrand.detect(from: card.cardNumber, level: card.level) {
        case .visa: return "VISA"
        case .mastercard: return "Mastercard"
        case .amex: return "AMEX"
        case .unionpay: return "UnionPay"
        case .discover: return "Discover"
        case .dinersClub: return "Diners Club"
        case .jcb: return "JCB"
        case .unknown: return ""
        }
    }
}

struct CardDetailView: View {
    let card: SharedCard
    var onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletIsLocked) private var isLocked
    @Environment(\.walletSheetSize) private var sheetSize
    private var isCredit: Bool { card.cardCategory != "debit" }

    var body: some View {
        Group {
            if isLocked {
                LockScreenView()
            } else {
                VStack(spacing: 0) {
                    WalletSheetHeader(title: "卡片详情", subtitle: card.bank + " · " + String(card.cardNumber.suffix(4)), icon: "creditcard") {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).help("关闭").accessibilityLabel("关闭").keyboardShortcut(.cancelAction)
                    }
                    HStack(alignment: .top, spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                WalletCardFace(card: card).frame(height: 149)
                                CardAttachmentStrip(images: card.cardImages, nested: true)
                                Text(card.alias?.isEmpty == false ? card.alias! : card.bank)
                                    .font(.system(size: 20, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                                WalletAnnualBadge(card: card)
                                Text([card.country, card.type ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                                Divider()
                                WalletSensitiveValue(title: "卡号", value: card.cardNumber, masked: "•••• " + String(card.cardNumber.suffix(4)))
                                if let cvv = card.cvv, !cvv.isEmpty {
                                    WalletSensitiveValue(title: "安全码", value: cvv, masked: "•••")
                                }
                                WalletFieldValue(title: "有效期", value: value(card.valid))
                                WalletFieldValue(title: "卡片等级", value: value(card.level))
                            }
                            .padding(20)
                        }
                        .frame(width: 280)
                        .background(palette.surface.opacity(0.3))
                        palette.line.frame(width: 1)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if isCredit {
                                    WalletFormSection(title: "额度与年费", icon: "yensign.circle") {
                                        HStack {
                                            WalletFieldValue(title: "信用额度", value: WalletFormat.amount(card.limit, currency: card.type))
                                            WalletFieldValue(title: "额度类型", value: card.isSharedLimit ? String(localized: "同行共享") : String(localized: "独立额度"))
                                        }
                                        if card.isQualified != "3" { HStack {
                                            WalletFieldValue(title: "年费", value: WalletFormat.amount(card.annualFee, currency: card.type))
                                            WalletFieldValue(title: "下次年费日期", value: WalletFormat.date(card.nextAnnualFeeCollectionTime))
                                        } }
                                        WalletFieldValue(title: "上次提额日期", value: WalletFormat.date(card.lastTime))
                                    }
                                    WalletFormSection(title: "账单与还款", icon: "calendar") {
                                        HStack {
                                            WalletFieldValue(title: "账单日", value: WalletFormat.day(card.accountBillDate))
                                            WalletFieldValue(title: "还款日", value: WalletFormat.day(card.dueDate))
                                        }
                                        HStack {
                                            WalletFieldValue(title: "账单日当天消费", value: card.billingDaySpendingToNextBill ? String(localized: "计入下一期") : String(localized: "计入当期"))
                                            WalletFieldValue(title: "最长免息期", value: interestFreeText)
                                        }
                                    }
                                }
                                WalletFormSection(title: "权益与备注", icon: "text.alignleft") {
                                    WalletFieldValue(title: "权益", value: value(card.equity))
                                    WalletFieldValue(title: "备注", value: value(card.remark))
                                }
                                Text("最后修改：\(DateCalculator.formatTimestampDateTime(card.lastModifyTime))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(20)
                        }
                    }
                    HStack {
                        Text(isCredit ? "信用卡" : "储蓄卡").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("关闭") { dismiss() }
                        Button(action: onEdit) { Label("编辑卡片", systemImage: "pencil") }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 22).padding(.vertical, 16)
                    .background(palette.surface.opacity(0.4))
                    .overlay(alignment: .top) { palette.line.frame(height: 1) }
                }
            }
        }
        .modifier(WalletThemeModifier())
        .frame(width: sheetSize.width, height: sheetSize.height)
    }

    private func value(_ value: String?) -> String { value?.isEmpty == false ? value! : String(localized: "未填写") }
    private var interestFreeText: String {
        guard let days = CardCatalogItem(card: card).interestFreeDays else { return String(localized: "请先填写账单日和还款日") }
        return String(localized: "\(days) 天")
    }
}

struct WalletSensitiveValue: View {
    let title: LocalizedStringKey
    let value: String
    let masked: String
    @State private var visible = false
    @State private var copied = false
    var body: some View {
        HStack {
            WalletFieldValue(title: title, value: visible ? value : masked)
            Button { visible.toggle() } label: { Image(systemName: visible ? "eye.slash" : "eye") }
                .buttonStyle(.borderless).help(visible ? "隐藏信息" : "显示五秒").accessibilityLabel(visible ? "隐藏信息" : "显示五秒")
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                copied = true
            } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
            .buttonStyle(.borderless).help("复制").accessibilityLabel("复制")
        }
        .task(id: visible) {
            guard visible else { return }
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            visible = false
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}

@MainActor
final class CardImageCache {
    static let shared = CardImageCache()
    private let cache = NSCache<NSString, NSImage>()
    private init() { cache.totalCostLimit = 32 * 1024 * 1024; cache.countLimit = 60 }
    func image(for asset: CardImageAsset, pixels: Int) async -> NSImage? {
        let key = "\(asset.id)-\(asset.createdAt)-\(asset.data.utf8.count)-\(pixels)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let encoded = asset.data
        let cgImage = await Task.detached(priority: .utility) {
            let payload = encoded.range(of: "base64,").map { String(encoded[$0.upperBound...]) } ?? encoded
            guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters),
                  let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil as CGImage? }
            return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: pixels,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary)
        }.value
        guard !Task.isCancelled else { return nil }
        guard let cgImage else {
            let payload = encoded.range(of: "base64,").map { String(encoded[$0.upperBound...]) } ?? encoded
            guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters), let fallback = NSImage(data: data) else { return nil }
            cache.setObject(fallback, forKey: key, cost: max(data.count, Int(fallback.size.width * fallback.size.height * 4)))
            return fallback
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}

struct CardImageView: View {
    let asset: CardImageAsset
    var pixels: Int = 480
    @State private var image: NSImage?
    @State private var finished = false
    var body: some View {
        ZStack {
            Color.secondary.opacity(0.06)
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else if finished {
                Label("无法预览图片", systemImage: "photo").font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityLabel(finished && image == nil ? String(localized: "无法预览图片") : (asset.name.isEmpty ? String(localized: "卡片图片") : asset.name))
        .task(id: "\(asset.id)-\(asset.createdAt)-\(pixels)") {
            image = nil
            finished = false
            image = await CardImageCache.shared.image(for: asset, pixels: pixels)
            finished = true
        }
    }

    static func byteCount(_ asset: CardImageAsset) -> Int64 {
        let value = asset.data.range(of: "base64,").map { asset.data[$0.upperBound...] } ?? asset.data[...]
        let padding = value.suffix(2).filter { $0 == "=" }.count
        return Int64(max(0, value.utf8.count * 3 / 4 - padding))
    }
}
