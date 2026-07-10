import SwiftUI
import UserNotifications

private struct CardEditRequest: Identifiable {
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

fileprivate struct BatchUpdateRequest {
    var status: String?
    var annualFee: Double?
    var nextAnnualFeeDate: Double?
    var valid: String?
    var cardCategory: String?
}

private enum CardCategoryFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case credit = "信用卡"
    case debit = "储蓄卡"
    
    var id: String { rawValue }
}

fileprivate enum ToolSubView: String, CaseIterable, Identifiable {
    case bestUsage = "优惠用卡"
    case dataQualityIssues = "数据异常检测"
    case statistics = "数据与统计分析"
    case syncDetail = "同步历史与详情"
    
    var id: String { rawValue }
}

struct ContentView: View {
    @State private var cards: [SharedCard] = []
    @StateObject private var syncCoordinator = SyncCoordinator.shared
    @State private var selection: NavigationSection? = .allCards
    @State private var searchText = ""
    
    // 💡 分组和排序状态管理
    @State private var groupBy: GroupOption = .bank
    @State private var sortBy: SortOption = .limitDesc
    @State private var cardCategoryFilter: CardCategoryFilter = .all
    @State private var showingFilterPopover = false
    
    // 编辑弹窗请求，创建弹窗时一并携带模式和目标卡片
    @State private var cardEditRequest: CardEditRequest?
    @State private var detailCard: SharedCard?
    @State private var hasCheckedAnnualFeeStatus = false
    
    // 💡 优雅的毛玻璃弹窗队列与当前状态
    @State private var alertQueue: [AppAlertType] = []
    @State private var activeAppAlert: AppAlertType? = nil
    
    // 监听自动锁定状态
    @State private var lockManager = AutoLockManager.shared
    
    // 工具箱二级视图选中状态
    @State private var activeToolSubView: ToolSubView? = nil
    
    // 💡 规避 macOS titlebarAppearsTransparent 在模态 sheet 消失后下沉偏移的重绘触发器
    @State private var offsetResetTrigger = false
    
    private var hasDetailCard: Bool {
        detailCard != nil
    }
    
    private var hasCardEditRequest: Bool {
        cardEditRequest != nil
    }
    
    var searchFilteredCards: [SharedCard] {
        if searchText.isEmpty {
            return cards
        } else {
            return cards.filter { card in
                let categoryText = card.cardCategory == "debit" ? "储蓄卡 debit" : "信用卡 credit"
                return card.bank.localizedCaseInsensitiveContains(searchText) ||
                (card.alias ?? "").localizedCaseInsensitiveContains(searchText) ||
                card.cardNumber.localizedCaseInsensitiveContains(searchText) ||
                categoryText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }


    
    private var creditCardCount: Int { searchFilteredCards.filter { $0.cardCategory != "debit" }.count }
    private var debitCardCount: Int { searchFilteredCards.filter { $0.cardCategory == "debit" }.count }
    
    var body: some View {
        ZStack {
            if lockManager.isLocked {
                // 💡 超时防窥锁屏罩层
                LockScreenView()
                    .transition(.opacity)
            } else {
                // 主导航页面
                NavigationSplitView {
                    SidebarView(selection: $selection, cards: cards)
                } detail: {
                    Group {
                        switch selection {
                        case .allCards:
                            AllCardsView(
                                cards: cards,
                                searchFilteredCards: searchFilteredCards,
                                creditCardCount: creditCardCount,
                                debitCardCount: debitCardCount,
                                searchText: $searchText,
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
                                detailCard: $detailCard,
                                cardsBinding: $cards,
                                syncCoordinator: syncCoordinator
                            )
                        case .statistics:
                            StatisticsView(cards: cards)
                        case .tools:
                            toolsView
                        case .settings:
                            SettingsView()
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
                    .frame(minWidth: 500, minHeight: 400)
                }
                .transition(.opacity)
            }
            
            // 💡 自定义毛玻璃弹窗 Overlay
            if let activeAlert = activeAppAlert {
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
        .padding(.top, offsetResetTrigger ? 0.2 : 0)
        .animation(.easeInOut(duration: 0.3), value: lockManager.isLocked)
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
        .onChange(of: selection) { _, _ in
            activeToolSubView = nil
        }
        .onChange(of: hasDetailCard) { _, newValue in
            if !newValue {
                // 当卡片详情弹窗被关闭时，在下个 Layout Runloop 触发 0.2pt 微小重绘微调，强制 AppKit 重新刷新主窗口 safe area，解决 hiddenTitleBar 模式下的下移顽疾
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    offsetResetTrigger.toggle()
                }
            }
        }
        .onChange(of: hasCardEditRequest) { _, newValue in
            if !newValue {
                // 当编辑/添加卡片弹窗被关闭时同样触发，保障返回主视图时排版居中正常
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    offsetResetTrigger.toggle()
                }
            }
        }
        // 请求存在后才创建完整表单，避免首次呈现产生空内容窗口
        .sheet(item: $cardEditRequest) { request in
            CardEditView(
                mode: request.mode,
                cardToEdit: request.card,
                initialCardCategory: request.card?.cardCategory ?? request.cardCategory,
                existingCards: cards,
                onSubmit: { submittedCard in
                    var finalCard = submittedCard

                    // 编辑时首次切换为已达标，需要同时完成当前年费周期并顺延日期。
                    if request.mode != "add",
                       request.card?.isQualified != "1",
                       finalCard.isQualified == "1" {
                        finalCard.nextAnnualFeeCollectionTime = DateCalculator.timestampByAddingOneYear(
                            finalCard.nextAnnualFeeCollectionTime
                        )
                    }

                    if request.mode == "add" {
                        cards.append(finalCard)
                    } else {
                        if let index = cards.firstIndex(where: { $0.id == finalCard.id }) {
                            cards[index] = finalCard
                        }
                    }

                    
                    // 💡 联动同步：如果信用卡启用了共享额度，自动同步批量更新其他同银行的共享额度卡片
                    if finalCard.cardCategory != "debit", finalCard.isSharedLimit {
                        let finalType = (finalCard.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        for i in 0..<cards.count {
                            let cardType = (cards[i].type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                            if cards[i].id != finalCard.id &&
                                cards[i].cardCategory != "debit" &&
                                cards[i].country == finalCard.country &&
                               cardType == finalType &&
                               BankNameNormalizer.namesReferToSameBank(cards[i].bank, finalCard.bank) &&
                               cards[i].isSharedLimit {
                                cards[i].limit = finalCard.limit
                                cards[i].lastModifyTime = DateCalculator.timestamp(from: Date())
                            }
                        }
                    }
                    
                    self.cards = syncCoordinator.commit(cards: cards)
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
    }
    


    private var toolsView: some View {
        Group {
            if let subView = activeToolSubView {
                switch subView {
                case .bestUsage:
                    MacBestUsageView(
                        cards: cards,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeToolSubView = nil
                            }
                        },
                        onEdit: { card in
                            cardEditRequest = CardEditRequest(mode: "edit", card: card)
                        }
                    )
                case .dataQualityIssues:
                    dataQualityIssuesDetailView
                case .statistics:
                    statisticsDetailView
                case .syncDetail:
                    SyncDetailView(onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeToolSubView = nil
                        }
                    })
                }
            } else {
                toolsMainMenuView
            }
        }
    }

    private var toolsMainMenuView: some View {
        let issues = DateCalculator.analyzeDataQuality(cards: cards)
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("工具")
                            .font(.title2)
                            .bold()
                        Text("数据管理与分析中心")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)
                
                VStack(spacing: 16) {
                    ToolMenuButton(
                        iconName: "sparkles",
                        iconColor: SoftColors.purple,
                        title: "优惠用卡",
                        description: "根据今天的消费日期实时计算可用免息期，推荐当前首选信用卡",
                        badgeText: nil,
                        badgeColor: nil,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeToolSubView = .bestUsage
                            }
                        }
                    )

                    ToolMenuButton(
                        iconName: "exclamationmark.triangle.fill",
                        iconColor: issues.isEmpty ? SoftColors.green : SoftColors.orange,
                        title: "数据异常检测",
                        description: "一键分析检测重复卡号、格式异常、不合法账单日/还款日等数据质量问题",
                        badgeText: issues.isEmpty ? "正常" : "\(issues.count) 项异常",
                        badgeColor: issues.isEmpty ? SoftColors.green : SoftColors.orange,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeToolSubView = .dataQualityIssues
                            }
                        }
                    )
                    
                    ToolMenuButton(
                        iconName: "chart.pie.fill",
                        iconColor: SoftColors.blue,
                        title: "数据与统计分析",
                        description: "以直观图表展示信用卡额度占比、银行分布，推荐下一次最佳提额卡片",
                        badgeText: nil,
                        badgeColor: nil,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeToolSubView = .statistics
                            }
                        }
                    )
                    
                    ToolMenuButton(
                        iconName: "clock.arrow.circlepath",
                        iconColor: SoftColors.purple,
                        title: "同步历史与详情",
                        description: "查看 WebDAV 云端同步的耗时、读写文件历史、本机/云端变更的卡片详情日志",
                        badgeText: nil,
                        badgeColor: nil,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeToolSubView = .syncDetail
                            }
                        }
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: 800, alignment: .leading)
        }
    }

    private var dataQualityIssuesDetailView: some View {
        let issues = DateCalculator.analyzeDataQuality(cards: cards)
        
        return VStack(spacing: 0) {
            // 顶部返回与标题栏
            HStack(spacing: 14) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeToolSubView = nil
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("返回工具")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundColor(issues.isEmpty ? SoftColors.green : SoftColors.orange)
                    Text("数据异常检测")
                        .font(.title3)
                        .bold()
                }
                
                Spacer()
                
                // 角标
                Text(issues.isEmpty ? "数据良好" : "\(issues.count) 项待处理")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((issues.isEmpty ? SoftColors.green : SoftColors.orange).opacity(0.15))
                    .foregroundColor(issues.isEmpty ? SoftColors.green : SoftColors.orange)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            if issues.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 56))
                        .foregroundColor(SoftColors.green.opacity(0.7))
                    Text("非常好！未检测到任何数据异常")
                        .font(.headline)
                    Text("所有卡号、账单日、还款日、年费及有效期格式均处于健康状态。")
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

    private var statisticsDetailView: some View {
        VStack(spacing: 0) {
            // 顶部返回与标题栏
            HStack(spacing: 14) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeToolSubView = nil
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("返回工具")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 10) {
                    Image(systemName: "chart.pie.fill")
                        .font(.title3)
                        .foregroundColor(SoftColors.blue)
                    Text("数据与统计分析")
                        .font(.title3)
                        .bold()
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 嵌套 StatisticsView
            StatisticsView(cards: cards)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            self.cards = syncCoordinator.bootstrap(localCards: loadedCards)
            refreshSystemNotifications(for: self.cards)
        case .failure(let error):
            print("读取本地数据失败，可能密码错误或数据损坏: \(error.localizedDescription)")
            self.cards = []
        }
    }
    
    private func runInitialAnnualFeeCheckIfNeeded() {
        guard !hasCheckedAnnualFeeStatus, !lockManager.isLocked else { return }
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
            return SoftColors.red
        case "警告":
            return SoftColors.orange
        default:
            return SoftColors.cyan
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
            var updatedCard = cards[index]
            updatedCard.isQualified = status
            if status == "1" {
                updatedCard.nextAnnualFeeCollectionTime = DateCalculator.timestampByAddingOneYear(
                    updatedCard.nextAnnualFeeCollectionTime
                )
            } else if status == "3" {
                updatedCard.nextAnnualFeeCollectionTime = nil
            }
            updatedCard.lastModifyTime = DateCalculator.timestamp(from: Date())
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

fileprivate struct MacBestUsageView: View {
    let cards: [SharedCard]
    let onBack: () -> Void
    let onEdit: (SharedCard) -> Void

    private var creditCards: [SharedCard] {
        cards.filter { $0.cardCategory != "debit" }
    }

    private var rankedCards: [(card: SharedCard, days: Int)] {
        creditCards
            .map { ($0, DateCalculator.calculateInterestFreeDays(card: $0)) }
            .filter { $0.1 >= 0 }
            .sorted { $0.1 > $1.1 }
    }

    private var invalidCards: [SharedCard] {
        creditCards.filter { DateCalculator.calculateInterestFreeDays(card: $0) < 0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button(action: onBack) {
                    Label("返回工具", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.plain)

                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("优惠用卡")
                    .font(.title3)
                    .bold()
                Spacer()
                Text("按今天实时计算")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("根据账单日、还款日及账单日消费归属规则，按当前日期计算每张卡的实际可用免息期。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if rankedCards.isEmpty {
                        ContentUnavailableView(
                            "暂无可推荐的信用卡",
                            systemImage: "creditcard.trianglebadge.exclamationmark",
                            description: Text("请先为信用卡配置账单日和还款日。")
                        )
                        .frame(maxWidth: .infinity, minHeight: 260)
                    } else {
                        ForEach(Array(rankedCards.enumerated()), id: \.element.card.id) { index, item in
                            HStack(spacing: 16) {
                                Text(rankText(index))
                                    .font(.title2)
                                    .frame(width: 44)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(displayName(item.card))
                                        .font(.headline)
                                    Text("账单日 \(item.card.accountBillDate ?? "-") 日 · 还款日 \(item.card.dueDate ?? "-") 日")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(spacing: 2) {
                                    Text("\(item.days)")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(index == 0 ? .orange : .cyan)
                                    Text("天免息期")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Button("配置") { onEdit(item.card) }
                                    .buttonStyle(.bordered)
                            }
                            .padding(16)
                            .background(index == 0 ? Color.orange.opacity(0.08) : Color.primary.opacity(0.035))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(index == 0 ? Color.orange.opacity(0.25) : Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }

                    if !invalidCards.isEmpty {
                        DisclosureGroup("\(invalidCards.count) 张信用卡尚未配置完整账单信息") {
                            VStack(spacing: 8) {
                                ForEach(invalidCards) { card in
                                    HStack {
                                        Text(displayName(card))
                                        Spacer()
                                        Button("去配置") { onEdit(card) }
                                            .buttonStyle(.link)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(14)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(12)
                    }
                }
                .padding(24)
                .frame(maxWidth: 820)
            }
        }
    }

    private func displayName(_ card: SharedCard) -> String {
        [card.bank, card.alias ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func rankText(_ index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "#\(index + 1)"
        }
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
                                        bankLogo(for: item.card.bank)
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
                                        bankLogo(for: item.card.bank)
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
                                        bankLogo(for: card.bank)
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
                                        bankLogo(for: item.card.bank)
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
                                        colors: [bankColor(for: card.bank), bankColor(for: card.bank).opacity(0.8)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                                    .frame(height: 120)
                                    .shadow(color: bankColor(for: card.bank).opacity(0.35), radius: 10, x: 0, y: 5)
                                
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
    
    // MARK: - 辅助组件
    
    private func bankLogo(for bankName: String) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [bankColor(for: bankName), bankColor(for: bankName).opacity(0.75)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 26, height: 26)
            
            Text(String(bankName.prefix(1)))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - 辅助方法
    
    private func bankColor(for bankName: String) -> Color {
        if bankName.contains("招商") { return .red }
        if bankName.contains("建设") { return .blue }
        if bankName.contains("中国") { return .red }
        if bankName.contains("工商") { return .red }
        if bankName.contains("农业") { return .green }
        if bankName.contains("交通") { return .blue }
        if bankName.contains("浦发") { return .blue }
        if bankName.contains("兴业") { return .blue }
        if bankName.contains("中信") { return .red }
        if bankName.contains("民生") { return .green }
        if bankName.contains("光大") { return .orange }
        if bankName.contains("广发") { return .red }
        if bankName.contains("平安") { return .orange }
        if bankName.contains("汇丰") { return .red }
        if bankName.contains("渣打") { return .blue }
        if bankName.contains("花旗") { return .blue }
        if bankName.contains("工银") { return .red }
        
        let hash = abs(bankName.hashValue)
        let colors: [Color] = [.cyan, .teal, .blue, .purple, .pink, .indigo]
        return colors[hash % colors.count]
    }
    
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

// MARK: - 精美提醒看板条目卡片

struct ReminderDashboardItem: View {
    let card: SharedCard
    let title: String
    let detail: String
    let tag: String
    let themeColor: Color
    let actionLabel: String
    let onAction: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 银行卡彩色迷你标
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [bankColor(for: card.bank), bankColor(for: card.bank).opacity(0.75)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 24, height: 24)
                        
                        Text(String(card.bank.prefix(1)))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(card.bank)
                            .font(.system(size: 13, weight: .semibold))
                        Text(card.alias ?? "未命名卡片")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 右侧 Tag
                Text(tag)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(themeColor.opacity(0.12))
                    .foregroundColor(themeColor)
                    .cornerRadius(6)
            }
            
            Text(detail)
                .font(.system(size: 11.5))
                .foregroundColor(.primary.opacity(0.75))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Text("尾号 *\(card.cardNumber.suffix(4))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Text(actionLabel)
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(themeColor.opacity(isHovered ? 0.08 : 0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.opacity(isHovered ? 0.28 : 0.16), lineWidth: 1)
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hover
            }
        }
    }
    
    private func bankColor(for bankName: String) -> Color {
        if bankName.contains("招商") { return .red }
        if bankName.contains("建设") { return .blue }
        if bankName.contains("中国") { return .red }
        if bankName.contains("工商") { return .red }
        if bankName.contains("农业") { return .green }
        if bankName.contains("交通") { return .blue }
        if bankName.contains("浦发") { return .blue }
        if bankName.contains("兴业") { return .blue }
        if bankName.contains("中信") { return .red }
        if bankName.contains("民生") { return .green }
        if bankName.contains("光大") { return .orange }
        if bankName.contains("广发") { return .red }
        if bankName.contains("平安") { return .orange }
        if bankName.contains("汇丰") { return .red }
        if bankName.contains("渣打") { return .blue }
        if bankName.contains("花旗") { return .blue }
        if bankName.contains("工银") { return .red }
        
        let hash = abs(bankName.hashValue)
        let colors: [Color] = [.cyan, .teal, .blue, .purple, .pink, .indigo]
        return colors[hash % colors.count]
    }
}

fileprivate struct SoftColors {
    static let red = Color(red: 1.0, green: 57.0/255.0, blue: 60.0/255.0)
    static let blue = Color(red: 0.0, green: 198.0/255.0, blue: 246.0/255.0)
    static let orange = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let purple = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let green = Color(red: 0.06, green: 0.73, blue: 0.50)
    static let cyan = Color(red: 0.0, green: 0.85, blue: 0.95)
}

// MARK: - 工具箱高级卡片菜单项按钮
fileprivate struct ToolMenuButton: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let description: String
    let badgeText: String?
    let badgeColor: Color?
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let bText = badgeText, let bColor = badgeColor {
                            Text(bText)
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(bColor.opacity(0.15))
                                .foregroundColor(bColor)
                                .cornerRadius(6)
                        }
                    }
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            .padding(18)
            .background(Color.primary.opacity(isHovered ? 0.04 : 0.02))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? iconColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hover
            }
        }
    }
}

// MARK: - 异常数据网格卡片
fileprivate struct DataIssueGridItem: View {
    let issue: DateCalculator.DataQualityIssue
    let card: SharedCard?
    let onAction: () -> Void
    
    @State private var isHovered = false
    
    private var severityColor: Color {
        switch issue.severity {
        case "严重":
            return SoftColors.red
        case "警告":
            return SoftColors.orange
        default:
            return SoftColors.cyan
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

// MARK: - 拆分出的卡包主视图以优化重绘性能
fileprivate struct AllCardsView: View {
    let cards: [SharedCard]
    let searchFilteredCards: [SharedCard]
    let creditCardCount: Int
    let debitCardCount: Int
    @Binding var searchText: String
    @Binding var cardCategoryFilter: CardCategoryFilter
    @Binding var groupBy: GroupOption
    @Binding var sortBy: SortOption
    @Binding var showingFilterPopover: Bool
    @Binding var cardEditRequest: CardEditRequest?
    @Binding var detailCard: SharedCard?
    let onDelete: (SharedCard) -> Void
    let onUpdateStatus: (SharedCard, String) -> Void
    let onBatchUpdate: (Set<String>, BatchUpdateRequest) -> Void
    let onBatchDelete: (Set<String>) -> Void
    @State private var isSelectionMode = false
    @State private var selectedCardIDs: Set<String> = []
    @State private var showingBatchEditor = false
    @State private var showingBatchDeleteConfirmation = false

    // 局部计算属性：最终显示的列表，切断 ContentView 对其频繁重绘
    private var filteredCards: [SharedCard] {
        searchFilteredCards.filter { card in
            switch cardCategoryFilter {
            case .all:
                return true
            case .credit:
                return card.cardCategory != "debit"
            case .debit:
                return card.cardCategory == "debit"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                    Text("卡包")
                        .font(.title2)
                        .bold()
                }
                
                Spacer()
                
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索银行、别名、卡号、卡类别...", text: $searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 180)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
                
                Picker("卡类别", selection: $cardCategoryFilter) {
                    Text("全部 \(searchFilteredCards.count)").tag(CardCategoryFilter.all)
                    Text("信用卡 \(creditCardCount)").tag(CardCategoryFilter.credit)
                    Text("储蓄卡 \(debitCardCount)").tag(CardCategoryFilter.debit)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
                
                // 💡 筛选与组合排序胶囊控制按钮
                Button {
                    showingFilterPopover = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text("分组: \(groupBy.rawValue) · 排序: \(sortBy.rawValue)")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingFilterPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 14) {
                        // 1. 分组选择区
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.grid.3x3.fill")
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 12))
                                Text("选择分组维度")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 6) {
                                ForEach(GroupOption.allCases) { option in
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            groupBy = option
                                        }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: option.icon)
                                                .font(.system(size: 14))
                                            Text(option.rawValue)
                                                .font(.system(size: 9))
                                        }
                                        .frame(width: 58, height: 48)
                                        .background(groupBy == option ? Color.cyan.opacity(0.15) : Color.primary.opacity(0.03))
                                        .foregroundColor(groupBy == option ? .cyan : .primary)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(groupBy == option ? Color.cyan.opacity(0.4) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Divider()
                            .opacity(0.5)
                        
                        // 2. 排序选择区
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.arrow.down.circle.fill")
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 12))
                                Text("选择排序算法")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                ForEach(SortOption.allCases) { option in
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            sortBy = option
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: option.icon)
                                                .font(.system(size: 12))
                                                .foregroundColor(sortBy == option ? .cyan : .secondary)
                                            Text(option.rawValue)
                                                .font(.system(size: 11))
                                                .foregroundColor(sortBy == option ? .primary : .secondary)
                                            Spacer()
                                            if sortBy == option {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.cyan)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(sortBy == option ? Color.cyan.opacity(0.08) : Color.clear)
                                        .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(width: 320)
                    .background(.ultraThinMaterial)
                }
                
                // 新增按钮
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSelectionMode.toggle()
                        if !isSelectionMode { selectedCardIDs.removeAll() }
                    }
                } label: {
                    Label(isSelectionMode ? "退出批量" : "批量操作", systemImage: isSelectionMode ? "xmark.circle" : "checklist")
                }
                .buttonStyle(.bordered)

                Button {
                    cardEditRequest = CardEditRequest(mode: "add", card: nil, cardCategory: "credit")
                } label: {
                    Label("新增卡片", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Divider()
                .background(Color.white.opacity(0.1))

            if isSelectionMode {
                HStack(spacing: 12) {
                    Text("已选择 \(selectedCardIDs.count) 张")
                        .font(.system(size: 12, weight: .semibold))
                    Button(selectedCardIDs.count == filteredCards.count ? "取消全选" : "全选当前结果") {
                        if selectedCardIDs.count == filteredCards.count {
                            selectedCardIDs.removeAll()
                        } else {
                            selectedCardIDs = Set(filteredCards.map(\.id))
                        }
                    }
                    .buttonStyle(.link)
                    Spacer()
                    Button("批量修改") { showingBatchEditor = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedCardIDs.isEmpty)
                    Button("批量删除", role: .destructive) { showingBatchDeleteConfirmation = true }
                        .buttonStyle(.bordered)
                        .disabled(selectedCardIDs.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.cyan.opacity(0.06))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if filteredCards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                    Text(searchText.isEmpty ? "目前暂无银行卡数据，点击右上方新增卡片吧！" : "没有找到符合搜索条件的卡片")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CardGridView(
                    cards: filteredCards,
                    groupBy: groupBy,
                    sortBy: sortBy,
                    selectionEnabled: isSelectionMode,
                    selectedCardIDs: selectedCardIDs,
                    onToggleSelection: { card in
                        if selectedCardIDs.contains(card.id) {
                            selectedCardIDs.remove(card.id)
                        } else {
                            selectedCardIDs.insert(card.id)
                        }
                    },
                    onEdit: { card in
                        cardEditRequest = CardEditRequest(mode: "edit", card: card)
                    },
                    onViewDetails: { card in
                        detailCard = card
                    },
                    onDelete: { card in
                        onDelete(card)
                    },
                    onUpdateStatus: { card, newStatus in
                        onUpdateStatus(card, newStatus)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingBatchEditor) {
            MacBatchEditView(selectedCount: selectedCardIDs.count) { request in
                onBatchUpdate(selectedCardIDs, request)
                selectedCardIDs.removeAll()
                isSelectionMode = false
            }
        }
        .alert("批量删除确认", isPresented: $showingBatchDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除 \(selectedCardIDs.count) 张卡片", role: .destructive) {
                onBatchDelete(selectedCardIDs)
                selectedCardIDs.removeAll()
                isSelectionMode = false
            }
        } message: {
            Text("删除后会通过同步账本传播到其他设备，此操作无法撤销。")
        }
    }
}

fileprivate struct MacBatchEditView: View {
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
                    Picker("卡类别", selection: $category) {
                        Text("信用卡").tag("credit")
                        Text("储蓄卡").tag("debit")
                    }
                    .pickerStyle(.segmented)
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
                            nextAnnualFeeDate: updateAnnualDate && status != "3" ? DateCalculator.timestamp(from: annualDate) : nil,
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

// MARK: - 拆分出的卡片提醒视图以优化重绘性能
fileprivate struct CardReminderView: View {
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
            // 顶部工具栏
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title2)
                        .foregroundColor(SoftColors.orange)
                    Text("卡片提醒")
                        .font(.title2)
                        .bold()
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            if !hasAnyReminder {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 56))
                        .foregroundColor(SoftColors.green.opacity(0.7))
                    Text("省心！目前没有任何需要关注的卡片提醒")
                        .font(.headline)
                    Text("您的账单还款、年费达标以及卡片有效期均处于安全状态。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                        }
                    }
                    .padding(24)
                }
                .background(Color.primary.opacity(0.005))
            }
        }
    }
}
