import SwiftUI

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
    @State private var notificationRefreshTask: Task<Void, Never>?
    
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
                            ToolsCenterView(
                                cards: cards,
                                activeSubView: $activeToolSubView,
                                onEdit: { card in
                                    cardEditRequest = CardEditRequest(mode: "edit", card: card)
                                }
                            )
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
        notificationRefreshTask?.cancel()
        let locked = lockManager.isLocked
        notificationRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await CardSystemNotificationCenter.shared.refresh(cards: cards, locked: locked)
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
