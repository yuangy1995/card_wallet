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
                            cardReminderView
                        case .statistics:
                            StatisticsView(cards: cards)
                        case .tools:
                            toolsView
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
    
    // 卡片提醒视图
    private var cardReminderView: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("卡片提醒")
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
                !DateCalculator.billingCycleReminders(for: card).isEmpty ||
                    DateCalculator.annualFeeDetection(for: card) != nil ||
                    cardExpiryReminderStatus(for: card) != nil
            }
            
            if alertCards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green.opacity(0.6))
                    Text("目前没有任何需要处理的卡片提醒。")
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

    private var toolsView: some View {
        let issues = DateCalculator.analyzeDataQuality(cards: cards)

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("工具")
                            .font(.title2)
                            .bold()
                        Text("数据异常检测")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("数据异常检测", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                        Spacer()
                        Text(issues.isEmpty ? "正常" : "\(issues.count) 项")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((issues.isEmpty ? Color.green : Color.orange).opacity(0.15))
                            .foregroundColor(issues.isEmpty ? .green : .orange)
                            .clipShape(Capsule())
                    }

                    if issues.isEmpty {
                        Text("未发现重复卡号、非法账单日/还款日、有效期格式异常或共享额度冲突。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(issues) { issue in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: dataIssueIcon(issue.severity))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(dataIssueColor(issue.severity))
                                        .frame(width: 22)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(issue.severity) · \(issue.title)")
                                            .font(.subheadline.bold())
                                            .foregroundColor(dataIssueColor(issue.severity))
                                        if !issue.cardName.isEmpty {
                                            Text(issue.cardName)
                                                .font(.caption.bold())
                                                .foregroundColor(.primary)
                                        }
                                        Text(issue.detail)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(dataIssueColor(issue.severity).opacity(0.09))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(dataIssueColor(issue.severity).opacity(0.18), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
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
        checkBillingCycleStatus()
        checkAnnualFeeQualifiedStatus()
        checkCardExpiryStatus()
    }

    private func checkBillingCycleStatus() {
        let reminders = DateCalculator.billingCycleReminderItems(for: cards)
        guard !reminders.isEmpty else { return }

        let cardList = reminders.prefix(10).map { item in
            let label = item.reminder.kind == .repayment ? "还款日" : "账单日"
            let note = item.reminder.kind == .repayment ? "请核对是否已还款" : "请关注本期出账"
            return "• \(item.card.bank) - \(item.card.alias ?? "无别名")：\(item.reminder.title)，\(label) \(DateCalculator.formatDate(item.reminder.date))，\(note)"
        }.joined(separator: "\n")
        let extraText = reminders.count > 10 ? "\n另有 \(reminders.count - 10) 项提醒也需要处理。" : ""

        let alert = NSAlert()
        alert.messageText = "还款日/账单日检测"
        alert.informativeText = """
        检测到以下信用卡即将到达还款日或账单日。

        \(cardList)\(extraText)
        """
        alert.alertStyle = reminders.contains { $0.reminder.kind == .repayment } ? .critical : .warning
        alert.addButton(withTitle: "查看卡片提醒")
        alert.addButton(withTitle: "知道了")

        if alert.runModal() == .alertFirstButtonReturn {
            selection = .annualFeeAlert
        }
    }

    private func refreshSystemNotifications(for cards: [SharedCard]) {
        guard !lockManager.isLocked else { return }
        Task {
            await CardSystemNotificationCenter.shared.refresh(cards: cards, locked: lockManager.isLocked)
        }
    }

    private func dataIssueColor(_ severity: String) -> Color {
        switch severity {
        case "严重":
            return .red
        case "警告":
            return .orange
        default:
            return .cyan
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

    private func cardExpiryReminderStatus(for card: SharedCard) -> DateCalculator.CardExpiryStatus? {
        guard let status = DateCalculator.cardExpiryStatus(valid: card.valid),
              status == .expired || status == .soonExpiring else {
            return nil
        }
        return status
    }

    private func checkCardExpiryStatus() {
        let expiryCards = cards.compactMap { card -> (card: SharedCard, status: DateCalculator.CardExpiryStatus)? in
            guard let status = cardExpiryReminderStatus(for: card) else { return nil }
            return (card, status)
        }.sorted { lhs, rhs in
            let lhsPriority = lhs.status == .expired ? 0 : 1
            let rhsPriority = rhs.status == .expired ? 0 : 1
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return lhs.card.bank < rhs.card.bank
        }

        guard !expiryCards.isEmpty else { return }

        let cardList = expiryCards.prefix(8).map { item in
            let statusText = item.status == .expired ? "已过期" : "6个月内到期"
            return "• \(item.card.bank) - \(item.card.alias ?? "无别名")：\(item.card.valid ?? "--/--")，\(statusText)"
        }.joined(separator: "\n")
        let extraText = expiryCards.count > 8 ? "\n另有 \(expiryCards.count - 8) 张卡片也需要处理。" : ""

        let alert = NSAlert()
        alert.messageText = "卡片有效期检测"
        alert.informativeText = """
        检测到以下卡片已过期或将在 6 个月内到期。

        \(cardList)\(extraText)

        请确认银行是否已换发新卡，并在卡片详情里更新有效期。
        """
        alert.alertStyle = expiryCards.contains { $0.status == .expired } ? .critical : .warning
        alert.addButton(withTitle: "查看统计")
        alert.addButton(withTitle: "知道了")

        if alert.runModal() == .alertFirstButtonReturn {
            selection = .statistics
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

@MainActor
private final class CardSystemNotificationCenter {
    static let shared = CardSystemNotificationCenter()

    private let center = UNUserNotificationCenter.current()
    private let defaultsKey = "card_system_notification_daily_v1"

    private init() {}

    func refresh(cards: [SharedCard], locked: Bool) async {
        guard !locked, !cards.isEmpty else { return }

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
        guard await requestAuthorizationIfNeeded() else { return }

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
