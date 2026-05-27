import SwiftUI
import AppKit

public struct DiffPreviewRequest: Identifiable {
    public let id = UUID()
    public let backupCards: [SharedCard]
    public let requiresIdentityReview: Bool
    
    public init(backupCards: [SharedCard], requiresIdentityReview: Bool = false) {
        self.backupCards = backupCards
        self.requiresIdentityReview = requiresIdentityReview
    }
}

public struct CardDiffResult: Identifiable {
    public var id: String { cardId }
    let cardId: String
    let bank: String
    let cardNumber: String
    let changeType: ChangeType
    let fieldChanges: [FieldChange]
    
    // 新增：双端最后修改时间对比与版本状态
    let localModifyTime: String
    let backupModifyTime: String
    let versionState: VersionState
    
    public enum VersionState {
        case localNewer  // 本地较新，备份较旧
        case backupNewer // 备份较新，本地较旧
        case identical   // 两端修改时间完全相同
        case unknown     // 缺省或单边状态
    }
    
    enum ChangeType {
        case added    // 当前有，备份无 (恢复后将被清除)
        case deleted  // 备份有，当前无 (恢复后将重新找回)
        case modified // 双方都有，字段有变动
    }
    
    struct FieldChange: Identifiable {
        var id: String { fieldName }
        let fieldName: String
        let oldValue: String
        let newValue: String
    }
}

public struct DiffPreviewView: View {
    @Environment(\.dismiss) var dismiss
    
    let currentCards: [SharedCard]
    let backupCards: [SharedCard]
    let requiresIdentityReview: Bool
    
    let onConfirmRestore: ([SharedCard]) -> Void
    let onConfirmMerge: ([SharedCard]) -> Void
    
    @State private var diffs: [CardDiffResult] = []
    
    // 💡 尊贵的同步微动效状态
    @State private var isProcessing = false
    @State private var processSuccess = false
    @State private var successMessage = ""
    
    public init(
        currentCards: [SharedCard],
        backupCards: [SharedCard],
        requiresIdentityReview: Bool = false,
        onConfirmRestore: @escaping ([SharedCard]) -> Void,
        onConfirmMerge: @escaping ([SharedCard]) -> Void
    ) {
        self.currentCards = currentCards
        self.backupCards = backupCards
        self.requiresIdentityReview = requiresIdentityReview
        self.onConfirmRestore = onConfirmRestore
        self.onConfirmMerge = onConfirmMerge
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 头部说明：高保真拟物，去除 Emoji
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.cyan)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("备份数据对比与恢复")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.primary)
                        Text("系统正在将备份文件与您当前的本地卡包进行精密对比，请仔细审查变更：")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(20)
                .background(Color(.windowBackgroundColor))
                
                Divider()
                
                // 差异核心对比区
                ScrollView {
                    VStack(spacing: 16) {
                        if diffs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)
                                Text("当前卡包与备份完全一致，无任何变更！")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 80)
                        } else {
                            ForEach(diffs) { diff in
                                DiffCardRow(diff: diff)
                            }
                        }
                    }
                    .padding(20)
                }
                
                Divider()
                
                // 底部操作区
                HStack(spacing: 14) {
                    // 仅在有差异时才显示融合和覆盖选项
                    if !diffs.isEmpty {
                        Button(action: {
                            performSmartMerge()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .bold))
                                Text("保留较新的数据")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .disabled(isProcessing || processSuccess)
                        .help("对比每张信用卡的修改时间，保留较新的卡片数据。")
                        
                        Button("使用此备份覆盖") {
                            showOverwriteConfirmation()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.orange)
                        .disabled(isProcessing || processSuccess)
                        .help("强制用该备份覆盖本地。若本地有比备份更新的数据，系统将进行拦截警告。")
                    }
                    
                    Spacer()
                    
                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    .disabled(isProcessing || processSuccess)
                }
                .padding(16)
                .background(Color(.windowBackgroundColor))
            }

            // 磨砂加载同步过场面板
            if isProcessing {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.3)
                        .padding(.bottom, 10)
                    
                    Text("正在处理数据...")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("正在保存本地数据，并同步到云端。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .transition(.opacity)
            } else if processSuccess {
                VStack(spacing: 18) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.green)
                        .symbolEffect(.bounce, value: processSuccess) // macOS 14+ 专属高拟物回弹效果！
                    
                    Text("同步完成")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.primary)
                    
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 50)
                    
                    Button("知道了") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .transition(.opacity)
            }
        }
        .frame(width: 720, height: 530)
        .onAppear {
            calculateDiff()
        }
    }
    
    // 双向合并调用入口
    private func performSmartMerge() {
        guard let reviewedBackupCards = reviewedBackupCardsForRestore() else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            isProcessing = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let merged = generateMergedCards(backupCards: reviewedBackupCards)
            onConfirmMerge(merged)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                isProcessing = false
                successMessage = "已保留较新的卡片数据，并同步到云端。"
                processSuccess = true
            }
        }
    }
    
    // 单向覆盖调用入口
    private func executeRestoreAction() {
        guard let reviewedBackupCards = reviewedBackupCardsForRestore() else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            isProcessing = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onConfirmRestore(reviewedBackupCards)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                isProcessing = false
                successMessage = "已按所选备份恢复本地卡片数据，并同步到云端。"
                processSuccess = true
            }
        }
    }
    
    // 差异分析与时间排序
    private func calculateDiff() {
        var results: [CardDiffResult] = []
        
        let currentMap = cardsByID(currentCards)
        let backupMap = cardsByID(backupCards)
        
        // 1. 寻找被删掉的卡 (备份有，当前无) -> 恢复后将重新找回 (高亮绿色)
        for (id, backupCard) in backupMap {
            if currentMap[id] == nil {
                results.append(
                    CardDiffResult(
                        cardId: id,
                        bank: backupCard.bank,
                        cardNumber: backupCard.cardNumber,
                        changeType: .deleted,
                        fieldChanges: [],
                        localModifyTime: "无 (当前本地不存在此卡)",
                        backupModifyTime: formatModifyTime(backupCard.lastModifyTime),
                        versionState: .backupNewer // 云端独有，视为云端新
                    )
                )
            }
        }
        
        // 2. 寻找新增加的卡 (当前有, 备份无) -> 恢复后将被清除 (高亮红色)
        for (id, currentCard) in currentMap {
            if backupMap[id] == nil {
                results.append(
                    CardDiffResult(
                        cardId: id,
                        bank: currentCard.bank,
                        cardNumber: currentCard.cardNumber,
                        changeType: .added,
                        fieldChanges: [],
                        localModifyTime: formatModifyTime(currentCard.lastModifyTime),
                        backupModifyTime: "无 (云端备份中不存在此卡)",
                        versionState: .localNewer // 本地独有，视为本地新
                    )
                )
            }
        }
        
        // 3. 寻找发生改动的卡 (双方都有，对比各个字段) -> 字段变更 (高亮黄色)
        for (id, currentCard) in currentMap {
            if let backupCard = backupMap[id] {
                var fieldChanges: [CardDiffResult.FieldChange] = []
                
                if currentCard.bank != backupCard.bank {
                    fieldChanges.append(.init(fieldName: "银行", oldValue: currentCard.bank, newValue: backupCard.bank))
                }
                if currentCard.limit != backupCard.limit {
                    fieldChanges.append(.init(fieldName: "额度", oldValue: String(format: "%.0f", currentCard.limit ?? 0), newValue: String(format: "%.0f", backupCard.limit ?? 0)))
                }
                if currentCard.alias != backupCard.alias {
                    fieldChanges.append(.init(fieldName: "别名", oldValue: currentCard.alias ?? "无", newValue: backupCard.alias ?? "无"))
                }
                if currentCard.isQualified != backupCard.isQualified {
                    let oldText = getStatusText(currentCard.isQualified)
                    let newText = getStatusText(backupCard.isQualified)
                    fieldChanges.append(.init(fieldName: "年费状态", oldValue: oldText, newValue: newText))
                }
                if currentCard.accountBillDate != backupCard.accountBillDate || currentCard.dueDate != backupCard.dueDate {
                    fieldChanges.append(.init(fieldName: "账单周期", oldValue: "\(currentCard.accountBillDate ?? "")-\(currentCard.dueDate ?? "")", newValue: "\(backupCard.accountBillDate ?? "")-\(backupCard.dueDate ?? "")"))
                }
                if currentCard.isSharedLimit != backupCard.isSharedLimit {
                    fieldChanges.append(.init(fieldName: "共享额度", oldValue: currentCard.isSharedLimit ? "开启" : "关闭", newValue: backupCard.isSharedLimit ? "开启" : "关闭"))
                }
                if currentCard.cardNumber != backupCard.cardNumber {
                    fieldChanges.append(.init(fieldName: "卡号", oldValue: currentCard.cardNumber.isEmpty ? "无" : "****" + String(currentCard.cardNumber.suffix(4)), newValue: backupCard.cardNumber.isEmpty ? "无" : "****" + String(backupCard.cardNumber.suffix(4))))
                }
                if currentCard.type != backupCard.type {
                    fieldChanges.append(.init(fieldName: "币种", oldValue: currentCard.type ?? "CNY", newValue: backupCard.type ?? "CNY"))
                }
                
                if !fieldChanges.isEmpty {
                    // 统一解析跨端时间格式，避免以字符串符号顺序误判新旧版本
                    let lTime = currentCard.lastModifyTime
                    let bTime = backupCard.lastModifyTime
                    
                    let vState: CardDiffResult.VersionState
                    switch DataMigrationManager.compareLastModifyTime(local: lTime, backup: bTime) {
                    case .orderedDescending?:
                        vState = .localNewer
                    case .orderedAscending?:
                        vState = .backupNewer
                    case .orderedSame?:
                        vState = .identical
                    case nil:
                        vState = .unknown
                    }
                    
                    results.append(
                        CardDiffResult(
                            cardId: id,
                            bank: currentCard.bank,
                            cardNumber: currentCard.cardNumber,
                            changeType: .modified,
                            fieldChanges: fieldChanges,
                            localModifyTime: formatModifyTime(lTime),
                            backupModifyTime: formatModifyTime(bTime),
                            versionState: vState
                        )
                    )
                }
            }
        }
        
        self.diffs = results
    }
    
    // 双向合并算法
    private func generateMergedCards(backupCards: [SharedCard]) -> [SharedCard] {
        var merged: [SharedCard] = []
        
        let currentMap = cardsByID(currentCards)
        let backupMap = cardsByID(backupCards)
        
        // 所有卡片的 ID 集合
        let allIds = Set(currentMap.keys).union(backupMap.keys)
        
        for id in allIds {
            let current = currentMap[id]
            let backup = backupMap[id]
            
            if let cur = current, let bac = backup {
                // 只有确认备份时间更新时才覆盖本地，时间异常时优先保护当前编辑结果
                if DataMigrationManager.compareLastModifyTime(local: cur.lastModifyTime, backup: bac.lastModifyTime) == .orderedAscending {
                    merged.append(bac)
                } else {
                    merged.append(cur)
                }
            } else if let cur = current {
                // 仅本地有，保留本地
                merged.append(cur)
            } else if let bac = backup {
                // 仅备份有，保留备份
                merged.append(bac)
            }
        }
        
        return merged
    }

    private func cardsByID(_ cards: [SharedCard]) -> [String: SharedCard] {
        cards.reduce(into: [:]) { result, card in
            guard !card.id.isEmpty else { return }
            if let existing = result[card.id],
               DataMigrationManager.compareLastModifyTime(local: existing.lastModifyTime, backup: card.lastModifyTime) != .orderedAscending {
                return
            }
            result[card.id] = card
        }
    }

    private func reviewedBackupCardsForRestore() -> [SharedCard]? {
        guard requiresIdentityReview else {
            return backupCards
        }

        return CardRestoreIdentityResolver.resolve(
            incomingCards: backupCards,
            existingCards: currentCards
        ) { match in
            requestIdentityDecision(for: match)
        }
    }

    private func requestIdentityDecision(for match: CardRestoreIdentityResolver.PotentialMatch) -> CardRestoreIdentityResolver.Decision? {
        let firstAlert = NSAlert()
        firstAlert.messageText = "发现卡号相同的卡片"
        firstAlert.informativeText = "备份中的「\(cardDisplayName(match.incoming))」和当前卡包里的「\(cardDisplayName(match.existing))」卡号相同。\n\n请确认它们是不是同一张卡。"
        firstAlert.addButton(withTitle: "是，同一张卡")
        firstAlert.addButton(withTitle: "不是，作为新卡保存")
        firstAlert.addButton(withTitle: "先不处理")
        firstAlert.alertStyle = .warning

        switch firstAlert.runModal() {
        case .alertFirstButtonReturn:
            return requestSameCardDecision(for: match)
        case .alertSecondButtonReturn:
            return confirmSeparateCard(for: match) ? .keepSeparate : nil
        default:
            return nil
        }
    }

    private func requestSameCardDecision(for match: CardRestoreIdentityResolver.PotentialMatch) -> CardRestoreIdentityResolver.Decision? {
        let chooseAlert = NSAlert()
        chooseAlert.messageText = "选择保留哪份数据"
        chooseAlert.informativeText = "这张卡在当前卡包和备份里都有记录。请选择恢复后保留哪一份内容。"
        chooseAlert.addButton(withTitle: "保留当前卡包中的数据")
        chooseAlert.addButton(withTitle: "使用备份中的数据")
        chooseAlert.addButton(withTitle: "先不处理")
        chooseAlert.alertStyle = .informational

        let decision: CardRestoreIdentityResolver.Decision
        let sourceText: String
        switch chooseAlert.runModal() {
        case .alertFirstButtonReturn:
            decision = .keepCurrent
            sourceText = "当前卡包中的内容"
        case .alertSecondButtonReturn:
            decision = .keepIncoming
            sourceText = "备份中的内容"
        default:
            return nil
        }

        let confirmAlert = NSAlert()
        confirmAlert.messageText = "再次确认"
        confirmAlert.informativeText = "将把「\(cardDisplayName(match.incoming))」和「\(cardDisplayName(match.existing))」视为同一张卡，并保留\(sourceText)。\n\n确认后不会额外生成重复卡片。"
        confirmAlert.addButton(withTitle: "确认")
        confirmAlert.addButton(withTitle: "返回检查")
        confirmAlert.alertStyle = .warning

        return confirmAlert.runModal() == .alertFirstButtonReturn ? decision : nil
    }

    private func confirmSeparateCard(for match: CardRestoreIdentityResolver.PotentialMatch) -> Bool {
        let confirmAlert = NSAlert()
        confirmAlert.messageText = "再次确认"
        confirmAlert.informativeText = "将把备份中的「\(cardDisplayName(match.incoming))」作为另一张卡保存，与当前卡包里的「\(cardDisplayName(match.existing))」分开管理。\n\n确认后这两张卡会同时保留。"
        confirmAlert.addButton(withTitle: "确认作为新卡保存")
        confirmAlert.addButton(withTitle: "返回检查")
        confirmAlert.alertStyle = .warning
        return confirmAlert.runModal() == .alertFirstButtonReturn
    }

    private func cardDisplayName(_ card: SharedCard) -> String {
        let alias = (card.alias ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let name = alias.isEmpty ? card.bank : "\(card.bank) - \(alias)"
        let digits = CardRestoreIdentityResolver.cardNumberFingerprint(card.cardNumber)
        guard digits.count >= 4 else {
            return name
        }
        return "\(name) 尾号 \(String(digits.suffix(4)))"
    }

    private func formatModifyTime(_ timestamp: Double) -> String {
        DateCalculator.formatTimestampDateTime(timestamp, placeholder: "未记录")
    }
    
    // 针对单向覆盖恢复的安全确认
    private func showOverwriteConfirmation() {
        let localNewerCount = diffs.filter { $0.versionState == .localNewer }.count
        if localNewerCount > 0 {
            let localNewerBanks = diffs.filter { $0.versionState == .localNewer }.map { $0.bank }.prefix(3).joined(separator: "、")
            let suffix = diffs.filter { $0.versionState == .localNewer }.count > 3 ? "等" : ""
            
            let alert = NSAlert()
            alert.messageText = "本地存在较新的卡片"
            alert.informativeText = "检测到本地有 \(localNewerCount) 张信用卡比当前备份更新（如：\(localNewerBanks)\(suffix)）。\n\n继续使用此备份覆盖会丢失这些本地修改。是否继续？"
            alert.addButton(withTitle: "取消")
            alert.addButton(withTitle: "继续覆盖")
            alert.alertStyle = .critical
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                // 用户确认强行覆盖，使用带动效的 executeRestoreAction()
                executeRestoreAction()
            }
        } else {
            // 安全无风险覆盖，使用带动效的 executeRestoreAction()
            executeRestoreAction()
        }
    }
    
    private func getStatusText(_ status: String?) -> String {
        switch status {
        case "1": return "已达标"
        case "2": return "未达标"
        case "3": return "终免年费"
        default: return "未达标"
        }
    }
}

// 差异行渲染视图 (升级拟物与磨砂新旧勋章)
struct DiffCardRow: View {
    let diff: CardDiffResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 卡片头部与状态标签
            HStack(spacing: 8) {
                Text(diff.bank)
                    .font(.headline)
                    .bold()
                Text("**** **** **** \(String(diff.cardNumber.suffix(4)))")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                
                // 核心：智能版本新旧勋章
                if diff.changeType == .modified {
                    if diff.versionState == .localNewer {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                            Text("本地较新，合并会保留本地")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(4)
                    } else if diff.versionState == .backupNewer {
                        HStack(spacing: 3) {
                            Image(systemName: "icloud.and.arrow.down.fill")
                                .font(.system(size: 8))
                            Text("云端较新，合并会采用云端")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // 行右侧状态变更描述标签
                TagView(changeType: diff.changeType)
            }
            
            // 双方修改时间轴对比透显 (核心知情权)
            if diff.changeType == .modified {
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 9))
                        Text("本地当前修改时间：\(diff.localModifyTime)")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(diff.versionState == .localNewer ? .blue.opacity(0.8) : .secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 9))
                        Text("云端备份修改时间：\(diff.backupModifyTime)")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(diff.versionState == .backupNewer ? .green.opacity(0.8) : .secondary)
                }
                .padding(.horizontal, 4)
            } else if diff.changeType == .added {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 9))
                    Text("本地修改时间：\(diff.localModifyTime)")
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            } else if diff.changeType == .deleted {
                HStack(spacing: 4) {
                    Image(systemName: "icloud")
                        .font(.system(size: 9))
                    Text("备份修改时间：\(diff.backupModifyTime)")
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            }
            
            // 字段对比列表
            if diff.changeType == .modified {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(diff.fieldChanges) { change in
                        FieldComparisonRow(change: change, versionState: diff.versionState)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.035))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(getBorderColor(diff.changeType), lineWidth: 1)
        )
    }
    
    private func getBorderColor(_ change: CardDiffResult.ChangeType) -> Color {
        switch change {
        case .added: return .red.opacity(0.3)
        case .deleted: return .green.opacity(0.3)
        case .modified: return .yellow.opacity(0.3)
        }
    }
}

private struct FieldComparisonRow: View {
    let change: CardDiffResult.FieldChange
    let versionState: CardDiffResult.VersionState

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(change.fieldName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            valueBlock(title: "本地当前", value: change.oldValue, isWinner: versionState == .localNewer)

            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.8))

            valueBlock(title: "云端备份", value: change.newValue, isWinner: versionState == .backupNewer)
        }
    }

    private func valueBlock(title: String, value: String, isWinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(title)
                if isWinner {
                    Text("将保留")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(3)
                }
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(isWinner ? .blue : .secondary)

            Text(value)
                .font(.system(size: 12, weight: isWinner ? .bold : .regular, design: .rounded))
                .foregroundColor(isWinner ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(minWidth: 110, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isWinner ? Color.blue.opacity(0.08) : Color.primary.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isWinner ? Color.blue.opacity(0.18) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct TagView: View {
    let changeType: CardDiffResult.ChangeType
    
    var body: some View {
        switch changeType {
        case .added:
            Text("备份中不存在此卡")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.12))
                .cornerRadius(4)
        case .deleted:
            Text("本地缺失此卡")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.12))
                .cornerRadius(4)
        case .modified:
            Text("字段存在差异")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(4)
        }
    }
}
