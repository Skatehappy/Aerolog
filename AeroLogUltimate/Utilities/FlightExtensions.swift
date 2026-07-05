import Foundation

extension Flight {
    /// Stable identifier for navigation and routing.
    var syncID: UUID {
        syncMetadata?.syncID ?? UUID()
    }

    var sortedLegs: [FlightLeg] {
        (legs ?? []).sorted { $0.legOrder < $1.legOrder }
    }

    var sortedAttachments: [Attachment] {
        (attachments ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var isDeleted: Bool {
        syncMetadata?.isSoftDeleted ?? false
    }

    var routeSummary: String {
        let legCount = legs?.count ?? 0
        if legCount > 1 {
            let first = sortedLegs.first?.departureICAO ?? departureICAO
            let last = sortedLegs.last?.arrivalICAO ?? arrivalICAO
            return "\(first) → \(last) (\(legCount) legs)"
        }
        if !departureICAO.isEmpty || !arrivalICAO.isEmpty {
            return "\(departureICAO) → \(arrivalICAO)"
        }
        return "No route"
    }

    var aircraftDisplay: String {
        aircraft?.displayName ?? "No aircraft"
    }

    /// Syncs single-leg route fields from the first/last leg when multi-leg is active.
    func syncRouteFromLegs() {
        let sorted = sortedLegs
        guard !sorted.isEmpty else { return }
        departureICAO = sorted.first?.departureICAO ?? departureICAO
        arrivalICAO = sorted.last?.arrivalICAO ?? arrivalICAO
        let totalLegTime = sorted.reduce(0) { $0 + $1.legTime }
        if totalLegTime > 0 && totalTime == 0 {
            totalTime = totalLegTime
        }
    }

    var usesMultiLeg: Bool {
        (legs?.count ?? 0) > 1
    }
}

extension Aircraft {
    var syncID: UUID {
        syncMetadata?.syncID ?? UUID()
    }

    var subtitle: String {
        if isSimulator {
            return "\(simulatorLevel.shortName) — \(make) \(model)"
        }
        return "\(make) \(model) — \(aircraftClass.displayName)"
    }
}