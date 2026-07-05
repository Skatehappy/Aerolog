import Foundation

/// Structured detail stored in `CurrencySnapshot.detailJSON`.
struct CurrencyDetailPayload: Codable, Equatable, Sendable {
    var regulationReference: String?
    var requiredLandings: Int?
    var requiredNightLandings: Int?
    var requiredApproaches: Int?
    var requiredHolds: Int?
    var requiredFlightHours: Double?

    var countedLandings: Int?
    var countedNightLandings: Int?
    var countedFullStopLandings: Int?
    var countedApproaches: Int?
    var countedHolds: Int?
    var countedFlightHours: Double?

    var qualifyingEvents: [QualifyingEvent]?
    var daysRemaining: Int?
    var progressFraction: Double?

    var lastQualifyingDate: Date?
    var nextRequiredAction: String?
}

struct QualifyingEvent: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var date: Date
    var description: String
    var flightSyncID: UUID?
    var contribution: String

    init(
        id: UUID = UUID(),
        date: Date,
        description: String,
        flightSyncID: UUID? = nil,
        contribution: String
    ) {
        self.id = id
        self.date = date
        self.description = description
        self.flightSyncID = flightSyncID
        self.contribution = contribution
    }
}