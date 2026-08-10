import SwiftUI

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

enum CardCategoryFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case credit = "信用卡"
    case debit = "储蓄卡"
    
    var id: String { rawValue }
}

struct AllCardsView: View {
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

    private var toolbarSubtitle: String {
        if filteredCards.count == cards.count {
            return "共 \(cards.count) 张卡片 · 信用卡 \(creditCardCount) · 储蓄卡 \(debitCardCount)"
        }
        return "共 \(cards.count) 张卡片 · 当前显示 \(filteredCards.count) 张"
    }

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(
                iconName: "creditcard.fill",
                iconColor: SoftColors.cyan,
                title: "卡包",
                subtitle: toolbarSubtitle
            ) {
                HStack(spacing: 10) {
                    searchField
                    categoryPicker
                    filterButton
                    selectionModeButton
                    addCardButton
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))

            if isSelectionMode {
                selectionBar
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if filteredCards.isEmpty {
                VStack {
                    AppEmptyState(
                        iconName: searchText.isEmpty ? "creditcard.and.123" : "magnifyingglass",
                        title: searchText.isEmpty ? "还没有银行卡" : "没有找到匹配卡片",
                        message: searchText.isEmpty ? "添加第一张卡片后，账单提醒、年费状态和同步都会自动接上。" : "试试换个关键词，或切回“全部”卡类别查看。",
                        accentColor: SoftColors.cyan,
                        actionTitle: searchText.isEmpty ? "新增卡片" : nil,
                        action: searchText.isEmpty ? {
                            cardEditRequest = CardEditRequest(mode: "add", card: nil, cardCategory: "credit")
                        } : nil
                    )
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

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索银行、别名、卡号…", text: $searchText)
                .textFieldStyle(.plain)
                .frame(width: 210)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .appPanel(cornerRadius: AppVisualMetrics.controlCornerRadius, tint: SoftColors.cyan)
    }

    private var categoryPicker: some View {
        Picker("卡类别", selection: $cardCategoryFilter) {
            Text("全部 \(searchFilteredCards.count)").tag(CardCategoryFilter.all)
            Text("信用卡 \(creditCardCount)").tag(CardCategoryFilter.credit)
            Text("储蓄卡 \(debitCardCount)").tag(CardCategoryFilter.debit)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 250)
    }

    private var filterButton: some View {
        Button {
            showingFilterPopover = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(groupBy.rawValue) · \(sortBy.rawValue)")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .appPanel(cornerRadius: AppVisualMetrics.controlCornerRadius, tint: SoftColors.cyan)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingFilterPopover, arrowEdge: .bottom) {
            filterPopover
        }
    }

    private var selectionModeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSelectionMode.toggle()
                if !isSelectionMode { selectedCardIDs.removeAll() }
            }
        } label: {
            Label(isSelectionMode ? "退出批量" : "批量操作", systemImage: isSelectionMode ? "xmark.circle" : "checklist")
        }
        .buttonStyle(.bordered)
    }

    private var addCardButton: some View {
        Button {
            cardEditRequest = CardEditRequest(mode: "add", card: nil, cardCategory: "credit")
        } label: {
            Label("新增卡片", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .tint(SoftColors.cyan)
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            AppStatusPill(
                text: "已选择 \(selectedCardIDs.count) 张",
                color: SoftColors.cyan,
                systemImage: "checkmark.circle.fill"
            )
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
                .tint(SoftColors.cyan)
                .disabled(selectedCardIDs.isEmpty)
            Button("批量删除", role: .destructive) { showingBatchDeleteConfirmation = true }
                .buttonStyle(.bordered)
                .disabled(selectedCardIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(SoftColors.cyan.opacity(0.045))
    }

    private var filterPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .foregroundColor(SoftColors.cyan)
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
                            .background(groupBy == option ? SoftColors.cyan.opacity(0.15) : Color.primary.opacity(0.03))
                            .foregroundColor(groupBy == option ? SoftColors.cyan : .primary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(groupBy == option ? SoftColors.cyan.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()
                .opacity(0.5)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .foregroundColor(SoftColors.cyan)
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
                                    .foregroundColor(sortBy == option ? SoftColors.cyan : .secondary)
                                Text(option.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundColor(sortBy == option ? .primary : .secondary)
                                Spacer()
                                if sortBy == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(SoftColors.cyan)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(sortBy == option ? SoftColors.cyan.opacity(0.08) : Color.clear)
                            .cornerRadius(7)
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
}


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
