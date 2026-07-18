import Foundation
import SwiftData

/// Errors surfaced by the currency service so callers can report them instead of
/// failing silently (the recurring silent-`try?` bug class).
enum CurrencyServiceError: LocalizedError {
    case requirementNotFound
    var errorDescription: String? {
        switch self {
        case .requirementNotFound:
            "Couldn't find that currency requirement to update. Pull to refresh and try again."
        }
    }
}

/// Orchestrates currency calculation, snapshot persistence, and dashboard queries.
@MainActor
final class CurrencyService {
    let dataStore: DataStore
    private let engine: CurrencyEngine

    init(dataStore: DataStore, referenceDate: Date = .now) {
        self.dataStore = dataStore
        self.engine = CurrencyEngine(referenceDate: referenceDate)
    }

    // MARK: - Dashboard

    func calculateDashboard(for pilot: PilotProfile? = nil) throws -> CurrencyDashboardSummary {
        try dataStore.ensureBuiltInCurrencyRequirements()

        let profile = try pilot ?? dataStore.primaryPilotProfile()
        guard let profile else {
            return CurrencyDashboardSummary(calculatedAt: .now, results: [])
        }

        let flights = try qualifyingFlights(for: profile)
        // C4: auto-create per-class/category currency instances from the pilot's
        // ratings AND the flights present, then deprecate legacy unscoped built-ins.
        // Ratings-based creation lets a new user who hasn't imported a logbook still
        // see (and add) all the currencies for the classes they're rated in.
        try ensureScopedRequirements(pilot: profile, flights: flights)

        let requirements = try enabledRequirements()
        let endorsements = try endorsements(for: profile)

        var results: [CurrencyCalculationResult] = []
        var instrumentCurrent = false

        for requirement in requirements where requirement.currencyType != .instrumentProficiencyCheck {
            let result = engine.calculate(
                requirement: requirement,
                pilot: profile,
                flights: flights,
                endorsements: endorsements
            )
            if requirement.currencyType == .instrument {
                instrumentCurrent = result.status == .current
            }
            results.append(result)
        }

        if let ipcRequirement = requirements.first(where: { $0.currencyType == .instrumentProficiencyCheck }) {
            let ipcResult = engine.calculate(
                requirement: ipcRequirement,
                pilot: profile,
                flights: flights,
                endorsements: endorsements,
                instrumentCurrencyCurrent: instrumentCurrent
            )
            results.append(ipcResult)
        }

        try persistSnapshots(results, pilot: profile, requirements: requirements)
        return CurrencyDashboardSummary(
            calculatedAt: .now,
            results: results.sorted { $0.requirementName < $1.requirementName },
            anomalyWarnings: anomalyWarnings(profile: profile, flights: flights)
        )
    }

    // MARK: - C4 scoped requirements + anomaly sweep

    private func flightHasInstrumentActivity(_ flight: Flight) -> Bool {
        flight.actualInstrumentTime > 0
            || flight.simulatedInstrumentTime > 0
            || !(flight.approaches ?? []).isEmpty
    }

    /// C4: ensure a per-class Passenger Carrying (Day/Night) requirement exists for
    /// every class flown, and a per-category Instrument requirement for every
    /// category with instrument activity. On first scoped run, deprecate the legacy
    /// unscoped built-ins (isEnabled = false; never deleted — snapshots reference
    /// them), carrying their user-edited reminderLeadDays onto the new instances.
    /// Classes the pilot is rated in (so their currencies appear without needing
    /// logged flights). ASEL is the base airplane class with no distinct stored
    /// rating — include it when the pilot flies airplanes (holds an airplane class
    /// or airplane-instrument rating) or hasn't set any ratings yet.
    private func ratedClasses(for pilot: PilotProfile) -> Set<AircraftClass> {
        let ratings = Set(pilot.ratings)
        var classes = Set<AircraftClass>()
        for cls in AircraftClass.allCases {
            if let rating = cls.matchingRating, ratings.contains(rating) { classes.insert(cls) }
        }
        let airplaneIndicators: Set<PilotRating> = [.multiEngineLand, .multiEngineSea, .singleEngineSea, .instrumentAirplane]
        if ratings.isEmpty || !ratings.isDisjoint(with: airplaneIndicators) {
            classes.insert(.singleEngineLand)
        }
        return classes
    }

    private func ratedInstrumentCategories(for pilot: PilotProfile) -> Set<AircraftCategory> {
        let ratings = Set(pilot.ratings)
        var categories = Set<AircraftCategory>()
        if ratings.contains(.instrumentAirplane) { categories.insert(.airplane) }
        if ratings.contains(.instrumentHelicopter) { categories.insert(.rotorcraft) }
        return categories
    }

    private func ensureScopedRequirements(pilot: PilotProfile, flights: [Flight]) throws {
        let all = try allRequirements()
        let classesPresent = Set(flights.compactMap { $0.aircraft?.aircraftClass })
            .union(ratedClasses(for: pilot))
        let instrumentCategories = Set(
            flights.filter(flightHasInstrumentActivity).compactMap { $0.aircraft?.category }
        ).union(ratedInstrumentCategories(for: pilot))
        guard !classesPresent.isEmpty || !instrumentCategories.isEmpty else { return }

        let legacyDay = all.first { $0.currencyType == .passengerCarryingDay && $0.applicableClass == nil && $0.isBuiltIn }
        let legacyNight = all.first { $0.currencyType == .passengerCarryingNight && $0.applicableClass == nil && $0.isBuiltIn }
        let legacyInstrument = all.first { $0.currencyType == .instrument && $0.applicableCategory == nil && $0.isBuiltIn }

        var changed = false

        for cls in classesPresent {
            if !all.contains(where: { $0.currencyType == .passengerCarryingDay && $0.applicableClass == cls }) {
                let req = CurrencyRequirement(currencyType: .passengerCarryingDay, displayName: "Passenger Carrying (Day) — \(cls.abbreviation)", lookbackDays: 90, isBuiltIn: true)
                req.applicableClass = cls
                req.requiredLandings = 3
                req.reminderLeadDays = legacyDay?.reminderLeadDays ?? req.reminderLeadDays
                dataStore.insert(req); changed = true
            }
            if !all.contains(where: { $0.currencyType == .passengerCarryingNight && $0.applicableClass == cls }) {
                let req = CurrencyRequirement(currencyType: .passengerCarryingNight, displayName: "Passenger Carrying (Night) — \(cls.abbreviation)", lookbackDays: 90, isBuiltIn: true)
                req.applicableClass = cls
                req.requiredNightLandings = 3
                req.reminderLeadDays = legacyNight?.reminderLeadDays ?? req.reminderLeadDays
                dataStore.insert(req); changed = true
            }
        }

        for cat in instrumentCategories {
            if !all.contains(where: { $0.currencyType == .instrument && $0.applicableCategory == cat }) {
                let req = CurrencyRequirement(currencyType: .instrument, displayName: "Instrument Currency — \(cat.displayName)", lookbackDays: 180, isBuiltIn: true)
                req.applicableCategory = cat
                req.requiredApproaches = 6
                req.reminderLeadDays = legacyInstrument?.reminderLeadDays ?? req.reminderLeadDays
                dataStore.insert(req); changed = true
            }
        }

        if !classesPresent.isEmpty {
            for legacy in [legacyDay, legacyNight].compactMap({ $0 }) where legacy.isEnabled {
                legacy.isEnabled = false; changed = true
            }
        }
        if !instrumentCategories.isEmpty, let legacyInstrument, legacyInstrument.isEnabled {
            legacyInstrument.isEnabled = false; changed = true
        }

        if changed { try dataStore.save() }
    }

    /// WS1.7: informational anomalies — PIC time logged in a class the pilot does
    /// not hold a rating for. Does not block or modify data.
    private func anomalyWarnings(profile: PilotProfile, flights: [Flight]) -> [String] {
        let ratings = Set(profile.ratings)
        var flaggedClasses: Set<AircraftClass> = []
        var warnings: [String] = []
        for flight in flights where flight.picTime > 0 {
            guard let cls = flight.aircraft?.aircraftClass,
                  let rating = cls.matchingRating,
                  !ratings.contains(rating),
                  !flaggedClasses.contains(cls) else { continue }
            flaggedClasses.insert(cls)
            warnings.append("PIC time is logged in \(cls.displayName) but that rating isn't on your pilot profile.")
        }
        return warnings
    }

    func result(for requirement: CurrencyRequirement, pilot: PilotProfile) throws -> CurrencyCalculationResult {
        let flights = try qualifyingFlights(for: pilot)
        let endorsements = try endorsements(for: pilot)
        let requirements = try enabledRequirements()
        let instrumentCurrent = requirements
            .first { $0.currencyType == .instrument }
            .map { engine.calculate(requirement: $0, pilot: pilot, flights: flights, endorsements: endorsements).status == .current }
            ?? false

        return engine.calculate(
            requirement: requirement,
            pilot: pilot,
            flights: flights,
            endorsements: endorsements,
            instrumentCurrencyCurrent: instrumentCurrent
        )
    }

    // MARK: - Requirements CRUD

    func allRequirements() throws -> [CurrencyRequirement] {
        let descriptor = FetchDescriptor<CurrencyRequirement>(
            sortBy: [SortDescriptor(\.displayName)]
        )
        return try dataStore.fetch(descriptor)
    }

    func enabledRequirements() throws -> [CurrencyRequirement] {
        try allRequirements().filter(\.isEnabled)
    }

    @discardableResult
    func createCustomRequirement(
        name: String,
        lookbackDays: Int,
        requiredLandings: Int? = nil,
        requiredNightLandings: Int? = nil,
        requiredApproaches: Int? = nil,
        requiredFlightHours: Double? = nil
    ) throws -> CurrencyRequirement {
        let requirement = CurrencyRequirement(
            currencyType: .custom,
            displayName: name,
            lookbackDays: lookbackDays,
            isBuiltIn: false
        )
        requirement.requiredLandings = requiredLandings
        requirement.requiredNightLandings = requiredNightLandings
        requirement.requiredApproaches = requiredApproaches
        requirement.requiredFlightHours = requiredFlightHours
        dataStore.insert(requirement)
        try dataStore.save()
        return requirement
    }

    func saveRequirement(_ requirement: CurrencyRequirement) throws {
        requirement.touch()
        try dataStore.save()
    }

    /// Manual "current as of" attestation (import-failed fallback). Pass nil to clear.
    func setManualCurrentDate(_ date: Date?, forRequirementSyncID syncID: UUID) throws {
        guard let requirement = try allRequirements().first(where: { $0.syncMetadata?.syncID == syncID }) else {
            // Previously returned silently, so a failed attestation looked like a no-op.
            throw CurrencyServiceError.requirementNotFound
        }
        requirement.manualCurrentDate = date
        requirement.touch()
        try dataStore.save()
    }

    func deleteRequirement(_ requirement: CurrencyRequirement) throws {
        guard !requirement.isBuiltIn else { return }
        dataStore.delete(requirement)
        try dataStore.save()
    }

    // MARK: - Persistence

    private func persistSnapshots(
        _ results: [CurrencyCalculationResult],
        pilot: PilotProfile,
        requirements: [CurrencyRequirement]
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        for result in results {
            guard let requirement = requirements.first(where: { $0.syncMetadata?.syncID == result.requirementSyncID }) else {
                continue
            }

            let existing = (pilot.currencySnapshots ?? []).first {
                $0.requirement?.persistentModelID == requirement.persistentModelID
            }

            let snapshot = existing ?? CurrencySnapshot(status: result.status, calculatedAt: result.calculatedAt)
            snapshot.status = result.status
            snapshot.calculatedAt = result.calculatedAt
            snapshot.expiresAt = result.expiresAt
            snapshot.windowStartDate = result.windowStartDate
            snapshot.windowEndDate = result.windowEndDate
            snapshot.summaryText = result.summaryText
            snapshot.warningText = result.warningText
            snapshot.pilot = pilot
            snapshot.requirement = requirement

            if let data = try? encoder.encode(result.detail),
               let json = String(data: data, encoding: .utf8) {
                snapshot.detailJSON = json
            }

            if existing == nil {
                dataStore.insert(snapshot)
            }
            snapshot.touch()
        }
        try dataStore.save()
    }

    // MARK: - Data Access

    private func qualifyingFlights(for pilot: PilotProfile) throws -> [Flight] {
        try dataStore.fetch(FetchDescriptor<Flight>())
            .filter { CurrencyEngine.qualifyingFlights(from: [$0], pilot: pilot).count == 1 }
    }

    private func endorsements(for pilot: PilotProfile) throws -> [Endorsement] {
        try dataStore.fetch(FetchDescriptor<Endorsement>())
            .filter {
                $0.student?.persistentModelID == pilot.persistentModelID
                    && $0.status == .signed
                    // C3: exclude soft-deleted endorsements — a deleted flight
                    // review / IPC must stop granting currency (every other read
                    // path filters this; this one didn't).
                    && !($0.syncMetadata?.isSoftDeleted ?? false)
            }
    }

    static func decodeDetail(from snapshot: CurrencySnapshot) -> CurrencyDetailPayload? {
        guard let json = snapshot.detailJSON,
              let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CurrencyDetailPayload.self, from: data)
    }
}