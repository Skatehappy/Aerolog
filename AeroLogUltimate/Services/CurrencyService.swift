import Foundation
import SwiftData

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

        let requirements = try enabledRequirements()
        let flights = try qualifyingFlights(for: profile)
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
        return CurrencyDashboardSummary(calculatedAt: .now, results: results.sorted { $0.requirementName < $1.requirementName })
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
            .filter { $0.student?.persistentModelID == pilot.persistentModelID && $0.status == .signed }
    }

    static func decodeDetail(from snapshot: CurrencySnapshot) -> CurrencyDetailPayload? {
        guard let json = snapshot.detailJSON,
              let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CurrencyDetailPayload.self, from: data)
    }
}