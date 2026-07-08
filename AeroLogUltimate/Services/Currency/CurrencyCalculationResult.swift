import Foundation

/// In-memory result from the currency engine before persisting to SwiftData.
struct CurrencyCalculationResult: Identifiable, Equatable, Sendable {
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
    /// C4: class/category this result is scoped to (nil for unscoped/legacy rules),
    /// so the dashboard can group by class and category.
    var applicableClass: AircraftClass? = nil
    var applicableCategory: AircraftCategory? = nil
    /// Manual "current as of" attestation on the requirement, surfaced so the
    /// detail view can display and clear it.
    var manualCurrentDate: Date? = nil

    var isActionRequired: Bool {
        status == .expired || status == .expiringSoon
    }
}

/// Dashboard-level aggregate across all calculated currencies.
struct CurrencyDashboardSummary: Sendable {
    let calculatedAt: Date
    let results: [CurrencyCalculationResult]
    /// WS1.7 anomaly sweep — informational notices (e.g. PIC time in a class the
    /// pilot doesn't hold). Does not block or modify data.
    var anomalyWarnings: [String] = []

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