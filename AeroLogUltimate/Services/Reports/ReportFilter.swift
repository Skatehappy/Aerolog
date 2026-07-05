import Foundation

/// Filter criteria applied when generating reports and analytics.
struct ReportFilter: Codable, Sendable, Equatable {
    var startDate: Date?
    var endDate: Date?
    var aircraftSyncIDs: [UUID]?
    var roles: [FlightRole]?
    var finalizedOnly: Bool = true

    static let allTime = ReportFilter()

    func matches(_ flight: Flight) -> Bool {
        if finalizedOnly && flight.status != .finalized { return false }
        if flight.syncMetadata?.isSoftDeleted == true { return false }
        if let startDate, flight.flightDate < Calendar.current.startOfDay(for: startDate) { return false }
        if let endDate {
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            if flight.flightDate > endOfDay { return false }
        }
        if let ids = aircraftSyncIDs, !ids.isEmpty {
            guard let aircraft = flight.aircraft, ids.contains(aircraft.syncID) else { return false }
        }
        if let roles, !roles.isEmpty, !roles.contains(flight.role) { return false }
        return true
    }

    var displaySummary: String {
        var parts: [String] = []
        if let startDate, let endDate {
            parts.append("\(startDate.formatted(date: .abbreviated, time: .omitted)) – \(endDate.formatted(date: .abbreviated, time: .omitted))")
        } else if let startDate {
            parts.append("From \(startDate.formatted(date: .abbreviated, time: .omitted))")
        } else if let endDate {
            parts.append("Through \(endDate.formatted(date: .abbreviated, time: .omitted))")
        } else {
            parts.append("All time")
        }
        if finalizedOnly { parts.append("Finalized only") }
        return parts.joined(separator: " · ")
    }
}