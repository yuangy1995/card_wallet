import Foundation

struct SharedCard: Codable, Identifiable {
    let id: String
    let country: String
    let bank: String
    let cardNumber: String
    let lastModifyTime: String
    let isSharedLimit: Bool
    let billingDaySpendingToNextBill: Bool
}
