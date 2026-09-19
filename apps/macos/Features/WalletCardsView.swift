import SwiftUI

struct AllCardsView: View {
    let cards: [SharedCard]
    @Binding var searchText: String
    @Binding var selectedCardID: String?
    @Binding var selectedBank: String
    let searchFocusRequest: Int
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

    @EnvironmentObject private var appearance: WalletAppearance
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletAnimation) private var animation
    @AppStorage("wallet_favorite_card_ids_v1") private var favoriteStorage = ""
    @AppStorage("wallet_only_favorites_v1") private var onlyFavorites = false
    private var favoriteIDs: Set<String> { LocalCardPreferences.favoriteIDs(favoriteStorage) }
    @AppStorage("wallet_card_layout") private var layout = "list"
    @State private var preparedCards: [CardCatalogItem] = []
    @State private var groups: [CardCatalogGroup] = []
    @State private var catalogTask: Task<Void, Never>?
    @State private var needsPreparation = true
    @State private var isPreparingCatalog = true
    @State private var collapsedGroups: Set<String> = []
    @State private var selectedCardIDs: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showingBatchEditor = false
    @State private var showingBatchDeleteConfirmation = false
    @FocusState private var searchFocused: Bool
    @FocusState private var focusedCard: String?

    private var query: CardCatalogQuery {
        CardCatalogQuery(search: searchText, bank: selectedBank, category: cardCategoryFilter, group: groupBy, sort: sortBy)
    }
    private var visibleItems: [CardCatalogItem] { groups.flatMap(\.items) }
    private var selectedCard: SharedCard? { cards.first { $0.id == selectedCardID } }
    private var reminderCount: Int { preparedCards.filter(\.needsAnnualReview).count }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchBar
                filters
                if isSelectionMode { batchBar }
                if groups.isEmpty && isPreparingCatalog && !cards.isEmpty {
                    ProgressView("正在整理卡片…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if groups.isEmpty {
                    ContentUnavailableView {
                        Label(cards.isEmpty ? "还没有卡片" : "没有找到卡片", systemImage: "creditcard")
                    } description: {
                        Text(cards.isEmpty ? "添加第一张卡片，开始整理你的卡包。" : "试试其他银行名称或卡号后四位。")
                    } actions: {
                        if cards.isEmpty {
                            Button("添加卡片", action: addCard).buttonStyle(.borderedProminent)
                        } else {
                            Button("清除筛选") { searchText = ""; selectedBank = ""; cardCategoryFilter = .all; onlyFavorites = false }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    catalog
                }
                HStack {
                    Text("\(visibleItems.count) 张卡片").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation(animation) {
                            isSelectionMode.toggle()
                            if !isSelectionMode { selectedCardIDs.removeAll() }
                        }
                    } label: { Label(isSelectionMode ? "完成选择" : "批量操作", systemImage: "checklist") }
                    .buttonStyle(.borderless).font(.caption)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if let card = selectedCard {
                Divider().overlay(palette.line)
                WalletCardInspector(
                    card: card,
                    onEdit: { edit(card) },
                    onViewDetails: { detailCard = card },
                    onUpdateStatus: { onUpdateStatus(card, $0) }
                )
                .frame(width: 282)
                .background(WalletBackground(palette: palette))
            }
        }
        .onAppear(perform: prepare)
        .onChange(of: cards) { _, _ in prepare() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in prepare() }
        .onChange(of: query) { _, _ in refreshGroups() }
        .onChange(of: favoriteStorage) { _, _ in refreshGroups() }
        .onChange(of: onlyFavorites) { _, _ in refreshGroups() }
        .onDisappear { catalogTask?.cancel() }
        .task(id: searchFocusRequest) { if searchFocusRequest > 0 { searchFocused = true } }
        .sheet(isPresented: $showingBatchEditor) {
            MacBatchEditView(selectedCount: selectedCardIDs.count) { request in
                onBatchUpdate(selectedCardIDs, request)
                selectedCardIDs.removeAll()
                isSelectionMode = false
            }
            .modifier(WalletThemeModifier())
        }
        .alert("删除所选卡片？", isPresented: $showingBatchDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除 \(selectedCardIDs.count) 张卡片", role: .destructive) {
                onBatchDelete(selectedCardIDs)
                selectedCardIDs.removeAll()
                isSelectionMode = false
            }
        } message: {
            Text("卡片及关联提醒将被删除；同步后，其他设备也会删除这些卡片。此操作无法撤销。")
        }
    }

    private var header: some View {
        WalletPageHeader(title: "我的卡包", subtitle: String(localized: "\(cards.count) 张卡片 · \(Set(cards.map { BankNameNormalizer.normalizedKey($0.bank) }).count) 家银行")) {
            Button(action: addCard) { Label("添加卡片", systemImage: "plus") }
                .buttonStyle(.borderedProminent).controlSize(.regular)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索银行、卡名或尾号", text: $searchText)
                .textFieldStyle(.plain).focused($searchFocused)
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("清除搜索")
            }
            Text("⌘ F").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(palette.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.line, lineWidth: 1))
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                WalletChoiceBar(title: "卡片类别", selection: $cardCategoryFilter,
                    choices: CardCategoryFilter.allCases.map { WalletChoice(value: $0, title: LocalizedStringKey($0.rawValue)) })
                Spacer(minLength: 0)
                WalletChoiceBar(title: "排列方式", selection: $layout, choices: [
                    WalletChoice(value: "list", title: "列表视图", icon: "list.bullet"),
                    WalletChoice(value: "grid", title: "卡片视图", icon: "square.grid.2x2")
                ], iconOnly: true)
                Button { onlyFavorites.toggle() } label: {
                    Image(systemName: onlyFavorites ? "star.fill" : "star")
                        .foregroundStyle(onlyFavorites ? palette.accent : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(onlyFavorites ? "显示全部卡片" : "只看收藏")
                .accessibilityLabel(onlyFavorites ? "显示全部卡片" : "只看收藏")
                Menu {
                    Picker("分组", selection: $groupBy) {
                        ForEach(GroupOption.allCases) { option in Label(LocalizedStringKey(option.rawValue), systemImage: option.icon).tag(option) }
                    }
                    Picker("排序", selection: $sortBy) {
                        ForEach(SortOption.allCases) { option in Label(LocalizedStringKey(option.rawValue), systemImage: option.icon).tag(option) }
                    }
                    if groupBy != .none {
                        Divider()
                        Button("展开所有分组") { collapsedGroups.removeAll() }
                        Button("收起所有分组") { collapsedGroups = Set(groups.map(\.id)) }
                    }
                } label: { Image(systemName: "slider.horizontal.3") }
                .menuStyle(.borderlessButton).fixedSize().help("分组与排序").accessibilityLabel("分组与排序")
            }
            if !selectedBank.isEmpty {
                HStack {
                    Text(selectedBank).font(.caption).foregroundStyle(palette.accent)
                    Button { selectedBank = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("清除银行筛选")
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(palette.selection, in: Capsule())
            }
            if reminderCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                    Text("\(reminderCount) 张卡片的年费需要留意").font(.caption)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(palette.warning).padding(11)
                .background(palette.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var batchBar: some View {
        HStack(spacing: 10) {
            Text("已选 \(selectedCardIDs.count) 张").font(.caption)
            Button(selectedCardIDs.isSuperset(of: Set(visibleItems.map(\.id))) ? "取消全选" : "全选当前结果") {
                let ids = Set(visibleItems.map(\.id))
                if selectedCardIDs.isSuperset(of: ids) { selectedCardIDs.subtract(ids) } else { selectedCardIDs.formUnion(ids) }
            }.buttonStyle(.borderless)
            Spacer(minLength: 0)
            Button("修改") { showingBatchEditor = true }.disabled(selectedCardIDs.isEmpty)
            Button("删除", role: .destructive) { showingBatchDeleteConfirmation = true }.disabled(selectedCardIDs.isEmpty)
        }
        .controlSize(.small)
    }

    private var catalog: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(groups) { group in
                        if groupBy != .none {
                            Button {
                                withAnimation(animation) {
                                    if collapsedGroups.contains(group.id) { collapsedGroups.remove(group.id) } else { collapsedGroups.insert(group.id) }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: collapsedGroups.contains(group.id) ? "chevron.right" : "chevron.down").frame(width: 10)
                                    Text(group.title).lineLimit(1)
                                    Text("\(group.items.count) 张").foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .font(.system(size: 12, weight: .medium)).padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                        if !collapsedGroups.contains(group.id) {
                            if layout == "grid" {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                                    ForEach(group.items) { item in entry(item, grid: true, scrollTo: { proxy.scrollTo($0, anchor: .center) }).id(item.id) }
                                }
                            } else {
                                ForEach(group.items) { item in entry(item, grid: false, scrollTo: { proxy.scrollTo($0, anchor: .center) }).id(item.id) }
                            }
                        }
                    }
                }
                .padding(3)
                .background(WalletScrollTrackAppearance())
            }
        }
    }

    private func entry(_ item: CardCatalogItem, grid: Bool, scrollTo: @escaping (String) -> Void) -> some View {
        Button {
            focusedCard = item.id
            if isSelectionMode {
                if selectedCardIDs.contains(item.id) { selectedCardIDs.remove(item.id) } else { selectedCardIDs.insert(item.id) }
            } else {
                withAnimation(animation) { selectedCardID = item.id }
            }
        } label: {
            HStack(spacing: 5) {
                if favoriteIDs.contains(item.id) { Image(systemName: "star.fill").foregroundStyle(palette.accent).accessibilityLabel("已收藏") }
                WalletCatalogRow(item: item, grid: grid, selected: isSelectionMode ? selectedCardIDs.contains(item.id) : selectedCardID == item.id, selectionMode: isSelectionMode, compact: appearance.compactList)
            }
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .focused($focusedCard, equals: item.id)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(focusedCard == item.id ? palette.accent.opacity(0.6) : .clear, lineWidth: 1).allowsHitTesting(false))
        .onKeyPress(.upArrow) { moveSelection(from: item.id, step: -1, scrollTo: scrollTo); return .handled }
        .onKeyPress(.downArrow) { moveSelection(from: item.id, step: 1, scrollTo: scrollTo); return .handled }
        .contextMenu {
            Button { LocalCardPreferences.toggle(item.id) } label: {
                Label(favoriteIDs.contains(item.id) ? "取消收藏" : "收藏卡片", systemImage: favoriteIDs.contains(item.id) ? "star.slash" : "star")
            }
            Button("查看完整详情") { detailCard = item.card }
            Button("编辑卡片") { edit(item.card) }
            if item.card.cardCategory != "debit" {
                Divider()
                Button("确认本周期已达标") { onUpdateStatus(item.card, "1") }
                Button("标记为未达标") { onUpdateStatus(item.card, "2") }
                Button("终免年费") { onUpdateStatus(item.card, "3") }
            }
            Divider()
            Button("删除卡片", role: .destructive) { onDelete(item.card) }
        }
    }

    private func moveSelection(from id: String, step: Int, scrollTo: (String) -> Void) {
        let navigationItems = groups.filter { !collapsedGroups.contains($0.id) }.flatMap(\.items)
        guard let current = navigationItems.firstIndex(where: { $0.id == id }) else { return }
        let next = current + step
        guard navigationItems.indices.contains(next) else { return }
        focusedCard = navigationItems[next].id
        if !isSelectionMode { selectedCardID = navigationItems[next].id }
        scrollTo(navigationItems[next].id)
    }

    private func prepare() {
        needsPreparation = true
        selectedCardIDs.formIntersection(Set(cards.map(\.id)))
        refreshGroups()
    }
    private func refreshGroups() {
        catalogTask?.cancel()
        isPreparingCatalog = true
        let cardsSnapshot = cards
        let cachedItems = preparedCards
        let querySnapshot = query
        let favorites = favoriteIDs
        let favoritesOnly = onlyFavorites
        let rebuildItems = needsPreparation
        catalogTask = Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                let items = rebuildItems ? cardsSnapshot.map(CardCatalogItem.init) : cachedItems
                return (items, CardCatalog.groups(items: favoritesOnly ? items.filter { favorites.contains($0.id) } : items, query: querySnapshot))
            }.value
            guard !Task.isCancelled else { return }
            preparedCards = result.0
            groups = result.1
            needsPreparation = false
            isPreparingCatalog = false
            collapsedGroups.formIntersection(Set(groups.map(\.id)))
            if !visibleItems.contains(where: { $0.id == selectedCardID }) { selectedCardID = visibleItems.first?.id }
        }
    }
    private func addCard() { cardEditRequest = CardEditRequest(mode: "add", card: nil, cardCategory: cardCategoryFilter == .debit ? "debit" : "credit") }
    private func edit(_ card: SharedCard) { cardEditRequest = CardEditRequest(mode: "edit", card: card) }
}

struct WalletCatalogRow: View {
    let item: CardCatalogItem
    let grid: Bool
    let selected: Bool
    let selectionMode: Bool
    let compact: Bool
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletAnimation) private var animation
    @State private var hovered = false
    var body: some View {
        Group {
            if grid {
                VStack(alignment: .leading, spacing: 12) {
                    WalletCardFace(card: item.card).frame(height: 138)
                    HStack {
                        Text(item.card.alias?.isEmpty == false ? item.card.alias! : item.card.bank).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 4)
                        WalletAnnualBadge(card: item.card)
                    }
                }
                .padding(12)
            } else {
                HStack(spacing: 11) {
                    if selectionMode {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(palette.accent)
                    }
                    WalletBankLogo(bank: item.card.bank, country: item.card.country, width: 32, height: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.card.bank).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Text("\(item.card.alias ?? "") · \(String(item.card.cardNumber.suffix(4)))")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    CardBrandIcon(brand: item.brand, width: 34, height: 22)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(item.card.cardCategory == "debit" ? "—" : WalletFormat.amount(item.card.limit, currency: item.card.type))
                            .font(.system(size: 12, weight: .medium)).monospacedDigit()
                        if item.card.isSharedLimit && item.card.cardCategory != "debit" { Text("同行共享").font(.system(size: 10)).foregroundStyle(.secondary) }
                    }
                    .frame(minWidth: 70, alignment: .trailing)
                    WalletAnnualBadge(card: item.card).frame(width: 74, alignment: .trailing)
                }
                .padding(.horizontal, 12).frame(minHeight: compact ? 62 : 78)
            }
        }
        .background(selected ? palette.surface : hovered ? palette.surface.opacity(0.55) : .clear, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? palette.edge : .clear, lineWidth: 1))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .animation(animation, value: hovered)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private struct WalletCardInspector: View {
    let card: SharedCard
    let onEdit: () -> Void
    let onViewDetails: () -> Void
    let onUpdateStatus: (String) -> Void
    @Environment(\.walletPalette) private var palette
    @State private var copied = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                HStack {
                    Text("卡片详情").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(action: onViewDetails) { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                        .buttonStyle(.plain).help("查看完整详情").accessibilityLabel("查看完整详情")
                }
                WalletCardFace(card: card).frame(height: 151)
                CardAttachmentStrip(images: card.cardImages)
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.alias?.isEmpty == false ? card.alias! : card.bank).font(.system(size: 17, weight: .semibold))
                    Text("\(card.bank) · 尾号 \(String(card.cardNumber.suffix(4)))").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(card.cardNumber, forType: .string)
                        copied = true
                    } label: { Label(copied ? "已复制" : "复制卡号", systemImage: copied ? "checkmark" : "doc.on.doc") }
                    Button(action: onEdit) { Label("编辑", systemImage: "pencil") }
                }
                .controlSize(.small)
                Divider()
                if card.cardCategory != "debit" {
                    HStack { WalletFieldValue(title: "信用额度", value: WalletFormat.amount(card.limit, currency: card.type)); WalletFieldValue(title: "额度类型", value: card.isSharedLimit ? String(localized: "同行共享") : String(localized: "独立额度")) }
                    HStack { WalletFieldValue(title: "账单日", value: WalletFormat.day(card.accountBillDate)); WalletFieldValue(title: "还款日", value: WalletFormat.day(card.dueDate)) }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("年费管理").font(.system(size: 13, weight: .semibold)); Spacer(); WalletAnnualBadge(card: card) }
                        if card.isQualified != "3" {
                            Text(WalletFormat.amount(card.annualFee, currency: card.type)).font(.subheadline).monospacedDigit()
                            Text("下次收取：\(WalletFormat.date(card.nextAnnualFeeCollectionTime))").font(.caption).foregroundStyle(.secondary)
                            if card.isQualified != "1" || DateCalculator.annualFeeDetection(for: card) != nil {
                                Button { onUpdateStatus("1") } label: { Label("确认本周期已达标", systemImage: "checkmark") }
                                    .controlSize(.small)
                            }
                        }
                    }
                    .modifier(WalletSurface(padding: 12))
                } else {
                    HStack { WalletFieldValue(title: "卡片类别", value: String(localized: "储蓄卡")); WalletFieldValue(title: "有效期", value: card.valid ?? String(localized: "未填写")) }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("权益与备注").font(.system(size: 13, weight: .semibold))
                    Text(card.equity?.isEmpty == false ? card.equity! : String(localized: "暂无权益说明"))
                    if let remark = card.remark, !remark.isEmpty { Text(remark) }
                }
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Button(action: onViewDetails) {
                    Label("查看完整信息", systemImage: "info.circle")
                }
                .buttonStyle(.borderless).font(.caption)
                Text("\(card.country) · \(card.type ?? "")").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(21)
            .background(WalletScrollTrackAppearance())
        }
        .onChange(of: card.id) { _, _ in copied = false }
        .onChange(of: card.cardNumber) { _, _ in copied = false }
    }
}
