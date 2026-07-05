import Foundation
import SwiftData

/// Data access helpers for flight logbook operations.
@MainActor
struct FlightService {
    let dataStore: DataStore

    func allFlights(includeDrafts: Bool = true) throws -> [Flight] {
        var descriptor = FetchDescriptor<Flight>(
            sortBy: [SortDescriptor(\.flightDate, order: .reverse)]
        )
        let flights = try dataStore.fetch(descriptor)
        return flights.filter { flight in
            let notDeleted = !(flight.syncMetadata?.isSoftDeleted ?? false)
            if includeDrafts { return notDeleted }
            return notDeleted && flight.status == .finalized
        }
    }

    func flight(syncID: UUID) throws -> Flight? {
        let flights = try allFlights()
        return flights.first { $0.syncMetadata?.syncID == syncID }
    }

    @discardableResult
    func createDraft(
        date: Date = .now,
        role: FlightRole = UserPreferences.shared.defaultFlightRole,
        pilot: PilotProfile? = nil
    ) throws -> Flight {
        let flight = Flight(flightDate: date, status: .draft, role: role)
        if let pilot {
            flight.pilot = pilot
        } else {
            flight.pilot = try dataStore.primaryPilotProfile()
        }
        dataStore.insert(flight)
        try dataStore.save()
        return flight
    }

    func save(_ flight: Flight) throws {
        if flight.status == .finalized {
            flight.recordEditHistory(action: "Edited finalized entry")
        }
        flight.touch()
        try dataStore.save()
    }

    func finalize(_ flight: Flight) throws {
        let validation = FlightValidation.validateForFinalize(flight)
        guard validation.isValid else {
            throw FlightServiceError.validationFailed(validation.errors)
        }
        flight.syncRouteFromLegs()
        flight.finalize()
        try dataStore.save()
    }

    func revertToDraft(_ flight: Flight) throws {
        flight.revertToDraft()
        try dataStore.save()
    }

    func delete(_ flight: Flight, force: Bool = false) throws {
        let isFinalized = flight.isFinalized
        if isFinalized && !force {
            throw FlightServiceError.finalizedDeleteRequiresConfirmation
        }
        if let metadata = flight.syncMetadata {
            metadata.softDelete()
        } else {
            dataStore.delete(flight)
        }
        try dataStore.save()
    }

    func permanentlyDelete(_ flight: Flight) throws {
        if let attachments = flight.attachments {
            for attachment in attachments {
                try? AttachmentStorageService().delete(relativePath: attachment.relativeStoragePath)
            }
        }
        dataStore.delete(flight)
        try dataStore.save()
    }

    // MARK: - Legs

    @discardableResult
    func addLeg(to flight: Flight) throws -> FlightLeg {
        let order = flight.legs?.count ?? 0
        let leg = FlightLeg(
            legOrder: order,
            departureICAO: order == 0 ? flight.departureICAO : (flight.sortedLegs.last?.arrivalICAO ?? ""),
            arrivalICAO: ""
        )
        leg.flight = flight
        dataStore.insert(leg)
        flight.touch()
        try dataStore.save()
        return leg
    }

    func removeLeg(_ leg: FlightLeg, from flight: Flight) throws {
        dataStore.delete(leg)
        reorderLegs(in: flight)
        flight.syncRouteFromLegs()
        flight.touch()
        try dataStore.save()
    }

    func reorderLegs(in flight: Flight) {
        let sorted = flight.sortedLegs
        for (index, leg) in sorted.enumerated() {
            leg.legOrder = index
        }
    }

    // MARK: - Approaches

    @discardableResult
    func addApproach(to flight: Flight, type: ApproachType = .ils) throws -> InstrumentApproach {
        let approach = InstrumentApproach(approachType: type, airportICAO: flight.arrivalICAO)
        approach.flight = flight
        dataStore.insert(approach)
        flight.touch()
        try dataStore.save()
        return approach
    }

    func removeApproach(_ approach: InstrumentApproach, from flight: Flight) throws {
        dataStore.delete(approach)
        flight.touch()
        try dataStore.save()
    }

    // MARK: - Weight & Balance

    @discardableResult
    func ensureWeightBalanceLog(for flight: Flight) throws -> WeightBalanceLog {
        if let existing = flight.weightBalanceLog { return existing }
        let log = WeightBalanceLog()
        log.flight = flight
        dataStore.insert(log)
        flight.touch()
        try dataStore.save()
        return log
    }

    func updateWeightBalance(_ log: WeightBalanceLog) throws {
        WeightBalanceCalculator.apply(to: log)
        log.touch()
        log.flight?.touch()
        try dataStore.save()
    }

    // MARK: - Sorting

    static func sortedForDisplay(_ flights: [Flight]) -> [Flight] {
        flights.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
            return lhs.flightDate > rhs.flightDate
        }
    }
}

enum FlightServiceError: LocalizedError {
    case validationFailed([String])
    case finalizedDeleteRequiresConfirmation
    case notFound

    var errorDescription: String? {
        switch self {
        case .validationFailed(let errors):
            errors.joined(separator: "\n")
        case .finalizedDeleteRequiresConfirmation:
            "This finalized entry requires confirmation before deletion."
        case .notFound:
            "Flight not found."
        }
    }
}