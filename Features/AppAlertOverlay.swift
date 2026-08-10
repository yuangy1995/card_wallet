import SwiftUI

enum AppAlertType: Identifiable, Equatable {
    var id: String {
        switch self {
        case .unifiedReminders: return "unifiedReminders"
        case .deleteCard(let card): return "deleteCard-\(card.id)"
        }
    }
    
    case unifiedReminders(
        billingReminders: [(card: SharedCard, reminder: DateCalculator.BillingCycleReminderResult)],
        annualFeeReminders: [SharedCard],
        expiryReminders: [(card: SharedCard, status: DateCalculator.CardExpiryStatus)]
    )
    case deleteCard(card: SharedCard)
    
    static func == (lhs: AppAlertType, rhs: AppAlertType) -> Bool {
        return lhs.id == rhs.id
    }
}

struct CustomAlertOverlay: View {
    let activeAlert: AppAlertType
    let onDismiss: () -> Void
    let onAction: (AppAlertType) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部 Header
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(gradientForAlert(activeAlert))
                        .frame(width: 44, height: 44)
                        .shadow(color: colorForAlert(activeAlert).opacity(0.25), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: iconNameForAlert(activeAlert))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(titleForAlert(activeAlert))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(subtitleForAlert(activeAlert))
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // 中间列表
            ScrollView {
                VStack(spacing: 12) {
                    switch activeAlert {
                    case .unifiedReminders(let billingReminders, let annualFeeReminders, let expiryReminders):
                        // 1. 还款日提醒
                        let repaymentReminders = billingReminders.filter { $0.reminder.kind == .repayment }
                        if !repaymentReminders.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.octagon.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("还款日提醒")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(SoftColors.red)
                                .padding(.leading, 4)
                                
                                ForEach(repaymentReminders.indices, id: \.self) { index in
                                    let item = repaymentReminders[index]
                                    HStack(spacing: 8) {
                                        BankAvatar(bankName: item.card.bank)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.card.bank)
                                                .font(.system(size: 12, weight: .semibold))
                                            Text(item.card.alias ?? "无别名")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        let days = item.reminder.days
                                        let dateStr = DateCalculator.formatDate(item.reminder.date)
                                        Text(days == 0 ? "今天还款 (\(dateStr))" : "\(days)天后还款 (\(dateStr))")
                                            .font(.system(size: 10.5, design: .rounded))
                                            .foregroundColor(SoftColors.red)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(SoftColors.red.opacity(0.09))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(SoftColors.red.opacity(0.24), lineWidth: 1))
                                }
                            }
                        }
                        
                        // 2. 账单日提醒
                        let billReminders = billingReminders.filter { $0.reminder.kind == .bill }
                        if !billReminders.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("账单日提醒")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(SoftColors.blue)
                                .padding(.leading, 4)
                                
                                ForEach(billReminders.indices, id: \.self) { index in
                                    let item = billReminders[index]
                                    HStack(spacing: 8) {
                                        BankAvatar(bankName: item.card.bank)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.card.bank)
                                                .font(.system(size: 12, weight: .semibold))
                                            Text(item.card.alias ?? "无别名")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        let days = item.reminder.days
                                        let dateStr = DateCalculator.formatDate(item.reminder.date)
                                        Text(days == 0 ? "今天出账 (\(dateStr))" : "\(days)天后出账 (\(dateStr))")
                                            .font(.system(size: 10.5, design: .rounded))
                                            .foregroundColor(SoftColors.blue)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(SoftColors.blue.opacity(0.09))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(SoftColors.blue.opacity(0.24), lineWidth: 1))
                                }
                            }
                        }
                        
                        // 3. 年费达标提醒
                        if !annualFeeReminders.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("年费达标提醒")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(SoftColors.orange)
                                .padding(.leading, 4)
                                
                                ForEach(annualFeeReminders.indices, id: \.self) { index in
                                    let card = annualFeeReminders[index]
                                    HStack(spacing: 8) {
                                        BankAvatar(bankName: card.bank)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(card.bank)
                                                .font(.system(size: 12, weight: .semibold))
                                            Text(card.alias ?? "无别名")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        let dateText = DateCalculator.formatTimestampDate(card.nextAnnualFeeCollectionTime)
                                        let days = DateCalculator.annualFeeRemainingDays(card.nextAnnualFeeCollectionTime) ?? 0
                                        Text("剩 \(days) 天 (\(dateText))")
                                            .font(.system(size: 10.5, design: .rounded))
                                            .foregroundColor(SoftColors.orange)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(SoftColors.orange.opacity(0.09))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(SoftColors.orange.opacity(0.24), lineWidth: 1))
                                }
                            }
                        }
                        
                        // 4. 卡片有效期提醒
                        if !expiryReminders.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("卡片有效期提醒")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(SoftColors.purple)
                                .padding(.leading, 4)
                                
                                ForEach(expiryReminders.indices, id: \.self) { index in
                                    let item = expiryReminders[index]
                                    let isExpired = item.status == .expired
                                    HStack(spacing: 8) {
                                        BankAvatar(bankName: item.card.bank)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.card.bank)
                                                .font(.system(size: 12, weight: .semibold))
                                            Text(item.card.alias ?? "无别名")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        let statusText = isExpired ? "已过期" : "即将到期"
                                        Text("\(statusText) (\(item.card.valid ?? "--/--"))")
                                            .font(.system(size: 10.5, weight: .semibold))
                                            .foregroundColor(SoftColors.purple)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(SoftColors.purple.opacity(0.09))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(SoftColors.purple.opacity(0.24), lineWidth: 1))
                                }
                            }
                        }
                        
                    case .deleteCard(let card):
                        VStack(spacing: 16) {
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(
                                        colors: [
                                            BankVisualStyle.color(for: card.bank),
                                            BankVisualStyle.color(for: card.bank).opacity(0.8)
                                        ],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                                    .frame(height: 120)
                                    .shadow(color: BankVisualStyle.color(for: card.bank).opacity(0.35), radius: 10, x: 0, y: 5)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(card.bank)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(card.cardCategory == "debit" ? "储蓄卡" : "信用卡")
                                            .font(.system(size: 10, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2.5)
                                            .background(.white.opacity(0.2))
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(card.alias ?? "未命名卡片")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Spacer()
                                    
                                    Text("••••  ••••  ••••  \(card.cardNumber.suffix(4))")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(16)
                            }
                            .frame(width: 280)
                            .padding(.vertical, 8)
                            
                            Text("删除此卡片后数据无法恢复，与之相关的全部提醒也将一并删除。")
                                .font(.system(size: 11.5))
                                .foregroundColor(.red.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: 280)
            
            Divider()
                .background(Color.primary.opacity(0.1))
                .padding(.top, 16)
            
            // 底部按钮
            HStack(spacing: 12) {
                if showCancelButton(activeAlert) {
                    Button(action: {
                        onDismiss()
                    }) {
                        Text(cancelButtonTitle(activeAlert))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    onAction(activeAlert)
                }) {
                    Text(actionButtonTitle(activeAlert))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: actionButtonColors(activeAlert),
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: actionButtonColors(activeAlert)[0].opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 25, x: 0, y: 12)
    }
    
    // MARK: - 辅助方法
    
    private func gradientForAlert(_ alert: AppAlertType) -> LinearGradient {
        switch alert {
        case .unifiedReminders:
            return LinearGradient(colors: [SoftColors.orange, SoftColors.red], startPoint: .top, endPoint: .bottom)
        case .deleteCard:
            return LinearGradient(colors: [SoftColors.red, Color(red: 0.75, green: 0.3, blue: 0.3)], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private func colorForAlert(_ alert: AppAlertType) -> Color {
        switch alert {
        case .unifiedReminders: return SoftColors.orange
        case .deleteCard: return SoftColors.red
        }
    }
    
    private func iconNameForAlert(_ alert: AppAlertType) -> String {
        switch alert {
        case .unifiedReminders: return "bell.badge.fill"
        case .deleteCard: return "trash.fill"
        }
    }
    
    private func titleForAlert(_ alert: AppAlertType) -> String {
        switch alert {
        case .unifiedReminders: return "卡片提醒"
        case .deleteCard: return "确认要删除此卡片吗？"
        }
    }
    
    private func subtitleForAlert(_ alert: AppAlertType) -> String {
        switch alert {
        case .unifiedReminders: return "检测到以下卡片有需要处理的事项，请及时关注。"
        case .deleteCard: return "删除卡片后将不可恢复，与之相关的全部提醒也均会被清空。"
        }
    }
    
    private func showCancelButton(_ alert: AppAlertType) -> Bool {
        return true
    }
    
    private func cancelButtonTitle(_ alert: AppAlertType) -> String {
        switch alert {
        case .unifiedReminders: return "知道了"
        case .deleteCard: return "取消"
        }
    }
    
    private func actionButtonTitle(_ alert: AppAlertType) -> String {
        switch alert {
        case .unifiedReminders: return "查看卡片提醒"
        case .deleteCard: return "确认删除"
        }
    }
    
    private func actionButtonColors(_ alert: AppAlertType) -> [Color] {
        switch alert {
        case .unifiedReminders: return [SoftColors.blue, SoftColors.cyan]
        case .deleteCard: return [SoftColors.red, Color(red: 0.75, green: 0.3, blue: 0.3)]
        }
    }
}
