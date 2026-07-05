import Foundation

/// Structured filters produced by natural language or advanced search.
struct FlightSearchCriteria: Sendable, Equatable {
    var textTokens: [String] = []
    var departureICAO: String?
    var arrivalICAO: String?
    var aircraftRegistration: String?
    var role: FlightRole?
    var status: FlightStatus?
    var pinnedOnly: Bool = false
    var favoritesOnly: Bool = false
    var minimumTotalTime: Double?
    var maximumTotalTime: Double?
    var minimumNightTime: Double?
    var requiresNightCondition: Bool = false
    var requiresCrossCountry: Bool = false
    var dateRange: ClosedRange<Date>?

    var isEmpty: Bool {
        textTokens.isEmpty
            && departureICAO == nil
            && arrivalICAO == nil
            && aircraftRegistration == nil
            && role == nil
            && status == nil
            && !pinnedOnly
            && !favoritesOnly
            && minimumTotalTime == nil
            && maximumTotalTime == nil
            && minimumNightTime == nil
            && !requiresNightCondition
            && !requiresCrossCountry
            && dateRange == nil
    }
}