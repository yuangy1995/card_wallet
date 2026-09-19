import SwiftUI

struct BestUsageView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @State private var cardToEdit: SharedCard? = nil

    private var today: Date { Date() }

    private var creditCards: [SharedCard] {
        syncCoordinator.cards.filter { $0.cardCategory != "debit" }
    }

    // 已配置账单信息的卡片，并按免息期降序排序
    private var validCards: [(card: SharedCard, days: Int)] {
        creditCards.map { card in
            (card: card, days: DateCalculator.calculateInterestFreeDays(card: card, today: today))
        }
        .filter { $0.days != -1 }
        .sorted { $0.days > $1.days }
    }

    // 未配置账单信息的卡片
    private var invalidCards: [SharedCard] {
        creditCards.filter { card in
            DateCalculator.calculateInterestFreeDays(card: card, today: today) == -1
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if creditCards.isEmpty {
                    emptyCardsStateView
                        .padding(.top, 12)
                } else if validCards.isEmpty && !invalidCards.isEmpty {
                    noConfiguredCardsStateView
                        .padding(.top, 12)
                } else {
                    ForEach(Array(validCards.enumerated()), id: \.element.card.id) { index, pair in
                        BestUsageCardTile(
                            card: pair.card,
                            days: pair.days,
                            rank: index + 1,
                            onTap: {
                                cardToEdit = pair.card
                            }
                        )
                    }
                }

                // 待配置卡片折叠区域
                if !invalidCards.isEmpty {
                    invalidCardsCollapseSection
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("优惠用卡")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $cardToEdit) { card in
            CardEditView(
                mode: "edit",
                cardToEdit: card,
                initialCardCategory: card.cardCategory,
                existingCards: syncCoordinator.cards
            ) { updatedCard in
                try await commitSubmittedCard(updatedCard, previousCard: card)
            }
        }
    }

    // MARK: - 空状态视图
    private var emptyCardsStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("暂无可用于免息期计算的信用卡")
                .font(.system(.headline, weight: .bold))
                .foregroundColor(.primary)
            Text("请先在首页卡包中添加信用卡，储蓄卡不会参与免息期计算。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var noConfiguredCardsStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("未检测到已配置的信用卡账单")
                .font(.system(.headline, weight: .bold))
                .foregroundColor(.primary)
            Text("请先在下方“待配置账单信息的卡片”中配置“账单日”和“还款日”。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 待配置卡片折叠区域
    private var invalidCardsCollapseSection: some View {
        DisclosureGroup {
            VStack(spacing: 8) {
                ForEach(invalidCards, id: \.id) { card in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.bank.isEmpty ? "信用银行" : card.bank)
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundColor(.primary)
                            if let alias = card.alias, !alias.isEmpty {
                                Text(alias)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            cardToEdit = card
                        } label: {
                            Text("去配置")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.vertical, 6)
                    if card.id != invalidCards.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text("待配置账单信息的卡片 (\(invalidCards.count)张)")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 数据保存提交
    private func commitSubmittedCard(_ submittedCard: SharedCard, previousCard: SharedCard?) async throws {
        _ = try await syncCoordinator.mutateCards { latest in
        var allCards = latest
        var finalCard = submittedCard
        let now = DataMigrationManager.currentTimestampMilliseconds()
        finalCard.lastModifyTime = now

        if let index = allCards.firstIndex(where: { $0.id == finalCard.id }) {
            allCards[index] = finalCard
        } else {
            allCards.append(finalCard)
        }



        if finalCard.cardCategory != "debit",
           finalCard.isSharedLimit,
           !finalCard.bank.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !finalCard.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let finalType = (finalCard.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            for index in allCards.indices where allCards[index].id != finalCard.id {
                let itemType = (allCards[index].type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard allCards[index].cardCategory != "debit",
                      allCards[index].isSharedLimit,
                      allCards[index].country == finalCard.country,
                      itemType == finalType,
                      BankNameNormalizer.namesReferToSameBank(allCards[index].bank, finalCard.bank) else {
                    continue
                }
                allCards[index].limit = finalCard.limit
                allCards[index].type = finalCard.type
                allCards[index].lastTime = finalCard.lastTime
                allCards[index].lastModifyTime = now
            }
        }

        return allCards
        }
    }
}

// MARK: - 优惠用卡单卡片组件
private struct BestUsageCardTile: View {
    let card: SharedCard
    let days: Int
    let rank: Int
    let onTap: () -> Void

    private var brand: CardBrand {
        CardBrand.detect(from: card.cardNumber, level: card.level)
    }

    private var brandGradient: [Color] {
        switch brand {
        case .visa:
            return [Color(hex: "#1A1F71"), Color(hex: "#2B3DA0"), Color(hex: "#0D1156")]
        case .mastercard:
            return [Color(hex: "#1A1A2E"), Color(hex: "#16213E"), Color(hex: "#0F3460")]
        case .amex:
            return [Color(hex: "#00416A"), Color(hex: "#007BC1"), Color(hex: "#003554")]
        case .unionpay:
            return [Color(hex: "#8B0000"), Color(hex: "#CC0000"), Color(hex: "#5C0000")]
        case .discover:
            return [Color(hex: "#8B3A00"), Color(hex: "#CC5500"), Color(hex: "#5C2400")]
        case .dinersClub:
            return [Color(hex: "#1A1A1A"), Color(hex: "#2D2D2D"), Color(hex: "#0D0D0D")]
        case .jcb:
            return [Color(hex: "#002266"), Color(hex: "#003399"), Color(hex: "#001A4D")]
        case .unknown:
            return [Color(hex: "#1C1C3A"), Color(hex: "#2A2A4A"), Color(hex: "#0E0E25")]
        }
    }

    private var badgeColor: Color {
        switch rank {
        case 1: return Color(hex: "#B8860B")
        case 2: return Color(hex: "#002266")
        case 3: return Color(hex: "#228B22")
        default: return .secondary
        }
    }

    private var badgeText: String {
        switch rank {
        case 1: return "🥇 今日首选"
        case 2: return "🥈 备选方案"
        case 3: return "🥉 推荐刷卡"
        default: return "第 \(rank) 名"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // 顶部名次与天数
            HStack {
                Text(badgeText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(badgeColor.opacity(0.35), lineWidth: 1))

                Spacer()

                HStack(alignment: .bottom, spacing: 2) {
                    Text("免息期")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                    Text("\(days)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(badgeColor)
                    Text("天")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                }
            }

            // 中间微缩卡片背景
            HStack {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.bank.isEmpty ? "信用银行" : card.bank)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        if let alias = card.alias, !alias.isEmpty {
                            Text(alias)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    Text(formatSpacingCardNumber(card.cardNumber))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(0.8)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    CardBrandIcon(brand: brand, size: 24, isForCardFace: true)
                    Spacer()
                    EMVChip()
                }
            }
            .padding(12)
            .frame(height: 84)
            .background(LinearGradient(colors: brandGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(12)

            // 下方参数行
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("账单日")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("每月 \(card.accountBillDate ?? "--") 号")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .center, spacing: 3) {
                    Text("还款日")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("每月 \(card.dueDate ?? "--") 号")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("入账规则")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(card.billingDaySpendingToNextBill ? "账单日消费计入下期" : "账单日消费计入本期")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(badgeColor)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(8)
            .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))

            // 首选卡黄金提示
            if rank == 1 {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(badgeColor)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("💡 用卡黄金提示")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(badgeColor)
                        Text("今日刷卡处于最拉长周转账单期！本次消费款项将享受长达 \(days) 天的免息缓冲。建议优先在此卡额度内大额支出，最大化周转您的闲置资金。")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(badgeColor.opacity(0.08))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(badgeColor.opacity(0.2), lineWidth: 0.5))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.015), radius: 6, x: 0, y: 3)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private func formatSpacingCardNumber(_ rawNum: String) -> String {
        let clean = rawNum.replacingOccurrences(of: " ", with: "")
        if clean.count >= 4 {
            let last4 = String(clean.suffix(4))
            return "••••  ••••  ••••  \(last4)"
        }
        var result = ""
        for (index, char) in clean.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += "  "
            }
            result.append(char)
        }
        return result
    }
}

private struct EMVChip: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FFD700").opacity(0.9), Color(hex: "#B8860B").opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 18)
            VStack(spacing: 2) {
                ForEach(0..<3) { _ in
                    Rectangle()
                        .fill(Color(hex: "#B8860B").opacity(0.6))
                        .frame(width: 14, height: 0.6)
                }
            }
        }
    }
}
