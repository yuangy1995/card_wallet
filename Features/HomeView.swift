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
    @State private var syncFeedbackText: String?
    @State private var currentCardIndex = 0

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

    var filteredCards: [SharedCard] {
        let categoryCards: [SharedCard]
        switch categoryFilter {
        case .all:    categoryCards = syncCoordinator.cards
        case .credit: categoryCards = syncCoordinator.cards.filter { $0.cardCategory != "debit" }
        case .debit:  categoryCards = syncCoordinator.cards.filter { $0.cardCategory == "debit" }
        }
        let searched: [SharedCard]
        if searchText.isEmpty {
            searched = categoryCards
        } else {
            searched = categoryCards.filter { card in
                card.bank.localizedCaseInsensitiveContains(searchText) ||
                (card.alias ?? "").localizedCaseInsensitiveContains(searchText) ||
                card.cardNumber.contains(searchText) ||
                (card.level ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return sortCards(searched)
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

    private var creditCardCount: Int { syncCoordinator.cards.filter { $0.cardCategory != "debit" }.count }
    private var debitCardCount: Int { syncCoordinator.cards.filter { $0.cardCategory == "debit" }.count }

    private func count(for filter: CardCategoryFilter) -> Int {
        switch filter {
        case .all: return syncCoordinator.cards.count
        case .credit: return creditCardCount
        case .debit: return debitCardCount
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
            .navigationDestination(item: $selectedCard) { card in
                CardDetailView(card: card, onEdit: { cardToEdit = $0 }, onDelete: { deleteCard($0) })
            }
            .navigationDestination(isPresented: $showSyncHistory) {
                SyncHistoryView()
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
        .overlay(alignment: .bottomTrailing) {
            addFAB
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
            selectedCard = card
        } label: {
            CreditCardMiniView(card: card)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemGroupedBackground))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { cardToEdit = card } label: { Label("编辑", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) { deleteCard(card) } label: { Label("删除", systemImage: "trash") }
        }
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
                    } else {
                        showSyncFeedback("已开始同步")
                        Task { await syncCoordinator.synchronize(forceUpload: true) }
                    }
                } label: {
                    Group {
                        if syncCoordinator.isSynchronizing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.blue)
                        } else {
                            Image(systemName: syncCoordinator.syncStatus.iconName)
                                .font(.system(size: 16))
                                .foregroundStyle(syncStatusColor)
                                .symbolEffect(.pulse, isActive: syncCoordinator.syncStatus == .syncing)
                        }
                    }
                    .frame(width: 22, height: 22)
                }
                .accessibilityLabel(syncCoordinator.isSynchronizing ? "查看同步记录" : "立即同步")
                // 筛选排序
                Button { showFilterSheet = true } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16))
                }
            }
        }
    }

    private var syncStatusColor: Color {
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

    private func commitSubmittedCard(_ submittedCard: SharedCard, previousCard: SharedCard?) {
        var allCards = syncCoordinator.cards
        var finalCard = submittedCard
        let now = DataMigrationManager.currentTimestampMilliseconds()
        finalCard.lastModifyTime = now

        if let index = allCards.firstIndex(where: { $0.id == finalCard.id }) {
            allCards[index] = finalCard
        } else {
            allCards.append(finalCard)
        }

        if BankNameNormalizer.shouldPropagateRename(from: previousCard?.bank, to: finalCard.bank) {
            for index in allCards.indices where allCards[index].id != finalCard.id {
                guard BankNameNormalizer.namesReferToSameBank(allCards[index].bank, previousCard?.bank),
                      BankNameNormalizer.display(allCards[index].bank) != BankNameNormalizer.display(finalCard.bank) else {
                    continue
                }
                allCards[index].bank = finalCard.bank
                allCards[index].lastModifyTime = now
            }
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
