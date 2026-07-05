import Foundation
import SwiftData

/// Instrument approach logged for IFR currency (61.57(c)).
@Model
final class InstrumentApproach {
    var approachType: ApproachType
    var airportICAO: String?
    var runway: String?
    var approachCount: Int
    var notes: String?

    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var flight: Flight?

    init(
        approachType: ApproachType = .ils,
        airportICAO: String? = nil,
        approachCount: Int = 1
    ) {
        self.approachType = approachType
        self.airportICAO = airportICAO
        self.approachCount = approachCount
        self.createdAt = .now
    }
}