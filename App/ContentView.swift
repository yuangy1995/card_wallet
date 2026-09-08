import SwiftUI
import UserNotifications

struct CardEditRequest: Identifiable {
    let id = UUID()
    let mode: String
    let card: SharedCard?
    let cardCategory: String
    
    init(mode: String, card: SharedCard?, cardCategory: String = "credit") {
        self.mode = mode
        self.card = card
        self.cardCategory = cardCategory == "debit" ? "debit" : "credit"
    }
}

struct BatchUpdateRequest {
    var status: String?
    var annualFee: Double?
    var nextAnnualFeeDate: Double?
    var valid: String?
    var cardCategory: String?
}


struct ContentView: View {
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletAnimation) private var walletAnimation
    @State private var cards: [SharedCard] = []
    @State private var hasLoadedCards = false
    @State private var loadingFailed = false
    @StateObject private var syncCoordinator = SyncCoordinator.shared
    @State private var selection: NavigationSection? = .allCards
    @State private var searchText = ""
    
    // 💡 分组和排序状态管理
    @State private var groupBy: GroupOption = .none
    @State private var sortBy: SortOption = .limitDesc
    @State private var cardCategoryFilter: CardCategoryFilter = .all
    @State private var showingFilterPopover = false
    @State private var selectedBank = ""
    @State private var searchFocusRequest = 0
    @State private var settingsSection: WalletSettingsSection = .appearance
    @State private var selectedCardID: String?
    @State private var usageDate = Date()
    
    // 编辑弹窗请求，创建弹窗时一并携带模式和目标卡片
    @State private var cardEditRequest: CardEditRequest?
    @State private var detailCard: SharedCard?
    @State private var hasCheckedAnnualFeeStatus = false
    
    // 💡 优雅的毛玻璃弹窗队列与当前状态
    @State private var alertQueue: [AppAlertType] = []
    @State private var activeAppAlert: AppAlertType? = nil
    
    // 监听自动锁定状态
    @State private var lockManager = AutoLockManager.shared
    
    
    
    
    var body: some View {
        ZStack {
            if lockManager.isLocked {
                // 💡 超时防窥锁屏罩层
                LockScreenView()
                    .transition(.opacity)
            } else if loadingFailed {
                ContentUnavailableView {
                    Label("暂时无法打开卡包", systemImage: "lock.doc")
                } description: {
                    Text("未能读取本机卡片。请检查系统授权后重试；已有卡片没有被更改。")
                } actions: {
                    Button("重新读取", action: loadCards).buttonStyle(.borderedProminent)
                }
            } else if !hasLoadedCards {
                ProgressView("正在打开卡包…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 主导航页面
                NavigationSplitView {
                    SidebarView(selection: $selection, selectedBank: $selectedBank, cards: cards, hasPassword: lockManager.hasPassword, onLock: { lockManager.lock() })
                } detail: {
                    Group {
                        switch selection {
                        case .allCards:
                            AllCardsView(
                                cards: cards,
                                searchText: $searchText,
                                selectedCardID: $selectedCardID,
                                selectedBank: $selectedBank,
                                searchFocusRequest: searchFocusRequest,
                                cardCategoryFilter: $cardCategoryFilter,
                                groupBy: $groupBy,
                                sortBy: $sortBy,
                                showingFilterPopover: $showingFilterPopover,
                                cardEditRequest: $cardEditRequest,
                                detailCard: $detailCard,
                                onDelete: { card in deleteCard(card) },
                                onUpdateStatus: { card, newStatus in updateCardStatus(card, status: newStatus) },
                                onBatchUpdate: { ids, request in
                                    applyBatchUpdate(cardIDs: ids, request: request)
                                },
                                onBatchDelete: { ids in
                                    deleteCards(cardIDs: ids)
                                }
                            )
                        case .annualFeeAlert:
                            CardReminderView(
                                cards: cards,
                                onShowCard: { detailCard = $0 },
                                onEditCard: { cardEditRequest = CardEditRequest(mode: "edit", card: $0) },
                                onConfirmAnnualFees: { ids in
                                    let updated = cards.map { ids.contains($0.id) ? CardEditing.settingAnnualStatus("1", for: $0) : $0 }
                                    cards = syncCoordinator.commit(cards: updated)
                                }
                            )
                        case .statistics:
                            StatisticsView(cards: cards, onShowCard: { detailCard = $0 })
                        case .bestUsage:
                            MacBestUsageView(cards: cards, onEdit: { card in
                                cardEditRequest = CardEditRequest(mode: "edit", card: card)
                            }, date: $usageDate)
                        case .sync:
                            SyncDetailView(onBack: { settingsSection = .sync; selection = .settings })
                        case .cardCheck:
                            dataQualityIssuesDetailView
                        case .settings:
                            SettingsView(selectedSection: $settingsSection)
                        case .none:
                            VStack {
                                Image(systemName: "creditcard")
                                    .font(.system(size: 64))
                                    .foregroundColor(.gray.opacity(0.3))
                                Text("请从左侧菜单选择一个视图以开始使用")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(minWidth: 720, minHeight: 580)
                }
                .navigationSplitViewStyle(.balanced)
                .disabled(activeAppAlert != nil)
                .accessibilityHidden(activeAppAlert != nil)
                .transition(.opacity)
            }
            
            // 💡 自定义毛玻璃弹窗 Overlay
            if let activeAlert = activeAppAlert, !lockManager.isLocked {
                Color.black.opacity(0.3)
                    .transition(.opacity)
                    .ignoresSafeArea()
                    .onTapGesture {} // 拦截点击穿透
                
                CustomAlertOverlay(
                    activeAlert: activeAlert,
                    onDismiss: { dismissActiveAlert() },
                    onAction: { alert in handleAlertAction(alert) }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(999)
            }
        }
        .animation(walletAnimation, value: lockManager.isLocked)
        .onAppear {
            syncCoordinator.onCardsChanged = { updatedCards in
                self.cards = updatedCards
                refreshSystemNotifications(for: updatedCards)
            }
            loadCards()
            runInitialAnnualFeeCheckIfNeeded()
        }
        .onChange(of: lockManager.isLocked) { _, isLocked in
            if !isLocked {
                runInitialAnnualFeeCheckIfNeeded()
                refreshSystemNotifications(for: cards)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .walletNewCard)) { _ in
            guard !lockManager.isLocked, hasLoadedCards, activeAppAlert == nil, cardEditRequest == nil, detailCard == nil else { return }
            cardEditRequest = CardEditRequest(mode: "add", card: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .walletFindCard)) { _ in
            guard !lockManager.isLocked, hasLoadedCards, activeAppAlert == nil, cardEditRequest == nil, detailCard == nil else { return }
            selection = .allCards
            searchFocusRequest += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .walletEditCard)) { _ in
            guard !lockManager.isLocked, hasLoadedCards, activeAppAlert == nil, cardEditRequest == nil else { return }
            guard detailCard != nil || selection == .allCards else { return }
            let id = detailCard?.id ?? selectedCardID
            guard let card = cards.first(where: { $0.id == id }) else { return }
            if detailCard != nil {
                detailCard = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { cardEditRequest = CardEditRequest(mode: "edit", card: card) }
            } else { cardEditRequest = CardEditRequest(mode: "edit", card: card) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .walletSettings)) { _ in
            guard !lockManager.isLocked, hasLoadedCards, activeAppAlert == nil, cardEditRequest == nil, detailCard == nil else { return }
            selection = .settings
        }
        // 请求存在后才创建完整表单，避免首次呈现产生空内容窗口
        .sheet(item: $cardEditRequest) { request in
            CardEditView(
                mode: request.mode,
                cardToEdit: request.card,
                initialCardCategory: request.card?.cardCategory ?? request.cardCategory,
                existingCards: cards,
                onSubmit: { submittedCard in
                    let updated = CardEditing.applySubmission(submittedCard, previous: request.mode == "add" ? nil : request.card, to: cards)
                    cards = syncCoordinator.commit(cards: updated)
                    if let previous = request.card, !selectedBank.isEmpty, BankNameNormalizer.namesReferToSameBank(selectedBank, previous.bank) {
                        selectedBank = BankNameNormalizer.display(submittedCard.bank)
                    }
                }
            )
        }
        .sheet(item: $detailCard) { card in
            CardDetailView(
                card: card,
                onEdit: {
                    detailCard = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        cardEditRequest = CardEditRequest(mode: "edit", card: card)
                    }
                }
            )
        }
        .environment(\.walletIsLocked, lockManager.isLocked)
    }
    



    private var dataQualityIssuesDetailView: some View {
        let issues = DateCalculator.analyzeDataQuality(cards: cards)
        
        return VStack(spacing: 0) {
            WalletPageHeader(title: "检查卡片", subtitle: String(localized: "查找重复卡号、缺失信息和日期格式问题。")) {
                Text(issues.isEmpty ? "未发现问题" : "\(issues.count) 项待处理")
                    .font(.caption).foregroundStyle(issues.isEmpty ? palette.success : palette.warning)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(palette.selection, in: Capsule())
            }
            .padding(24)
            
            if issues.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 56))
                        .foregroundColor(palette.success.opacity(0.7))
                    Text("检查完成，未发现这些常见问题")
                        .font(.headline)
                    Text("已检查卡号、账单日、还款日、年费及有效期格式。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.01))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)], spacing: 16) {
                            ForEach(issues) { issue in
                                let associatedCard = findCard(for: issue.cardName)
                                DataIssueGridItem(
                                    issue: issue,
                                    card: associatedCard,
                                    onAction: {
                                        if let card = associatedCard {
                                            cardEditRequest = CardEditRequest(mode: "edit", card: card)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(24)
                }
                .background(Color.primary.opacity(0.005))
            }
        }
    }


    private func findCard(for cardName: String) -> SharedCard? {
        guard !cardName.isEmpty else { return nil }
        return cards.first { card in
            let bank = card.bank.trimmingCharacters(in: .whitespacesAndNewlines)
            let alias = (card.alias ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let name = "\(bank.isEmpty ? "未知银行" : bank) - \(alias.isEmpty ? "未命名卡片" : alias)"
            return name == cardName
        }
    }
    
    private func loadCards() {
        let result = LocalStorageManager.read()
        switch result {
        case .success(let loadedCards):
            loadingFailed = false
            hasLoadedCards = true
            self.cards = syncCoordinator.bootstrap(localCards: loadedCards)
            refreshSystemNotifications(for: self.cards)
        case .failure(let error):
            print("读取本地数据失败，可能密码错误或数据损坏: \(error.localizedDescription)")
            loadingFailed = true
            hasLoadedCards = false
        }
    }
    
    private func runInitialAnnualFeeCheckIfNeeded() {
        guard hasLoadedCards, !hasCheckedAnnualFeeStatus, !lockManager.isLocked else { return }
        hasCheckedAnnualFeeStatus = true
        runUnifiedCardRemindersCheck()
    }

    private func queueAlert(_ alert: AppAlertType) {
        guard !alertQueue.contains(where: { $0.id == alert.id }) && activeAppAlert?.id != alert.id else {
            return
        }
        alertQueue.append(alert)
        if activeAppAlert == nil {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                activeAppAlert = alertQueue.removeFirst()
            }
        }
    }

    private func dismissActiveAlert() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeAppAlert = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if !alertQueue.isEmpty {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    activeAppAlert = alertQueue.removeFirst()
                }
            }
        }
    }

    private func handleAlertAction(_ alert: AppAlertType) {
        switch alert {
        case .unifiedReminders:
            selection = .annualFeeAlert
            dismissActiveAlert()
        case .deleteCard(let card):
            cards.removeAll { $0.id == card.id }
            cards = syncCoordinator.commit(cards: cards, deletedCardIDs: [card.id])
            dismissActiveAlert()
        }
    }

    private func runUnifiedCardRemindersCheck() {
        let billingReminders = DateCalculator.billingCycleReminderItems(for: cards)
        
        let annualFeeReminders = cards.filter { card in
            guard card.cardCategory != "debit",
                  card.isQualified != "3",
                  let diffDays = DateCalculator.annualFeeRemainingDays(card.nextAnnualFeeCollectionTime) else {
                return false
            }
            return diffDays <= 60 && diffDays >= 0
        }
        
        let expiryReminders = cards.compactMap { card -> (card: SharedCard, status: DateCalculator.CardExpiryStatus)? in
            guard let status = cardExpiryReminderStatus(for: card) else { return nil }
            return (card, status)
        }.sorted { lhs, rhs in
            let lhsPriority = lhs.status == .expired ? 0 : 1
            let rhsPriority = rhs.status == .expired ? 0 : 1
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return lhs.card.bank < rhs.card.bank
        }
        
        if !billingReminders.isEmpty || !annualFeeReminders.isEmpty || !expiryReminders.isEmpty {
            queueAlert(.unifiedReminders(
                billingReminders: billingReminders,
                annualFeeReminders: annualFeeReminders,
                expiryReminders: expiryReminders
            ))
        }
    }

    private func refreshSystemNotifications(for cards: [SharedCard]) {
        Task {
            await CardSystemNotificationCenter.shared.refresh(cards: cards, locked: lockManager.isLocked)
        }
    }

    private func dataIssueColor(_ severity: String) -> Color {
        switch severity {
        case "严重":
            return Color.red
        case "警告":
            return palette.warning
        default:
            return palette.accent
        }
    }

    private func dataIssueIcon(_ severity: String) -> String {
        switch severity {
        case "严重":
            return "xmark.octagon.fill"
        case "警告":
            return "exclamationmark.triangle.fill"
        default:
            return "info.circle.fill"
        }
    }

    private func cardExpiryReminderStatus(for card: SharedCard) -> DateCalculator.CardExpiryStatus? {
        guard let status = DateCalculator.cardExpiryStatus(valid: card.valid),
              status == .expired || status == .soonExpiring else {
            return nil
        }
        return status
    }
    
    private func deleteCard(_ card: SharedCard) {
        queueAlert(.deleteCard(card: card))
    }

    
    private func updateCardStatus(_ card: SharedCard, status: String) {
        guard card.cardCategory != "debit" else { return }
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            let updatedCard = CardEditing.settingAnnualStatus(status, for: cards[index])
            cards[index] = updatedCard
            cards = syncCoordinator.commit(cards: cards)
        }
    }

    private func applyBatchUpdate(cardIDs: Set<String>, request: BatchUpdateRequest) {
        guard !cardIDs.isEmpty else { return }
        for index in cards.indices where cardIDs.contains(cards[index].id) {
            if let category = request.cardCategory {
                cards[index].cardCategory = category == "debit" ? "debit" : "credit"
            }
            if cards[index].cardCategory != "debit" {
                if let status = request.status {
                    cards[index].isQualified = status
                    if status == "3" {
                        cards[index].nextAnnualFeeCollectionTime = nil
                    }
                }
                if let annualFee = request.annualFee {
                    cards[index].annualFee = annualFee
                }
                if let nextDate = request.nextAnnualFeeDate, request.status != "3" {
                    cards[index].nextAnnualFeeCollectionTime = nextDate
                }
            }
            if let valid = request.valid {
                cards[index].valid = valid
            }
            cards[index].lastModifyTime = DateCalculator.timestamp(from: Date())
        }
        cards = syncCoordinator.commit(cards: cards)
    }

    private func deleteCards(cardIDs: Set<String>) {
        guard !cardIDs.isEmpty else { return }
        cards.removeAll { cardIDs.contains($0.id) }
        cards = syncCoordinator.commit(cards: cards, deletedCardIDs: cardIDs)
    }
}


@MainActor
private final class CardSystemNotificationCenter {
    static let shared = CardSystemNotificationCenter()

    private let center = UNUserNotificationCenter.current()
    private let defaultsKey = "card_system_notification_daily_v1"
    private let scheduledPrefix = "card_scheduled_"
    private var pendingRefresh: (cards: [SharedCard], locked: Bool)?
    private var isRefreshing = false

    private struct PlannedNotification {
        let identifier: String
        let fireDate: Date
        let title: String
        let body: String
        let cardID: String
    }

    private init() {}

    func refresh(cards: [SharedCard], locked: Bool) async {
        pendingRefresh = (cards, locked)
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }
        while let request = pendingRefresh {
            pendingRefresh = nil
            await performRefresh(cards: request.cards, locked: request.locked)
        }
    }

    private func performRefresh(cards: [SharedCard], locked: Bool) async {
        if cards.isEmpty {
            await replaceScheduledNotifications(cards: [])
            return
        }
        guard await requestAuthorizationIfNeeded() else { return }

        await replaceScheduledNotifications(cards: cards)
        if pendingRefresh != nil { return }
        guard !locked else { return }

        let billingCount = DateCalculator.billingCycleReminderItems(for: cards).count
        let annualCount = cards.filter { DateCalculator.annualFeeDetection(for: $0) != nil }.count
        let expiryCount = cards.filter { card in
            guard let status = DateCalculator.cardExpiryStatus(valid: card.valid) else { return false }
            return status == .expired || status == .soonExpiring
        }.count
        let total = billingCount + annualCount + expiryCount
        guard total > 0 else { return }

        let todayKey = DateCalculator.formatDate(Date())
        let fingerprint = "\(todayKey)|\(billingCount)|\(annualCount)|\(expiryCount)"
        guard UserDefaults.standard.string(forKey: defaultsKey) != fingerprint else { return }
        var parts: [String] = []
        if billingCount > 0 { parts.append("还款/账单 \(billingCount) 项") }
        if annualCount > 0 { parts.append("年费 \(annualCount) 项") }
        if expiryCount > 0 { parts.append("有效期 \(expiryCount) 项") }

        let content = UNMutableNotificationContent()
        content.title = "银行卡提醒"
        content.body = "检测到\(parts.joined(separator: "、"))，请打开应用查看。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "card_daily_summary_\(todayKey)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            UserDefaults.standard.set(fingerprint, forKey: defaultsKey)
        } catch {
            print("发送系统通知失败: \(error.localizedDescription)")
        }
    }

    private func replaceScheduledNotifications(cards: [SharedCard]) async {
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending.map(\.identifier).filter { $0.hasPrefix(scheduledPrefix) }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }

        let now = Date()
        let plans = buildPlans(cards: cards, now: now)
            .filter { $0.fireDate.timeIntervalSince(now) > 30 }
            .sorted { $0.fireDate < $1.fireDate }

        // 控制排程数量，优先保证最近一年的最早提醒。
        for plan in plans.prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            content.userInfo = ["cardID": plan.cardID]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: plan.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                print("排程系统通知失败: \(error.localizedDescription)")
            }
        }
    }

    private func buildPlans(cards: [SharedCard], now: Date) -> [PlannedNotification] {
        var plans: [PlannedNotification] = []
        let calendar = Calendar.current

        for card in cards where card.cardCategory != "debit" {
            if let billDay = dayNumber(card.accountBillDate) {
                for monthOffset in 0..<13 {
                    guard let target = monthlyDate(day: billDay, monthOffset: monthOffset, from: now),
                          let fireDate = calendar.date(byAdding: .day, value: -DateCalculator.billWarningDays, to: target) else { continue }
                    plans.append(
                        plan(
                            card: card,
                            kind: "bill",
                            target: target,
                            fireDate: notificationTime(fireDate),
                            title: "信用卡账单日提醒",
                            body: "\(DateCalculator.billWarningDays) 天后是账单日，请留意本期账单。"
                        )
                    )
                }
            }

            if let dueDay = dayNumber(card.dueDate) {
                for monthOffset in 0..<13 {
                    guard let target = monthlyDate(day: dueDay, monthOffset: monthOffset, from: now),
                          let fireDate = calendar.date(byAdding: .day, value: -DateCalculator.repaymentWarningDays, to: target) else { continue }
                    plans.append(
                        plan(
                            card: card,
                            kind: "repayment",
                            target: target,
                            fireDate: notificationTime(fireDate),
                            title: "信用卡还款提醒",
                            body: "\(DateCalculator.repaymentWarningDays) 天后是还款日，请及时核对并安排还款。"
                        )
                    )
                }
            }

            if card.isQualified != "3",
               let annualTarget = DateCalculator.date(fromTimestamp: card.nextAnnualFeeCollectionTime),
               let fireDate = calendar.date(byAdding: .day, value: -60, to: annualTarget) {
                plans.append(
                    plan(
                        card: card,
                        kind: "annual",
                        target: annualTarget,
                        fireDate: notificationTime(fireDate),
                        title: "信用卡年费提醒",
                        body: "距离下次年费收取约 60 天，请确认本周期达标情况。"
                    )
                )
            }

            if let expiryTarget = expiryDate(card.valid),
               let fireDate = calendar.date(byAdding: .month, value: -6, to: expiryTarget) {
                plans.append(
                    plan(
                        card: card,
                        kind: "expiry",
                        target: expiryTarget,
                        fireDate: notificationTime(fireDate),
                        title: "银行卡有效期提醒",
                        body: "卡片将在约 6 个月后到期，请提前联系发卡行换卡。"
                    )
                )
            }
        }
        return plans
    }

    private func plan(
        card: SharedCard,
        kind: String,
        target: Date,
        fireDate: Date,
        title: String,
        body: String
    ) -> PlannedNotification {
        let dateKey = ISO8601DateFormatter().string(from: target).prefix(10)
        return PlannedNotification(
            identifier: "\(scheduledPrefix)\(kind)_\(card.id)_\(dateKey)",
            fireDate: fireDate,
            title: title,
            body: body,
            cardID: card.id
        )
    }

    private func monthlyDate(day: Int, monthOffset: Int, from now: Date) -> Date? {
        let calendar = Calendar.current
        guard let month = calendar.date(byAdding: .month, value: monthOffset, to: now),
              let range = calendar.range(of: .day, in: .month, for: month) else { return nil }
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = min(day, range.count)
        components.hour = 9
        return calendar.date(from: components)
    }

    private func notificationTime(_ date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? date
    }

    private func expiryDate(_ value: String?) -> Date? {
        let parts = (value ?? "").split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let year = Int(parts[1]),
              (1...12).contains(month) else { return nil }
        return Calendar.current.date(from: DateComponents(year: 2000 + year, month: month, day: 1, hour: 9))
    }

    private func dayNumber(_ value: String?) -> Int? {
        guard let value,
              let day = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...31).contains(day) else { return nil }
        return day
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }
}

// MARK: - 自定义弹窗关联类型与视图

fileprivate enum AppAlertType: Identifiable, Equatable {
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

fileprivate struct CustomAlertOverlay: View {
    let activeAlert: AppAlertType
    let onDismiss: () -> Void
    let onAction: (AppAlertType) -> Void
    @Environment(\.walletPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 13) {
                Image(systemName: isDeletion ? "trash" : "calendar.badge.clock")
                    .font(.system(size: 23)).foregroundStyle(isDeletion ? Color.red : palette.accent)
                    .frame(width: 46, height: 46)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 13))
                Text(isDeletion ? "删除这张卡片？" : "有需要留意的卡片")
                    .font(.system(size: 19, weight: .semibold))
            }
            switch activeAlert {
            case .deleteCard(let card):
                Text("\(card.bank) · 尾号 \(String(card.cardNumber.suffix(4)))").font(.headline)
                Text("卡片和关联提醒将被删除。同步后，其他设备也会删除这张卡片；此操作无法撤销。")
                    .font(.subheadline).foregroundStyle(.secondary)
            case .unifiedReminders(let billing, let annual, let expiry):
                Text("根据已填写的信息，以下事项需要关注。")
                    .font(.subheadline).foregroundStyle(.secondary)
                VStack(spacing: 13) {
                    summary("账单与还款", icon: "doc.text", count: billing.count)
                    summary("年费", icon: "calendar.badge.exclamationmark", count: annual.count)
                    summary("有效期", icon: "creditcard", count: expiry.count)
                }
                .modifier(WalletSurface())
            }
            HStack(spacing: 12) {
                Spacer()
                Button(isDeletion ? "取消" : "稍后查看", action: onDismiss).keyboardShortcut(.cancelAction)
                if isDeletion {
                    Button("删除卡片", role: .destructive) { onAction(activeAlert) }
                } else {
                    Button("查看提醒") { onAction(activeAlert) }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(25)
        .frame(width: 440)
        .modifier(WalletGlass())
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.edge, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private var isDeletion: Bool { if case .deleteCard = activeAlert { return true }; return false }
    private func summary(_ title: LocalizedStringKey, icon: String, count: Int) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Text("\(count) 项").foregroundStyle(palette.accent).monospacedDigit() }
            .font(.system(size: 13))
    }
}


// MARK: - 异常数据网格卡片
fileprivate struct DataIssueGridItem: View {
    @Environment(\.walletPalette) private var palette
    let issue: DateCalculator.DataQualityIssue
    let card: SharedCard?
    let onAction: () -> Void
    
    @State private var isHovered = false
    
    private var severityColor: Color {
        switch issue.severity {
        case "严重":
            return Color.red
        case "警告":
            return palette.warning
        default:
            return palette.accent
        }
    }
    
    private var severityIcon: String {
        switch issue.severity {
        case "严重":
            return "xmark.octagon.fill"
        case "警告":
            return "exclamationmark.triangle.fill"
        default:
            return "info.circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: severityIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(issue.severity)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(severityColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(severityColor.opacity(0.12))
                .cornerRadius(6)
                
                Spacer()
                
                if let card = card {
                    Text(card.cardCategory == "debit" ? "储蓄卡" : "信用卡")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                
                if let card = card {
                    Text("\(card.bank) · \(card.alias ?? "无别名")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.8))
                } else if !issue.cardName.isEmpty {
                    Text(issue.cardName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.8))
                }
            }
            
            Text(issue.detail)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            if card != nil {
                Spacer(minLength: 0)
                
                HStack {
                    if let card = card {
                        Text("尾号 *\(card.cardNumber.suffix(4))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: onAction) {
                        HStack(spacing: 4) {
                            Text("去处理")
                            Image(systemName: "pencil")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(severityColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(severityColor.opacity(isHovered ? 0.08 : 0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(severityColor.opacity(isHovered ? 0.28 : 0.16), lineWidth: 1)
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hover
            }
        }
    }
}

// MARK: - 批量编辑

struct MacBatchEditView: View {
    let selectedCount: Int
    let onApply: (BatchUpdateRequest) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var updateStatus = false
    @State private var status = "1"
    @State private var updateAnnualFee = false
    @State private var annualFee = 0.0
    @State private var updateAnnualDate = false
    @State private var annualDate = Date()
    @State private var updateValid = false
    @State private var validDate = Date()
    @State private var updateCategory = false
    @State private var category = "credit"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("批量修改 \(selectedCount) 张卡片")
                .font(.title2)
                .bold()
            Text("仅勾选的字段会被更新，未勾选字段保持原值。")
                .font(.caption)
                .foregroundColor(.secondary)

            Form {
                Toggle("更新卡类别", isOn: $updateCategory)
                if updateCategory {
                    WalletChoiceBar(title: "卡类别", selection: $category, choices: [
                        WalletChoice(value: "credit", title: "信用卡"), WalletChoice(value: "debit", title: "储蓄卡")
                    ], showsTitle: true)
                }

                Toggle("更新年费状态", isOn: $updateStatus)
                if updateStatus {
                    Picker("年费状态", selection: $status) {
                        Text("已达标").tag("1")
                        Text("未达标").tag("2")
                        Text("终免年费").tag("3")
                    }
                }

                Toggle("更新年费金额", isOn: $updateAnnualFee)
                if updateAnnualFee {
                    TextField("年费金额", value: $annualFee, format: .number)
                }

                Toggle("更新下次年费日期", isOn: $updateAnnualDate)
                    .disabled(updateStatus && status == "3")
                if updateAnnualDate && !(updateStatus && status == "3") {
                    DatePicker("下次年费日期", selection: $annualDate, displayedComponents: .date)
                }

                Toggle("更新有效期", isOn: $updateValid)
                if updateValid {
                    DatePicker("有效期月份", selection: $validDate, displayedComponents: .date)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("应用修改") {
                    onApply(
                        BatchUpdateRequest(
                            status: updateStatus ? status : nil,
                            annualFee: updateAnnualFee ? annualFee : nil,
                            nextAnnualFeeDate: updateAnnualDate && !(updateStatus && status == "3") ? DateCalculator.timestamp(from: annualDate) : nil,
                            valid: updateValid ? validText : nil,
                            cardCategory: updateCategory ? category : nil
                        )
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
            }
        }
        .padding(24)
        .frame(width: 520, height: 620)
    }

    private var hasChanges: Bool {
        updateStatus || updateAnnualFee || updateAnnualDate || updateValid || updateCategory
    }

    private var validText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yy"
        return formatter.string(from: validDate)
    }
}
