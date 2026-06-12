import SwiftUI

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

private enum CardCategoryFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case credit = "信用卡"
    case debit = "储蓄卡"
    
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
    
    // 监听自动锁定状态
    @State private var lockManager = AutoLockManager.shared
    
    var filteredCards: [SharedCard] {
        let categoryCards: [SharedCard]
        switch cardCategoryFilter {
        case .all:
            categoryCards = cards
        case .credit:
            categoryCards = cards.filter { $0.cardCategory != "debit" }
        case .debit:
            categoryCards = cards.filter { $0.cardCategory == "debit" }
        }
        
        if searchText.isEmpty {
            return categoryCards
        } else {
            return categoryCards.filter { card in
                let categoryText = card.cardCategory == "debit" ? "储蓄卡 debit" : "信用卡 credit"
                return card.bank.localizedCaseInsensitiveContains(searchText) ||
                (card.alias ?? "").localizedCaseInsensitiveContains(searchText) ||
                card.cardNumber.localizedCaseInsensitiveContains(searchText) ||
                categoryText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var creditCardCount: Int { cards.filter { $0.cardCategory != "debit" }.count }
    private var debitCardCount: Int { cards.filter { $0.cardCategory == "debit" }.count }
    
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
                            allCardsView
                        case .annualFeeAlert:
                            annualFeeAlertView
                        case .statistics:
                            StatisticsView(cards: cards)
                        case .cloudSync:
                            CloudSyncView()
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
        }
        .animation(.easeInOut(duration: 0.3), value: lockManager.isLocked)
        .onAppear {
            syncCoordinator.onCardsChanged = { updatedCards in
                self.cards = updatedCards
            }
            loadCards()
            runInitialAnnualFeeCheckIfNeeded()
        }
        .onChange(of: lockManager.isLocked) { _, isLocked in
            if !isLocked {
                runInitialAnnualFeeCheckIfNeeded()
            }
        }
        // 请求存在后才创建完整表单，避免首次呈现产生空内容窗口
        .sheet(item: $cardEditRequest) { request in
            CardEditView(
                mode: request.mode,
                cardToEdit: request.card,
                initialCardCategory: request.card?.cardCategory ?? request.cardCategory,
                existingCards: cards,
                onSubmit: { finalCard in
                    let previousCard = request.mode == "edit"
                        ? (cards.first { $0.id == finalCard.id } ?? request.card)
                        : nil

                    if request.mode == "add" {
                        cards.append(finalCard)
                    } else {
                        if let index = cards.firstIndex(where: { $0.id == finalCard.id }) {
                            cards[index] = finalCard
                        }
                    }

                    _ = propagateBankRename(from: previousCard, to: finalCard)
                    
                    // 💡 联动同步：如果信用卡启用了共享额度，自动同步批量更新其他同银行的共享额度卡片
                    if finalCard.cardCategory != "debit", finalCard.isSharedLimit {
                        for i in 0..<cards.count {
                            if cards[i].id != finalCard.id &&
                                cards[i].cardCategory != "debit" &&
                                cards[i].country == finalCard.country &&
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
    
    // 所有卡片视图
    private var allCardsView: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                    Text("银行卡")
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
                    Text("全部 \(cards.count)").tag(CardCategoryFilter.all)
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
                    onEdit: { card in
                        cardEditRequest = CardEditRequest(mode: "edit", card: card)
                    },
                    onViewDetails: { card in
                        detailCard = card
                    },
                    onDelete: { card in
                        deleteCard(card)
                    },
                    onUpdateStatus: { card, newStatus in
                        updateCardStatus(card, status: newStatus)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // 临近年费提醒视图
    private var annualFeeAlertView: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("年费提醒卡片")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.orange)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            let alertCards = cards.filter { card in
                card.cardCategory != "debit" && DateCalculator.annualFeeDetection(for: card) != nil
            }
            
            if alertCards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green.opacity(0.6))
                    Text("目前没有任何需要处理的年费提醒。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CardGridView(
                    cards: alertCards,
                    groupBy: .none,
                    sortBy: sortBy,
                    onEdit: { card in
                        cardEditRequest = CardEditRequest(mode: "edit", card: card)
                    },
                    onViewDetails: { card in
                        detailCard = card
                    },
                    onDelete: { card in
                        deleteCard(card)
                    },
                    onUpdateStatus: { card, newStatus in
                        updateCardStatus(card, status: newStatus)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func loadCards() {
        let result = LocalStorageManager.read()
        switch result {
        case .success(let loadedCards):
            self.cards = syncCoordinator.bootstrap(localCards: loadedCards)
        case .failure(let error):
            print("读取本地数据失败，可能密码错误或数据损坏: \(error.localizedDescription)")
            self.cards = []
        }
    }
    
    private func runInitialAnnualFeeCheckIfNeeded() {
        guard !hasCheckedAnnualFeeStatus, !lockManager.isLocked else { return }
        hasCheckedAnnualFeeStatus = true
        checkAnnualFeeQualifiedStatus()
    }
    
    private func checkAnnualFeeQualifiedStatus() {
        let warningCards = cards.filter { card in
            guard card.cardCategory != "debit",
                  card.isQualified != "3",
                  card.isQualified != "2",
                  let diffDays = DateCalculator.annualFeeRemainingDays(card.nextAnnualFeeCollectionTime) else {
                return false
            }
            return diffDays <= 60 && diffDays >= 0
        }
        
        guard !warningCards.isEmpty else { return }
        
        let cardList = warningCards.prefix(8).map { card in
            let dateText = DateCalculator.formatTimestampDate(card.nextAnnualFeeCollectionTime)
            let daysText = DateCalculator.annualFeeRemainingDays(card.nextAnnualFeeCollectionTime) ?? 0
            return "• \(card.bank) - \(card.alias ?? "无别名")：\(dateText)，剩余 \(daysText) 天"
        }.joined(separator: "\n")
        let extraText = warningCards.count > 8 ? "\n另有 \(warningCards.count - 8) 张卡片也需要处理。" : ""
        
        let alert = NSAlert()
        alert.messageText = "年费达标状态检测"
        alert.informativeText = """
        检测到以下卡片临近年费收取时间不足 60 天。
        
        \(cardList)\(extraText)
        
        如果去年已达标但今年尚未完成达标，建议更新为未达标以避免遗漏年费。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "更新为未达标")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let warningIDs = Set(warningCards.map(\.id))
            let nowTimestamp = DateCalculator.timestamp(from: Date())
            for index in cards.indices where warningIDs.contains(cards[index].id) {
                cards[index].isQualified = "2"
                cards[index].lastModifyTime = nowTimestamp
            }
            cards = syncCoordinator.commit(cards: cards)
        }
    }
    
    private func deleteCard(_ card: SharedCard) {
        let alert = NSAlert()
        alert.messageText = "确认要删除此卡片吗？"
        alert.informativeText = "银行：\(card.bank)\n别名：\(card.alias ?? "无")\n卡号：\(card.cardNumber.suffix(4))\n\n删除后不可撤销，确认删除吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            cards.removeAll { $0.id == card.id }
            cards = syncCoordinator.commit(cards: cards, deletedCardIDs: [card.id])
        }
    }

    private func propagateBankRename(from previousCard: SharedCard?, to updatedCard: SharedCard) -> Int {
        guard BankNameNormalizer.shouldPropagateRename(from: previousCard?.bank, to: updatedCard.bank) else {
            return 0
        }

        let nowTimestamp = DateCalculator.timestamp(from: Date())
        var updatedCount = 0
        for index in cards.indices {
            guard cards[index].id != updatedCard.id,
                  BankNameNormalizer.namesReferToSameBank(cards[index].bank, previousCard?.bank),
                  BankNameNormalizer.display(cards[index].bank) != BankNameNormalizer.display(updatedCard.bank) else {
                continue
            }
            cards[index].bank = updatedCard.bank
            cards[index].lastModifyTime = nowTimestamp
            updatedCount += 1
        }
        return updatedCount
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
}
