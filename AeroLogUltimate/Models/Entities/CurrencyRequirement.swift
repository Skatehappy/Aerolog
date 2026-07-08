import Foundation
import SwiftData

/// Configurable currency rule — built-in FAA rules and user-defined custom rules.
@Model
final class CurrencyRequirement {
    var currencyType: CurrencyType
    var displayName: String
    var isEnabled: Bool
    var isBuiltIn: Bool

    /// Lookback window in days (e.g., 90 for passenger carrying).
    var lookbackDays: Int

    /// Minimum landings required within lookback (when applicable).
    var requiredLandings: Int?

    /// Minimum night landings required (when applicable).
    var requiredNightLandings: Int?

    /// Minimum approaches required (when applicable).
    var requiredApproaches: Int?

    /// Minimum flight time hours required (when applicable).
    var requiredFlightHours: Double?

    /// Category/class scoping for tailwheel, type rating, etc.
    var applicableCategory: AircraftCategory?
    var applicableClass: AircraftClass?
    var typeRatingDesignator: String?

    /// Reminder lead time in days before expiration.
    var reminderLeadDays: Int

    /// Manual self-attestation: the date the pilot states they last met this
    /// requirement, used when a logbook import failed/was incomplete so currency
    /// can be established without per-flight data. Blended with flight-computed
    /// currency (whichever expires later wins). Optional → additive migration.
    var manualCurrentDate: Date?

    var notes: String?

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    @Relationship(deleteRule: .nullify, inverse: \CurrencySnapshot.requirement)
    var snapshots: [CurrencySnapshot]?

    init(
        currencyType: CurrencyType,
        displayName: String,
        lookbackDays: Int = 90,
        isBuiltIn: Bool = false
    ) {
        self.currencyType = currencyType
        self.displayName = displayName
        self.lookbackDays = lookbackDays
        self.isBuiltIn = isBuiltIn
        self.isEnabled = true
        self.reminderLeadDays = 14
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}