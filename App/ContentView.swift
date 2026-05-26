import SwiftUI

private struct CardEditRequest: Identifiable {
    let id = UUID()
    let mode: String
    let card: SharedCard?
}

struct ContentView: View {
    @State private var cards: [SharedCard] = []
    @State private var selection: NavigationSection? = .allCards
    @State private var searchText = ""
    
    // 💡 分组和排序状态管理
    @State private var groupBy: GroupOption = .bank
    @State private var sortBy: SortOption = .limitDesc
    @State private var showingFilterPopover = false
    
    // 编辑弹窗请求，创建弹窗时一并携带模式和目标卡片
    @State private var cardEditRequest: CardEditRequest?
    
    // 监听自动锁定状态
    @State private var lockManager = AutoLockManager.shared
    
    // 💡 共享的 Diff 预览控制 (为自动检测提供前台红绿比对支持)
    @State private var diffPreviewRequest: DiffPreviewRequest?
    
    // 💡 云端最新变动感知警报控制
    @State private var showingCloudAlert = false
    @State private var cloudAlertMessage = ""
    @State private var cloudAlertCards: [SharedCard] = []
    
    var filteredCards: [SharedCard] {
        if searchText.isEmpty {
            return cards
        } else {
            return cards.filter { card in
                card.bank.localizedCaseInsensitiveContains(searchText) ||
                (card.alias ?? "").localizedCaseInsensitiveContains(searchText) ||
                card.cardNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
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
                            CloudSyncView(currentCards: cards, onDataRestored: { restoredCards in
                                self.cards = restoredCards
                            })
                        case .settings:
                            SettingsView(currentCards: cards, onDataRestored: { restoredCards in
                                self.cards = restoredCards
                            })
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
            loadCards()
            
            // 💡 订阅云端最新账本变动警报，实现高阶云端实时变动感知
            CloudSyncManager.shared.onCloudChangeDetected = { filename, cloudCards in
                // 💡 如果系统被锁定了，绝不在前台弹窗打扰，也不要让警报浮在锁屏之后！
                guard !lockManager.isLocked else { return }
                
                self.cloudAlertCards = cloudCards
                if cloudCards.isEmpty {
                    self.cloudAlertMessage = "检测到云端存在最新的账本备份：\n\(filename)\n\n此备份采用了自定义密码加密。请前往云同步中心，点击恢复以输入密码进行解密与比对。"
                } else {
                    self.cloudAlertMessage = "检测到云端存在更新/不同的账本备份：\n\(filename)\n\n系统已为您在后台静默解密，是否立即前往云端比对中心，进行可视化红绿差异对比？"
                }
                self.showingCloudAlert = true
            }
            
            // 💡 自动根据偏好设置启动/重置自动检测轮询 Timer
            CloudSyncManager.shared.setupTimerFromConfig()
        }
        // 请求存在后才创建完整表单，避免首次呈现产生空内容窗口
        .sheet(item: $cardEditRequest) { request in
            CardEditView(
                mode: request.mode,
                cardToEdit: request.card,
                existingCards: cards,
                onSubmit: { finalCard in
                    if request.mode == "add" {
                        cards.append(finalCard)
                    } else {
                        if let index = cards.firstIndex(where: { $0.id == finalCard.id }) {
                            cards[index] = finalCard
                        }
                    }
                    
                    // 💡 联动同步：如果卡片启用了共享额度，自动同步批量更新其他同银行的共享额度卡片
                    if finalCard.isSharedLimit {
                        let cleanBank = finalCard.bank.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                        for i in 0..<cards.count {
                            let itemBank = cards[i].bank.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                            if cards[i].id != finalCard.id &&
                               cards[i].country == finalCard.country &&
                               itemBank == cleanBank &&
                               cards[i].isSharedLimit {
                                cards[i].limit = finalCard.limit
                                cards[i].lastModifyTime = DateFormatter.iso8601String(from: Date())
                            }
                        }
                    }
                    
                    LocalStorageManager.write(cards: cards)
                    
                    // 💡 联动：卡片数据变动保存后，后台非阻塞地静默云端自动备份同步一份最新账本！
                    CloudSyncManager.shared.triggerSilentAutoUpload(cards: cards)
                }
            )
        }
        // 💡 共享的云端数据红绿可视化 Diff 差异比对 Sheet 弹窗
        .sheet(item: $diffPreviewRequest) { request in
            DiffPreviewView(
                currentCards: cards,
                backupCards: request.backupCards,
                onConfirmRestore: {
                    LocalStorageManager.write(cards: request.backupCards)
                    self.cards = request.backupCards
                    
                    // 导入覆盖完毕后，亦自动触发一次静默备份，使云端与本地完美持平
                    CloudSyncManager.shared.triggerSilentAutoUpload(cards: request.backupCards)
                },
                onConfirmMerge: { mergedCards in
                    // 智能双向大融合，写入本地并静默同步云端让两端同时升至最新
                    LocalStorageManager.write(cards: mergedCards)
                    self.cards = mergedCards
                    CloudSyncManager.shared.triggerSilentAutoUpload(cards: mergedCards)
                }
            )
        }
        // 💡 触发云端变动警报
        .alert("云端数据变动感知", isPresented: $showingCloudAlert) {
            Button("前往比对并恢复") {
                selection = .cloudSync
                if !cloudAlertCards.isEmpty {
                    self.diffPreviewRequest = DiffPreviewRequest(backupCards: cloudAlertCards)
                }
            }
            Button("稍后处理", role: .cancel) {}
        } message: {
            Text(cloudAlertMessage)
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
                    Text("所有信用卡")
                        .font(.title2)
                        .bold()
                }
                
                Spacer()
                
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索银行、别名、卡号...", text: $searchText)
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
                    cardEditRequest = CardEditRequest(mode: "add", card: nil)
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
                    Text(searchText.isEmpty ? "目前暂无信用卡数据，点击右上方新增卡片吧！" : "没有找到符合搜索条件的卡片")
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
                    Text("临近年费卡片")
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
                guard card.isQualified == "2" else { return false }
                return DateCalculator.isNearAnnualFeeDate(card.nextAnnualFeeCollectionTime)
            }
            
            if alertCards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green.opacity(0.6))
                    Text("非常好！目前没有任何信用卡临近收取年费且未达标。")
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
            self.cards = loadedCards
        case .failure(let error):
            print("读取本地数据失败，可能密码错误或数据损坏: \(error.localizedDescription)")
            self.cards = []
        }
    }
    
    private func deleteCard(_ card: SharedCard) {
        let alert = NSAlert()
        alert.messageText = "确认要删除此信用卡吗？"
        alert.informativeText = "银行：\(card.bank)\n别名：\(card.alias ?? "无")\n卡号：\(card.cardNumber.suffix(4))\n\n删除后不可撤销，确认删除吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            cards.removeAll { $0.id == card.id }
            LocalStorageManager.write(cards: cards)
            
            // 💡 联动：卡片删除后，后台静默云端自动备份同步一份最新账本！
            CloudSyncManager.shared.triggerSilentAutoUpload(cards: cards)
        }
    }
    
    private func updateCardStatus(_ card: SharedCard, status: String) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            var updatedCard = cards[index]
            updatedCard.isQualified = status
            updatedCard.lastModifyTime = DateFormatter.iso8601String(from: Date())
            cards[index] = updatedCard
            LocalStorageManager.write(cards: cards)
            
            // 💡 联动：卡片年费状态更新后，后台静默云端自动备份同步一份最新账本！
            CloudSyncManager.shared.triggerSilentAutoUpload(cards: cards)
        }
    }
}
