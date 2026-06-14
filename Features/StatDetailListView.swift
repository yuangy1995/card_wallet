import SwiftUI

struct StatDetailListView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    let type: StatDetailType
    let cards: [SharedCard]

    @State private var cardToEdit: SharedCard? = nil
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

    private var creditCards: [SharedCard] {
        cards.filter { $0.cardCategory != "debit" }
    }

    private var groupedByBank: [String: [SharedCard]] {
        Dictionary(grouping: cards, by: { $0.bank })
    }

    private var groupedByCountry: [String: [SharedCard]] {
        Dictionary(grouping: cards, by: { $0.country })
    }

    private var filteredExpiryCards: [SharedCard] {
        creditCards.filter { card in
            guard let status = DateCalculator.cardExpiryStatus(valid: card.valid) else { return false }
            return status == .expired || status == .soonExpiring
        }
    }

    var body: some View {
        List {
            switch type {
            case .bank:
                ForEach(groupedByBank.keys.sorted(), id: \.self) { bank in
                    Section(header: Text("\(bank) (\(groupedByBank[bank]?.count ?? 0)张)")) {
                        ForEach(groupedByBank[bank] ?? []) { card in
                            cardRow(card)
                        }
                    }
                }
            case .country:
                ForEach(groupedByCountry.keys.sorted(), id: \.self) { country in
                    Section(header: Text("\(country) (\(groupedByCountry[country]?.count ?? 0)张)")) {
                        ForEach(groupedByCountry[country] ?? []) { card in
                            cardRow(card)
                        }
                    }
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
        NavigationLink {
            CardDetailView(
                card: card,
                onEdit: { cardToEdit = $0 },
                onDelete: { cardToDelete in
                    var current = syncCoordinator.cards
                    current.removeAll { $0.id == cardToDelete.id }
                    syncCoordinator.commit(cards: current, deletedCardIDs: [cardToDelete.id])
                }
            )
        } label: {
            CreditCardMiniView(card: card)
        }
    }
}
