import Foundation
import SwiftData
import os

/// Central data access layer for offline-first SwiftData operations.
@MainActor
final class DataStore {
    private let logger = Logger(subsystem: "com.aerologultimate", category: "DataStore")

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    /// Creates the production data store with seed data on first launch.
    static func makeProduction() throws -> DataStore {
        let container = try ModelContainerConfiguration.makeLocalContainer()
        let store = DataStore(container: container)
        try store.seedIfNeeded()
        // Repair installs that already have >1 primary profile from an earlier
        // restore (C2) so the app binds to the pilot that owns the flights.
        try store.reconcilePrimaryProfiles()
        return store
    }

    /// Creates an in-memory store for tests and SwiftUI previews.
    static func makeInMemory() throws -> DataStore {
        let container = try ModelContainerConfiguration.inMemory
        let store = DataStore(container: container)
        try store.seedIfNeeded()
        return store
    }

    // MARK: - Persistence

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    func rollback() {
        context.rollback()
    }

    // MARK: - Generic Fetch

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        try context.fetch(descriptor)
    }

    func fetchOne<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> T? {
        var descriptor = descriptor
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert<T: PersistentModel>(_ model: T) {
        context.insert(model)
    }

    func delete<T: PersistentModel>(_ model: T) {
        context.delete(model)
    }

    // MARK: - Seed Data

    /// Seeds built-in currency requirements and a primary pilot profile when the store is empty.
    private func seedIfNeeded() throws {
        let needsPilot = try fetchOne(FetchDescriptor<PilotProfile>()) == nil
        let needsCurrency = try fetch(FetchDescriptor<CurrencyRequirement>()).isEmpty
        guard needsPilot || needsCurrency else { return }

        logger.info("Seeding initial data")

        if needsPilot {
            let primaryPilot = PilotProfile(firstName: "", lastName: "", isPrimaryProfile: true)
            insert(primaryPilot)
        }

        if needsCurrency {
            try seedBuiltInCurrencyRequirements()
        }

        try save()
        UserPreferences.shared.hasCompletedInitialSeed = true
    }

    private func seedBuiltInCurrencyRequirements(missingOnly: Set<CurrencyType> = []) throws {
        let shouldInsert: (CurrencyType) -> Bool = { missingOnly.isEmpty || !missingOnly.contains($0) }

        var builtIns: [CurrencyRequirement] = []
        if shouldInsert(.passengerCarryingDay) {
        builtIns.append(
            CurrencyRequirement(
                currencyType: .passengerCarryingDay,
                displayName: "Passenger Carrying (Day)",
                lookbackDays: 90,
                isBuiltIn: true
            ))
        }
        if shouldInsert(.passengerCarryingNight) {
            builtIns.append(CurrencyRequirement(currencyType: .passengerCarryingNight, displayName: "Passenger Carrying (Night)", lookbackDays: 90, isBuiltIn: true))
        }
        if shouldInsert(.instrument) {
            builtIns.append(CurrencyRequirement(currencyType: .instrument, displayName: "Instrument Currency", lookbackDays: 180, isBuiltIn: true))
        }
        if shouldInsert(.tailwheel) {
            builtIns.append(CurrencyRequirement(currencyType: .tailwheel, displayName: "Tailwheel Currency", lookbackDays: 90, isBuiltIn: true))
        }
        if shouldInsert(.flightReview) {
            builtIns.append(CurrencyRequirement(currencyType: .flightReview, displayName: "Flight Review (BFR)", lookbackDays: 730, isBuiltIn: true))
        }
        if shouldInsert(.instrumentProficiencyCheck) {
            builtIns.append(CurrencyRequirement(currencyType: .instrumentProficiencyCheck, displayName: "Instrument Proficiency Check", lookbackDays: 180, isBuiltIn: true))
        }
        if shouldInsert(.medical) {
            builtIns.append(CurrencyRequirement(currencyType: .medical, displayName: "Medical Certificate", lookbackDays: 0, isBuiltIn: true))
        }
        if shouldInsert(.cfiCertificate) {
            builtIns.append(CurrencyRequirement(currencyType: .cfiCertificate, displayName: "CFI Certificate", lookbackDays: 0, isBuiltIn: true))
        }
        if shouldInsert(.complex) {
            builtIns.append(CurrencyRequirement(currencyType: .complex, displayName: "Complex Aircraft Proficiency", lookbackDays: 90, isBuiltIn: true))
        }
        if shouldInsert(.highPerformance) {
            builtIns.append(CurrencyRequirement(currencyType: .highPerformance, displayName: "High Performance Proficiency", lookbackDays: 90, isBuiltIn: true))
        }
        if shouldInsert(.typeRating) {
            builtIns.append(CurrencyRequirement(currencyType: .typeRating, displayName: "Type Rating Proficiency", lookbackDays: 365, isBuiltIn: true))
        }

        for req in builtIns {
            switch req.currencyType {
            case .passengerCarryingDay: req.requiredLandings = 3
            case .passengerCarryingNight:
                req.requiredLandings = 3
                req.requiredNightLandings = 3
            case .instrument: req.requiredApproaches = 6
            case .tailwheel: req.requiredLandings = 3
            case .complex: req.requiredFlightHours = 0.5
            case .highPerformance: req.requiredFlightHours = 0.5
            case .typeRating:
                req.requiredFlightHours = 1.0
                req.notes = "Set type designator to match your type rating"
            default: break
            }
            insert(req)
        }
    }

    /// Inserts any built-in currency requirements missing from existing databases.
    func ensureBuiltInCurrencyRequirements() throws {
        let existing = try fetch(FetchDescriptor<CurrencyRequirement>())
        let existingTypes = Set(existing.map(\.currencyType))
        let beforeCount = existing.count
        try seedBuiltInCurrencyRequirements(missingOnly: existingTypes)
        if try fetch(FetchDescriptor<CurrencyRequirement>()).count > beforeCount {
            try save()
        }
    }

    // MARK: - Primary Pilot

    func primaryPilotProfile() throws -> PilotProfile? {
        let primaries = try context.fetch(FetchDescriptor<PilotProfile>(
            predicate: #Predicate { $0.isPrimaryProfile == true }
        ))
        if primaries.count > 1 {
            // Self-heal if two primaries ever coexist (e.g. a restore inserted a
            // second one before reconcile ran) so callers never bind to the wrong
            // pilot nondeterministically.
            return try reconcilePrimaryProfiles() ?? primaries.first
        }
        return primaries.first
    }

    /// Ensures exactly one primary pilot profile exists. `seedIfNeeded()` creates
    /// a blank primary on first launch; a backup restore can insert a second
    /// `isPrimaryProfile = true` pilot. With two primaries `primaryPilotProfile()`
    /// picked nondeterministically, so currency/reports/new-flights could bind to
    /// the blank pilot while history lived on the imported one. Keep the profile
    /// that owns flights (tie-break: one with a name), demote the rest.
    @discardableResult
    func reconcilePrimaryProfiles() throws -> PilotProfile? {
        let primaries = try context.fetch(FetchDescriptor<PilotProfile>(
            predicate: #Predicate { $0.isPrimaryProfile == true }
        ))
        guard primaries.count > 1 else { return primaries.first }

        var flightCount: [PersistentIdentifier: Int] = [:]
        for flight in try context.fetch(FetchDescriptor<Flight>()) {
            guard let pilotID = flight.pilot?.persistentModelID else { continue }
            flightCount[pilotID, default: 0] += 1
        }

        let keeper = primaries.max { lhs, rhs in
            let lc = flightCount[lhs.persistentModelID] ?? 0
            let rc = flightCount[rhs.persistentModelID] ?? 0
            if lc != rc { return lc < rc }
            let lNamed = !(lhs.firstName.isEmpty && lhs.lastName.isEmpty)
            let rNamed = !(rhs.firstName.isEmpty && rhs.lastName.isEmpty)
            return !lNamed && rNamed
        }
        for profile in primaries where profile.persistentModelID != keeper?.persistentModelID {
            profile.isPrimaryProfile = false
        }
        try save()
        return keeper
    }
}