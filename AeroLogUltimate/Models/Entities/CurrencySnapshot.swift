import Foundation
import SwiftData

/// Point-in-time computed currency status for a pilot and requirement.
///
/// Populated by the currency engine in Phase 2; stored here for offline dashboard reads.
@Model
final class CurrencySnapshot {
    var status: CurrencyStatus
    var calculatedAt: Date
    var expiresAt: Date?
    var windowStartDate: Date?
    var windowEndDate: Date?

    /// JSON-encoded detail payload (landing counts, approach breakdown, etc.).
    var detailJSON: String?

    var summaryText: String?
    var warningText: String?

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    @Relationship(deleteRule: .nullify)
    var pilot: PilotProfile?

    @Relationship(deleteRule: .nullify)
    var requirement: CurrencyRequirement?

    init(
        status: CurrencyStatus = .unknown,
        calculatedAt: Date = .now
    ) {
        self.status = status
        self.calculatedAt = calculatedAt
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}