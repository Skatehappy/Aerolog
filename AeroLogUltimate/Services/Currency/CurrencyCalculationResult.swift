import Foundation

/// In-memory result from the currency engine before persisting to SwiftData.
struct CurrencyCalculationResult: Identifiable, Sendable {
    var id: UUID { requirementSyncID }
    let requirementSyncID: UUID
    let requirementName: String
    let currencyType: CurrencyType
    let status: CurrencyStatus
    let summaryText: String
    let warningText: String?
    let expiresAt: Date?
    let windowStartDate: Date?
    let windowEndDate: Date?
    let detail: CurrencyDetailPayload
    let calculatedAt: Date

    var isActionRequired: Bool {
        status == .expired || status == .expiringSoon
    }
}

/// Dashboard-level aggregate across all calculated currencies.
struct CurrencyDashboardSummary: Sendable {
    let calculatedAt: Date
    let results: [CurrencyCalculationResult]

    var currentCount: Int { results.filter { $0.status == .current }.count }
    var expiringSoonCount: Int { results.filter { $0.status == .expiringSoon }.count }
    var expiredCount: Int { results.filter { $0.status == .expired }.count }
    var unknownCount: Int { results.filter { $0.status == .unknown }.count }

    var attentionItems: [CurrencyCalculationResult] {
        results
            .filter { $0.status == .expired || $0.status == .expiringSoon }
            .sorted { lhs, rhs in
                priority(lhs.status) > priority(rhs.status)
            }
    }

    private func priority(_ status: CurrencyStatus) -> Int {
        switch status {
        case .expired: 3
        case .expiringSoon: 2
        default: 1
        }
    }
}