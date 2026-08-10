import SwiftUI

struct CardReminderView: View {
    let cards: [SharedCard]
    @Binding var detailCard: SharedCard?
    @Binding var cardsBinding: [SharedCard] // 因为年费设为达标/未达标需要回写 cards
    let syncCoordinator: SyncCoordinator
    
    // 提醒数据局部惰性计算属性
    private var billingReminders: [(card: SharedCard, reminder: DateCalculator.BillingCycleReminderResult)] {
        DateCalculator.billingCycleReminderItems(for: cards)
    }
    
    private var repaymentReminders: [(card: SharedCard, reminder: DateCalculator.BillingCycleReminderResult)] {
        billingReminders.filter { $0.reminder.kind == .repayment }
    }
    
    private var billReminders: [(card: SharedCard, reminder: DateCalculator.BillingCycleReminderResult)] {
        billingReminders.filter { $0.reminder.kind == .bill }
    }
    
    private var annualFeeReminders: [SharedCard] {
        cards.filter { card in
            guard card.cardCategory != "debit",
                  card.isQualified != "3",
                  let diffDays = DateCalculator.annualFeeRemainingDays(card.nextAnnualFeeCollectionTime) else {
                return false
            }
            return diffDays <= 60 && diffDays >= 0
        }
    }
    
    private var expiryReminders: [(card: SharedCard, status: DateCalculator.CardExpiryStatus)] {
        cards.compactMap { card -> (card: SharedCard, status: DateCalculator.CardExpiryStatus)? in
            guard let status = cardExpiryReminderStatus(for: card) else { return nil }
            return (card, status)
        }.sorted { lhs, rhs in
            let lhsPriority = lhs.status == .expired ? 0 : 1
            let rhsPriority = rhs.status == .expired ? 0 : 1
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return lhs.card.bank < rhs.card.bank
        }
    }
    
    private var hasAnyReminder: Bool {
        !repaymentReminders.isEmpty || !billReminders.isEmpty || !annualFeeReminders.isEmpty || !expiryReminders.isEmpty
    }

    private var reminderCount: Int {
        repaymentReminders.count + billReminders.count + annualFeeReminders.count + expiryReminders.count
    }
    
    private func cardExpiryReminderStatus(for card: SharedCard) -> DateCalculator.CardExpiryStatus? {
        guard let status = DateCalculator.cardExpiryStatus(valid: card.valid),
              status == .expired || status == .soonExpiring else {
            return nil
        }
        return status
    }

    // 确认当前年费周期达标，并以卡片中保存的年费日期为基准顺延一年。
    private func confirmAnnualFeeQualified(cardIDs: Set<String>) {
        let nowTimestamp = DateCalculator.timestamp(from: Date())
        for index in cardsBinding.indices where cardIDs.contains(cardsBinding[index].id) {
            cardsBinding[index].isQualified = "1"
            cardsBinding[index].nextAnnualFeeCollectionTime = DateCalculator.timestampByAddingOneYear(
                cardsBinding[index].nextAnnualFeeCollectionTime
            )
            cardsBinding[index].lastModifyTime = nowTimestamp
        }
        cardsBinding = syncCoordinator.commit(cards: cardsBinding)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                iconName: "bell.badge.fill",
                iconColor: SoftColors.orange,
                title: "卡片提醒",
                subtitle: "集中查看账单、还款、年费和有效期提醒"
            ) {
                if hasAnyReminder {
                    AppStatusPill(
                        text: "\(reminderCount) 项提醒",
                        color: SoftColors.orange,
                        systemImage: "bell.badge.fill"
                    )
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            if !hasAnyReminder {
                VStack {
                    AppEmptyState(
                        iconName: "checkmark.shield.fill",
                        title: "省心！目前没有需要关注的卡片提醒",
                        message: "账单还款、年费达标以及卡片有效期都处于安全状态。",
                        accentColor: SoftColors.green
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.01))
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. 还款提醒板块 (Repayment)
                        if !repaymentReminders.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.octagon.fill")
                                        .foregroundColor(SoftColors.red)
                                    Text("还款日提醒")
                                        .font(.headline)
                                        .foregroundColor(SoftColors.red)
                                }
                                .padding(.horizontal, 4)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)], spacing: 16) {
                                    ForEach(repaymentReminders.indices, id: \.self) { index in
                                        let item = repaymentReminders[index]
                                        let days = item.reminder.days
                                        ReminderDashboardItem(
                                            card: item.card,
                                            title: "即将到达还款日",
                                            detail: "还款日：\(DateCalculator.formatDate(item.reminder.date))，请核对本期账单是否已还款",
                                            tag: "剩 \(days) 天",
                                            themeColor: SoftColors.red,
                                            actionLabel: "查看详情",
                                            onAction: { detailCard = item.card }
                                        )
                                    }
                                }
                            }
                            .padding(16)
                            .appPanel(cornerRadius: 18, tint: SoftColors.red)
                        }
                        
                        // 2. 账单提醒板块 (Billing)
                        if !billReminders.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(SoftColors.blue)
                                    Text("账单日提醒")
                                        .font(.headline)
                                        .foregroundColor(SoftColors.blue)
                                }
                                .padding(.horizontal, 4)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)], spacing: 16) {
                                    ForEach(billReminders.indices, id: \.self) { index in
                                        let item = billReminders[index]
                                        let days = item.reminder.days
                                        ReminderDashboardItem(
                                            card: item.card,
                                            title: "账单日到了",
                                            detail: "账单日：\(DateCalculator.formatDate(item.reminder.date))，请关注本期出账",
                                            tag: days == 0 ? "今天" : "剩 \(days) 天",
                                            themeColor: SoftColors.blue,
                                            actionLabel: "查看详情",
                                            onAction: { detailCard = item.card }
                                        )
                                    }
                                }
                            }
                            .padding(16)
                            .appPanel(cornerRadius: 18, tint: SoftColors.blue)
                        }
                        
                        // 3. 年费警示板块 (Annual Fee)
                        if !annualFeeReminders.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: "dollarsign.circle.fill")
                                            .foregroundColor(SoftColors.orange)
                                        Text("年费达标警示")
                                            .font(.headline)
                                            .foregroundColor(SoftColors.orange)
                                    }
                                    Spacer()
                                    // 批量确认当前周期达标，统一顺延下一次年费日期。
                                    Button(action: {
                                        confirmAnnualFeeQualified(cardIDs: Set(annualFeeReminders.map(\.id)))
                                    }) {
                                        Text("全部确认本周期已达标")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(SoftColors.orange)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(SoftColors.orange.opacity(0.12))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 4)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)], spacing: 16) {
                                    ForEach(annualFeeReminders.indices, id: \.self) { index in
                                        let card = annualFeeReminders[index]
                                        let dateText = DateCalculator.formatTimestampDate(card.nextAnnualFeeCollectionTime)
                                        let days = DateCalculator.annualFeeRemainingDays(card.nextAnnualFeeCollectionTime) ?? 0
                                        ReminderDashboardItem(
                                            card: card,
                                            title: card.isQualified == "2" ? "本周期尚未达标" : "新周期达标确认",
                                            detail: "收取日：\(dateText)，距离产生年费仅剩 \(days) 天。请确认本周期是否已经达标。",
                                            tag: "剩 \(days) 天",
                                            themeColor: SoftColors.orange,
                                            actionLabel: "确认本周期已达标",
                                            onAction: {
                                                confirmAnnualFeeQualified(cardIDs: [card.id])
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(16)
                            .appPanel(cornerRadius: 18, tint: SoftColors.orange)
                        }
                        
                        // 4. 有效期预警板块 (Expiry)
                        if !expiryReminders.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .foregroundColor(SoftColors.purple)
                                    Text("有效期临界/过期")
                                        .font(.headline)
                                        .foregroundColor(SoftColors.purple)
                                }
                                .padding(.horizontal, 4)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)], spacing: 16) {
                                    ForEach(expiryReminders.indices, id: \.self) { index in
                                        let item = expiryReminders[index]
                                        let isExpired = item.status == .expired
                                        ReminderDashboardItem(
                                            card: item.card,
                                            title: isExpired ? "卡片已过期" : "卡片即将到期",
                                            detail: "有效期：\(item.card.valid ?? "--/--")。\(isExpired ? "卡片已失效，请更新卡片信息。" : "请留意银行是否已安排寄送新卡并及时更新。")",
                                            tag: isExpired ? "已失效" : "将到期",
                                            themeColor: SoftColors.purple,
                                            actionLabel: "更新有效期",
                                            onAction: { detailCard = item.card }
                                        )
                                    }
                                }
                            }
                            .padding(16)
                            .appPanel(cornerRadius: 18, tint: SoftColors.purple)
                        }
                    }
                    .padding(24)
                }
                .background(Color.primary.opacity(0.005))
            }
        }
    }
}
