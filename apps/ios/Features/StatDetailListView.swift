import SwiftUI

struct StatDetailListView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    let type: StatDetailType
    let cards: [SharedCard]

    @State private var cardToEdit: SharedCard? = nil
    @State private var selectedCard: SharedCard? = nil
    @Environment(\.dismiss) private var dismiss


    enum StatDetailType {
        case bank
        case country
        case expiry

        var title: String {
            switch self {
            case .bank: return "发卡行详情"
            case .country: return "发卡国家详情"
            case .expiry: return "即将到期卡片"
            }
        }
    }

    private var groupedByBank: [String: [SharedCard]] {
        Dictionary(grouping: cards, by: { $0.bank })
    }

    private var groupedByCountry: [String: [SharedCard]] {
        Dictionary(grouping: cards, by: { $0.country })
    }

    private var filteredExpiryCards: [SharedCard] {
        cards.filter { card in
            guard let status = DateCalculator.cardExpiryStatus(valid: card.valid) else { return false }
            return status == .expired || status == .soonExpiring
        }
    }

    var body: some View {
        List {
            switch type {
            case .bank:
                ForEach(groupedByBank.keys.sorted(), id: \.self) { bank in
                    StatSummaryRow(
                        title: bank,
                        count: groupedByBank[bank]?.count ?? 0,
                        iconName: "building.columns.fill",
                        iconColor: .purple
                    )
                }
            case .country:
                ForEach(groupedByCountry.keys.sorted(), id: \.self) { country in
                    StatSummaryRow(
                        title: country,
                        count: groupedByCountry[country]?.count ?? 0,
                        iconName: "globe",
                        iconColor: .green
                    )
                }
            case .expiry:
                if filteredExpiryCards.isEmpty {
                    Text("暂无即将到期卡片")
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredExpiryCards) { card in
                        cardRow(card)
                    }
                }
            }
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCard) { card in
            CardDetailView(
                card: card,
                onEdit: { cardToEdit = $0 },
                onDelete: { cardToDelete in
                    var current = syncCoordinator.cards
                    current.removeAll { $0.id == cardToDelete.id }
                    syncCoordinator.commit(cards: current, deletedCardIDs: [cardToDelete.id])
                }
            )
        }
        .sheet(item: $cardToEdit) { card in
            CardEditView(
                mode: "edit",
                cardToEdit: card,
                initialCardCategory: card.cardCategory,
                existingCards: syncCoordinator.cards
            ) { updatedCard in
                if let idx = syncCoordinator.cards.firstIndex(where: { $0.id == card.id }) {
                    var current = syncCoordinator.cards
                    current[idx] = updatedCard
                    syncCoordinator.commit(cards: current)
                }
            }
        }
    }

    private func cardRow(_ card: SharedCard) -> some View {
        Button {
            selectedCard = card
        } label: {
            CreditCardMiniView(card: card)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 统计分析聚合行
struct StatSummaryRow: View {
    let title: String
    let count: Int
    let iconName: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(.body, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Text("\(count)张")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.systemGray6), in: Capsule())
        }
        .padding(.vertical, 4)
    }
}
