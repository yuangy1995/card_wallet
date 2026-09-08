import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @State private var searchText = ""
    @State private var categoryFilter: CardCategoryFilter = .all
    @State private var groupBy: GroupOption = .bank
    @State private var sortBy: SortOption = .limitDesc
    @State private var showingAddMenu = false
    @State private var cardToEdit: SharedCard?
    @State private var isAddingNewCard = false
    @State private var newCardCategory = "credit"
    @State private var selectedCard: SharedCard?
    @State private var showFilterSheet = false
    @State private var showSyncHistory = false
    @State private var showCloudSync = false
    @State private var syncFeedbackText: String?
    @State private var currentCardIndex = 0
    @State private var showReminderPage = false
    @State private var isSelectionMode = false
    @State private var selectedCardIDs: Set<String> = []
    @State private var showBatchEditor = false
    @State private var showBatchDeleteConfirmation = false

    enum CardCategoryFilter: String, CaseIterable {
        case all = "全部"
        case credit = "信用卡"
        case debit = "储蓄卡"
        var icon: String {
            switch self {
            case .all: return "creditcard.and.123"
            case .credit: return "creditcard.fill"
            case .debit: return "banknote.fill"
            }
        }
    }

    var searchFilteredCards: [SharedCard] {
        if searchText.isEmpty {
            return syncCoordinator.cards
        } else {
            return syncCoordinator.cards.filter { card in
                card.bank.localizedCaseInsensitiveContains(searchText) ||
                (card.alias ?? "").localizedCaseInsensitiveContains(searchText) ||
                card.cardNumber.contains(searchText) ||
                (card.level ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var filteredCards: [SharedCard] {
        let categoryCards: [SharedCard]
        switch categoryFilter {
        case .all:    categoryCards = searchFilteredCards
        case .credit: categoryCards = searchFilteredCards.filter { $0.cardCategory != "debit" }
        case .debit:  categoryCards = searchFilteredCards.filter { $0.cardCategory == "debit" }
        }
        return sortCards(categoryCards)
    }

    var groupedCards: [(key: String, cards: [SharedCard])] {
        if groupBy == .none { return [("全部", filteredCards)] }
        var groups: [String: [SharedCard]] = [:]
        for card in filteredCards {
            let key: String
            switch groupBy {
            case .none:    key = "全部"
            case .bank:    key = card.bank.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            case .brand:   key = CardBrand.detect(from: card.cardNumber, level: card.level).displayName
            case .level:   key = card.level ?? "未知级别"
            case .country: key = card.country
            }
            groups[key, default: []].append(card)
        }
        return groups.sorted { $0.key < $1.key }.map { (key: $0.key, cards: $0.value) }
    }


    private var annualReminderItems: [(card: SharedCard, result: DateCalculator.AnnualFeeDetectionResult)] {
        syncCoordinator.cards.compactMap { card in
            guard let result = DateCalculator.annualFeeDetection(for: card) else { return nil }
            return (card, result)
        }.sorted { lhs, rhs in
            if lhs.result.sortPriority != rhs.result.sortPriority {
                return lhs.result.sortPriority < rhs.result.sortPriority
            }
            if lhs.result.days != rhs.result.days {
                return lhs.result.days < rhs.result.days
            }
            return lhs.card.bank < rhs.card.bank
        }
    }
    private var expiryReminderCards: [SharedCard] {
        syncCoordinator.cards.filter { card in
            guard let status = DateCalculator.cardExpiryStatus(valid: card.valid) else { return false }
            return status == .expired || status == .soonExpiring
        }.sorted { $0.bank < $1.bank }
    }
    private var billingReminderItems: [(card: SharedCard, reminder: DateCalculator.BillingCycleReminderResult)] {
        DateCalculator.billingCycleReminderItems(for: syncCoordinator.cards)
    }
    private var reminderCount: Int {
        billingReminderItems.count + annualReminderItems.count + expiryReminderCards.count
    }

    private func count(for filter: CardCategoryFilter) -> Int {
        switch filter {
        case .all: return searchFilteredCards.count
        case .credit: return searchFilteredCards.filter { $0.cardCategory != "debit" }.count
        case .debit: return searchFilteredCards.filter { $0.cardCategory == "debit" }.count
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                backgroundView

                if syncCoordinator.cards.isEmpty {
                    emptyStateView
                } else {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .overlay(alignment: .top) {
                syncFeedbackBanner
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索银行、卡号、别名…")
            .navigationDestination(isPresented: $isAddingNewCard) {
                CardEditView(
                    mode: "add",
                    initialCardCategory: newCardCategory,
                    existingCards: syncCoordinator.cards
                ) { newCard in
                    commitSubmittedCard(newCard, previousCard: nil)
                }
            }
            .navigationDestination(item: $cardToEdit) { card in
                CardEditView(
                    mode: "edit",
                    cardToEdit: card,
                    initialCardCategory: card.cardCategory,
                    existingCards: syncCoordinator.cards
                ) { updatedCard in
                    commitSubmittedCard(updatedCard, previousCard: card)
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSortSheet(groupBy: $groupBy, sortBy: $sortBy)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showBatchEditor) {
                IOSBatchEditView(selectedCount: selectedCardIDs.count) { request in
                    applyBatchUpdate(request)
                    exitSelectionMode()
                }
            }
            .alert("批量删除确认", isPresented: $showBatchDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除 \(selectedCardIDs.count) 张卡片", role: .destructive) {
                    deleteSelectedCards()
                    exitSelectionMode()
                }
            } message: {
                Text("删除后会通过同步账本传播到其他设备，此操作无法撤销。")
            }
            .navigationDestination(isPresented: $showReminderPage) {
                CardReminderPage(
                    cards: syncCoordinator.cards,
                    onEditCard: { cardToEdit = $0 },
                    onDeleteCard: { deleteCard($0) },
                    onConfirmAnnualFeeQualified: { updateAnnualFeeStatus($0, status: "1") }
                )
            }
            .navigationDestination(item: $selectedCard) { card in
                CardDetailView(card: card, onEdit: { cardToEdit = $0 }, onDelete: { deleteCard($0) })
            }
            .navigationDestination(isPresented: $showSyncHistory) {
                SyncHistoryView()
            }
            .navigationDestination(isPresented: $showCloudSync) {
                CloudSyncView()
            }
            .onAppear {
                syncCoordinator.refreshWebDAVConfigurationState()
            }
            .onChange(of: showCloudSync) { _, isShowing in
                if !isShowing {
                    syncCoordinator.refreshWebDAVConfigurationState()
                }
            }
        }
    }

    // MARK: - 背景
    private var backgroundView: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            // 彩色光晕背景点缀
            GeometryReader { geo in
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 80)
                    .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.1)
                Circle()
                    .fill(Color.purple.opacity(0.07))
                    .frame(width: geo.size.width * 0.6)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.4)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - 主内容
    private var mainContent: some View {
        VStack(spacing: 0) {
            // 分类筛选 Tab
            categoryFilterBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))

            ScrollView {
                LazyVStack(spacing: 0) {
                    if reminderCount > 0 {
                        reminderBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 10)
                    }

                    // 卡片列表（分组）
                    ForEach(groupedCards, id: \.key) { group in
                        Section {
                            ForEach(group.cards) { card in
                                cardRow(card)
                            }
                        } header: {
                            if groupBy != .none {
                                groupHeader(group.key, count: group.cards.count)
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelectionMode {
                batchSelectionBar
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !isSelectionMode {
                addFAB
            }
        }
    }

    // MARK: - 分类 Tab
    private var categoryFilterBar: some View {
        HStack(spacing: 0) {
            ForEach(CardCategoryFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(duration: 0.3)) { categoryFilter = filter }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(filter.rawValue)(\(count(for: filter)))")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(categoryFilter == filter ? .white : .secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background {
                        if categoryFilter == filter {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var reminderBanner: some View {
        Button {
            showReminderPage = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("发现 \(reminderCount) 项卡片提醒")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Text("还款/账单 \(billingReminderItems.count) 项 / 年费 \(annualReminderItems.count) 项 / 有效期 \(expiryReminderCards.count) 项")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分组标头
    private func groupHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Text("\(count)张")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color(.systemGroupedBackground).opacity(0.9))
    }

    // MARK: - 卡片行
    private func cardRow(_ card: SharedCard) -> some View {
        Button {
            if isSelectionMode {
                toggleSelection(card)
            } else {
                selectedCard = card
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                CreditCardMiniView(card: card)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemGroupedBackground))

                if isSelectionMode {
                    Image(systemName: selectedCardIDs.contains(card.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(selectedCardIDs.contains(card.id) ? Color.accentColor : Color.secondary)
                        .background(.regularMaterial, in: Circle())
                        .padding(.top, 14)
                        .padding(.trailing, 26)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isSelectionMode {
                Button { cardToEdit = card } label: { Label("编辑", systemImage: "pencil") }
                if card.cardCategory != "debit" {
                    Button { updateAnnualFeeStatus(card, status: "1") } label: {
                        Label("确认本周期年费已达标", systemImage: "checkmark.seal.fill")
                    }
                    Button { updateAnnualFeeStatus(card, status: "2") } label: {
                        Label("标记年费未达标", systemImage: "exclamationmark.triangle.fill")
                    }
                }
                Divider()
                Button(role: .destructive) { deleteCard(card) } label: { Label("删除", systemImage: "trash") }
            }
        }
    }

    private var batchSelectionBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("已选择 \(selectedCardIDs.count) 张")
                    .font(.system(size: 14, weight: .semibold))
                Button(allVisibleCardsSelected ? "取消全选" : "全选当前结果") {
                    if allVisibleCardsSelected {
                        selectedCardIDs.subtract(filteredCards.map(\.id))
                    } else {
                        selectedCardIDs.formUnion(filteredCards.map(\.id))
                    }
                }
                .font(.system(size: 12, weight: .medium))
            }
            Spacer()
            Button {
                showBatchEditor = true
            } label: {
                Label("修改", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCardIDs.isEmpty)

            Button(role: .destructive) {
                showBatchDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(selectedCardIDs.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private var allVisibleCardsSelected: Bool {
        !filteredCards.isEmpty && Set(filteredCards.map(\.id)).isSubset(of: selectedCardIDs)
    }

    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue.opacity(0.7), .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            VStack(spacing: 8) {
                Text("还没有银行卡")
                    .font(.system(.title3, weight: .semibold))
                Text("点击右下角按钮添加第一张卡片")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                newCardCategory = "credit"
                isAddingNewCard = true
            } label: {
                Label("添加信用卡", systemImage: "plus.circle.fill")
                    .font(.system(.callout, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [.blue.opacity(0.7), .blue], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
        }
        .padding()
    }

    // MARK: - FAB 按钮
    private var addFAB: some View {
        Menu {
            Button { newCardCategory = "credit"; isAddingNewCard = true } label: { Label("新增信用卡", systemImage: "creditcard.fill") }
            Button { newCardCategory = "debit"; isAddingNewCard = true } label: { Label("新增储蓄卡", systemImage: "banknote.fill") }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Color.blue.opacity(0.7), Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.blue.opacity(0.5), radius: 12, x: 0, y: 6)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 6) {
                Image(systemName: "wallet.bifold.fill")
                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.7), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("卡包")
                    .font(.system(.headline, weight: .bold))
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                // 同步状态指示器
                Button {
                    if syncCoordinator.isSynchronizing {
                        showSyncHistory = true
                    } else if !syncCoordinator.refreshWebDAVConfigurationState() {
                        showCloudSync = true
                    } else {
                        syncCoordinator.requestManualSync()
                    }
                } label: {
                    Group {
                        if syncCoordinator.isSynchronizing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.blue)
                        } else {
                            Image(systemName: syncIconName)
                                .font(.system(size: 16))
                                .foregroundStyle(syncStatusColor)
                                .symbolEffect(.pulse, isActive: syncCoordinator.webDAVConfigReady && syncCoordinator.syncStatus == .syncing)
                        }
                    }
                    .frame(width: 22, height: 22)
                }
                .accessibilityLabel(syncAccessibilityLabel)
                // 筛选排序
                Button { showFilterSheet = true } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16))
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isSelectionMode {
                            exitSelectionMode()
                        } else {
                            isSelectionMode = true
                        }
                    }
                } label: {
                    Image(systemName: isSelectionMode ? "xmark.circle.fill" : "checklist")
                        .font(.system(size: 16))
                }
                .accessibilityLabel(isSelectionMode ? "退出批量操作" : "进入批量操作")
            }
        }
    }

    private var syncIconName: String {
        syncCoordinator.webDAVConfigReady ? syncCoordinator.syncStatus.iconName : "icloud.slash"
    }

    private var syncAccessibilityLabel: String {
        if syncCoordinator.isSynchronizing { return "查看同步记录" }
        return syncCoordinator.webDAVConfigReady ? "立即同步" : "配置云端同步"
    }

    private var syncStatusColor: Color {
        if !syncCoordinator.webDAVConfigReady {
            return .secondary
        }
        switch syncCoordinator.syncStatus {
        case .idle:    return .secondary
        case .syncing: return .blue
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        }
    }

    private var syncFeedbackBanner: some View {
        Group {
            if let syncFeedbackText {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(syncFeedbackText)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.blue.gradient, in: Capsule())
                .shadow(color: Color.blue.opacity(0.25), radius: 10, x: 0, y: 5)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func showSyncFeedback(_ text: String) {
        withAnimation(.spring(duration: 0.25)) {
            syncFeedbackText = text
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                guard syncFeedbackText == text else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    syncFeedbackText = nil
                }
            }
        }
    }

    // MARK: - Helpers
    private func sortCards(_ cards: [SharedCard]) -> [SharedCard] {
        switch sortBy {
        case .limitDesc: return cards.sorted { ($0.limit ?? 0) > ($1.limit ?? 0) }
        case .limitAsc:  return cards.sorted { ($0.limit ?? 0) < ($1.limit ?? 0) }
        case .daysDesc:
            return cards.sorted {
                let d0 = DateCalculator.calculateInterestFreePeriod(
                    accountBillDate: $0.accountBillDate ?? "", dueDate: $0.dueDate ?? "",
                    billingDayToNextBill: $0.billingDaySpendingToNextBill)
                let d1 = DateCalculator.calculateInterestFreePeriod(
                    accountBillDate: $1.accountBillDate ?? "", dueDate: $1.dueDate ?? "",
                    billingDayToNextBill: $1.billingDaySpendingToNextBill)
                return d0 > d1
            }
        case .daysAsc:
            return cards.sorted {
                let d0 = DateCalculator.calculateInterestFreePeriod(
                    accountBillDate: $0.accountBillDate ?? "", dueDate: $0.dueDate ?? "",
                    billingDayToNextBill: $0.billingDaySpendingToNextBill)
                let d1 = DateCalculator.calculateInterestFreePeriod(
                    accountBillDate: $1.accountBillDate ?? "", dueDate: $1.dueDate ?? "",
                    billingDayToNextBill: $1.billingDaySpendingToNextBill)
                return d0 < d1
            }
        case .lastModify:
            return cards.sorted { $0.lastModifyTime > $1.lastModifyTime }
        }
    }

    private func deleteCard(_ card: SharedCard) {
        let remaining = syncCoordinator.cards.filter { $0.id != card.id }
        syncCoordinator.commit(cards: remaining, deletedCardIDs: [card.id])
    }

    private func toggleSelection(_ card: SharedCard) {
        if selectedCardIDs.contains(card.id) {
            selectedCardIDs.remove(card.id)
        } else {
            selectedCardIDs.insert(card.id)
        }
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedCardIDs.removeAll()
    }

    private func applyBatchUpdate(_ request: IOSBatchUpdateRequest) {
        guard !selectedCardIDs.isEmpty else { return }
        var allCards = syncCoordinator.cards
        let now = DataMigrationManager.currentTimestampMilliseconds()

        for index in allCards.indices where selectedCardIDs.contains(allCards[index].id) {
            if let category = request.cardCategory {
                allCards[index].cardCategory = category == "debit" ? "debit" : "credit"
            }
            if allCards[index].cardCategory != "debit" {
                if let status = request.status {
                    allCards[index].isQualified = status
                    if status == "3" {
                        allCards[index].nextAnnualFeeCollectionTime = nil
                    }
                }
                if let annualFee = request.annualFee {
                    allCards[index].annualFee = annualFee
                }
                if let nextDate = request.nextAnnualFeeDate, request.status != "3" {
                    allCards[index].nextAnnualFeeCollectionTime = nextDate
                }
            }
            if let valid = request.valid {
                allCards[index].valid = valid
            }
            allCards[index].lastModifyTime = now
        }
        syncCoordinator.commit(cards: allCards)
    }

    private func deleteSelectedCards() {
        guard !selectedCardIDs.isEmpty else { return }
        let remaining = syncCoordinator.cards.filter { !selectedCardIDs.contains($0.id) }
        syncCoordinator.commit(cards: remaining, deletedCardIDs: selectedCardIDs)
    }

    private func updateAnnualFeeStatus(_ card: SharedCard, status: String) {
        guard card.cardCategory != "debit" else { return }
        var allCards = syncCoordinator.cards
        guard let index = allCards.firstIndex(where: { $0.id == card.id }) else { return }
        allCards[index].isQualified = status
        if status == "1" {
            allCards[index].nextAnnualFeeCollectionTime = DateCalculator.timestampByAddingOneYear(allCards[index].nextAnnualFeeCollectionTime)
        } else if status == "3" {
            allCards[index].nextAnnualFeeCollectionTime = nil
        }
        allCards[index].lastModifyTime = DataMigrationManager.currentTimestampMilliseconds()
        syncCoordinator.commit(cards: allCards)
    }

    private func commitSubmittedCard(_ submittedCard: SharedCard, previousCard: SharedCard?) {
        var allCards = syncCoordinator.cards
        var finalCard = submittedCard

        // 编辑时首次切换为已达标，需要同时完成当前周期并顺延年费日期。
        if let previousCard, previousCard.isQualified != "1", finalCard.isQualified == "1" {
            finalCard.nextAnnualFeeCollectionTime = DateCalculator.timestampByAddingOneYear(
                finalCard.nextAnnualFeeCollectionTime
            )
        }

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

        syncCoordinator.commit(cards: allCards)
    }
}

private struct IOSBatchUpdateRequest {
    var status: String?
    var annualFee: Double?
    var nextAnnualFeeDate: Double?
    var valid: String?
    var cardCategory: String?
}

private struct IOSBatchEditView: View {
    let selectedCount: Int
    let onApply: (IOSBatchUpdateRequest) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var updateCategory = false
    @State private var category = "credit"
    @State private var updateStatus = false
    @State private var status = "1"
    @State private var updateAnnualFee = false
    @State private var annualFee = 0.0
    @State private var updateAnnualDate = false
    @State private var annualDate = Date()
    @State private var updateValid = false
    @State private var validDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("仅开启的字段会被更新，其他信息保持原值。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("卡片类别") {
                    Toggle("更新卡类别", isOn: $updateCategory)
                    if updateCategory {
                        Picker("卡类别", selection: $category) {
                            Text("信用卡").tag("credit")
                            Text("储蓄卡").tag("debit")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("年费信息") {
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
                            .keyboardType(.decimalPad)
                    }

                    Toggle("更新下次年费日期", isOn: $updateAnnualDate)
                        .disabled(updateStatus && status == "3")
                    if updateAnnualDate && !(updateStatus && status == "3") {
                        DatePicker("下次年费日期", selection: $annualDate, displayedComponents: .date)
                    }
                }

                Section("有效期") {
                    Toggle("更新有效期", isOn: $updateValid)
                    if updateValid {
                        DatePicker("有效期月份", selection: $validDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("批量修改 \(selectedCount) 张")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        onApply(
                            IOSBatchUpdateRequest(
                                status: updateStatus ? status : nil,
                                annualFee: updateAnnualFee ? annualFee : nil,
                                nextAnnualFeeDate: updateAnnualDate && status != "3" ? annualDate.timeIntervalSince1970 * 1000 : nil,
                                valid: updateValid ? validText : nil,
                                cardCategory: updateCategory ? category : nil
                            )
                        )
                        dismiss()
                    }
                    .disabled(!hasChanges)
                }
            }
        }
    }

    private var hasChanges: Bool {
        updateCategory || updateStatus || updateAnnualFee || updateAnnualDate || updateValid
    }

    private var validText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yy"
        return formatter.string(from: validDate)
    }
}

// MARK: - 筛选排序 Sheet
struct FilterSortSheet: View {
    @Binding var groupBy: GroupOption
    @Binding var sortBy: SortOption
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("分组方式") {
                    ForEach(GroupOption.allCases) { option in
                        Button {
                            withAnimation { groupBy = option }
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if groupBy == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.system(.body, weight: .semibold))
                                }
                            }
                        }
                    }
                }
                Section("排序方式") {
                    ForEach(SortOption.allCases) { option in
                        Button {
                            withAnimation { sortBy = option }
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if sortBy == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.system(.body, weight: .semibold))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("筛选与排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct AnnualReminderItem: Identifiable {
    let card: SharedCard
    let result: DateCalculator.AnnualFeeDetectionResult
    var id: String { "annual-\(card.id)" }
}

private struct ExpiryReminderItem: Identifiable {
    let card: SharedCard
    let status: DateCalculator.CardExpiryStatus
    var id: String { "expiry-\(card.id)" }
}

private struct BillingReminderItem: Identifiable {
    let card: SharedCard
    let reminder: DateCalculator.BillingCycleReminderResult
    var id: String { "billing-\(reminder.kind)-\(card.id)" }
}

private struct CardReminderPage: View {
    let cards: [SharedCard]
    let onEditCard: (SharedCard) -> Void
    let onDeleteCard: (SharedCard) -> Void
    let onConfirmAnnualFeeQualified: (SharedCard) -> Void

    private var annualItems: [AnnualReminderItem] {
        cards.compactMap { card in
            guard let result = DateCalculator.annualFeeDetection(for: card) else { return nil }
            return AnnualReminderItem(card: card, result: result)
        }.sorted {
            if $0.result.sortPriority != $1.result.sortPriority {
                return $0.result.sortPriority < $1.result.sortPriority
            }
            if $0.result.days != $1.result.days {
                return $0.result.days < $1.result.days
            }
            return $0.card.bank < $1.card.bank
        }
    }

    private var expiryItems: [ExpiryReminderItem] {
        cards.compactMap { card in
            guard let status = DateCalculator.cardExpiryStatus(valid: card.valid),
                  status == .expired || status == .soonExpiring else {
                return nil
            }
            return ExpiryReminderItem(card: card, status: status)
        }.sorted {
            if $0.status.sortPriority != $1.status.sortPriority {
                return $0.status.sortPriority < $1.status.sortPriority
            }
            return $0.card.bank < $1.card.bank
        }
    }

    private var billingItems: [BillingReminderItem] {
        DateCalculator.billingCycleReminderItems(for: cards).map {
            BillingReminderItem(card: $0.card, reminder: $0.reminder)
        }
    }

    var body: some View {
        List {
            if billingItems.isEmpty && annualItems.isEmpty && expiryItems.isEmpty {
                ContentUnavailableView("暂无卡片提醒", systemImage: "checkmark.shield.fill")
            }

            if !billingItems.isEmpty {
                Section("还款与账单提醒") {
                    ForEach(billingItems) { item in
                        NavigationLink {
                            cardDetail(for: item.card)
                        } label: {
                            ReminderRow(
                                icon: item.reminder.iconName,
                                color: item.reminder.tintColor,
                                title: item.card.bank,
                                subtitle: item.card.alias ?? "未命名卡片",
                                trailing: item.reminder.displayText
                            )
                        }
                    }
                }
            }

            if !annualItems.isEmpty {
                Section("年费提醒") {
                    ForEach(annualItems) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            NavigationLink {
                                cardDetail(for: item.card)
                            } label: {
                                ReminderRow(
                                    icon: item.result.iconName,
                                    color: item.result.tintColor,
                                    title: item.card.bank,
                                    subtitle: item.card.alias ?? "未命名卡片",
                                    trailing: item.result.displayText
                                )
                            }
                            Button {
                                onConfirmAnnualFeeQualified(item.card)
                            } label: {
                                Label("确认本周期已达标", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(item.result.tintColor)
                        }
                    }
                }
            }

            if !expiryItems.isEmpty {
                Section("有效期提醒") {
                    ForEach(expiryItems) { item in
                        NavigationLink {
                            cardDetail(for: item.card)
                        } label: {
                            ReminderRow(
                                icon: item.status.iconName,
                                color: item.status.tintColor,
                                title: item.card.bank,
                                subtitle: item.card.valid ?? "--/--",
                                trailing: item.status.displayText
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("卡片提醒")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
    }

    private func cardDetail(for card: SharedCard) -> some View {
        CardDetailView(
            card: card,
            onEdit: onEditCard,
            onDelete: onDeleteCard
        )
    }
}

private struct ReminderRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let trailing: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(trailing)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

private extension DateCalculator.BillingCycleReminderResult {
    var tintColor: Color {
        switch kind {
        case .repayment: return .red
        case .bill: return .orange
        }
    }

    var iconName: String {
        switch kind {
        case .repayment: return "calendar.badge.exclamationmark"
        case .bill: return "calendar.badge.clock"
        }
    }

    var displayText: String {
        switch kind {
        case .repayment: return days == 0 ? "今日还款" : "\(days) 天后还款"
        case .bill: return days == 0 ? "今日账单" : "\(days) 天后账单"
        }
    }
}

private extension DateCalculator.AnnualFeeDetectionResult {
    var sortPriority: Int {
        switch kind {
        case .overdue: return 0
        case .unqualified: return 1
        case .warning: return 2
        }
    }

    var tintColor: Color {
        switch kind {
        case .overdue: return .red
        case .unqualified: return .orange
        case .warning: return .yellow
        }
    }

    var iconName: String {
        switch kind {
        case .overdue: return "xmark.circle.fill"
        case .unqualified: return "exclamationmark.circle.fill"
        case .warning: return "clock.badge.exclamationmark.fill"
        }
    }

    var displayText: String {
        switch kind {
        case .overdue: return "已过 \(days) 天"
        case .unqualified: return "未达标 · \(days) 天"
        case .warning: return "待确认 · \(days) 天"
        }
    }
}

private extension DateCalculator.CardExpiryStatus {
    var sortPriority: Int {
        switch self {
        case .expired: return 0
        case .soonExpiring: return 1
        case .normal: return 2
        }
    }

    var tintColor: Color {
        switch self {
        case .expired: return .red
        case .soonExpiring: return .orange
        case .normal: return .green
        }
    }

    var iconName: String {
        switch self {
        case .expired: return "calendar.badge.exclamationmark"
        case .soonExpiring: return "calendar.badge.clock"
        case .normal: return "checkmark.circle.fill"
        }
    }

    var displayText: String {
        switch self {
        case .expired: return "已过期"
        case .soonExpiring: return "6个月内"
        case .normal: return "正常"
        }
    }
}
