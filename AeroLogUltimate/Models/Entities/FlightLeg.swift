import Foundation
import SwiftData

/// A single segment within a multi-leg flight.
@Model
final class FlightLeg {
    var legOrder: Int

    var departureICAO: String
    var arrivalICAO: String
    var routeSegment: String?

    /// Block or airborne time for this leg (decimal hours).
    var legTime: Double

    var departureTime: Date?
    var arrivalTime: Date?

    var notes: String?

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Flight.legs)
    var flight: Flight?

    init(
        legOrder: Int = 0,
        departureICAO: String = "",
        arrivalICAO: String = "",
        legTime: Double = 0
    ) {
        self.legOrder = legOrder
        self.departureICAO = departureICAO
        self.arrivalICAO = arrivalICAO
        self.legTime = legTime
        self.createdAt = .now
        self.updatedAt = .now
    }

    func touch() {
        updatedAt = .now
        flight?.touch()
    }
}