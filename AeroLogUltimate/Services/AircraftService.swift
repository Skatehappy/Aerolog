import Foundation
import SwiftData

/// Data access helpers for aircraft fleet management.
@MainActor
struct AircraftService {
    let dataStore: DataStore

    func allAircraft(activeOnly: Bool = true, includeSimulators: Bool = true) throws -> [Aircraft] {
        var descriptor = FetchDescriptor<Aircraft>(
            sortBy: [SortDescriptor(\.registration), SortDescriptor(\.make)]
        )
        let aircraft = try dataStore.fetch(descriptor)
        return aircraft.filter { item in
            if activeOnly && !item.isActive { return false }
            if !includeSimulators && item.isSimulator { return false }
            return true
        }
    }

    func aircraft(syncID: UUID) throws -> Aircraft? {
        try allAircraft(activeOnly: false).first { $0.syncMetadata?.syncID == syncID }
    }

    @discardableResult
    func create(
        registration: String,
        make: String,
        model: String,
        category: AircraftCategory = .airplane,
        aircraftClass: AircraftClass = .singleEngineLand,
        simulatorLevel: SimulatorLevel = .none
    ) throws -> Aircraft {
        let aircraft = Aircraft(
            registration: registration,
            make: make,
            model: model,
            category: category,
            aircraftClass: aircraftClass,
            simulatorLevel: simulatorLevel
        )
        dataStore.insert(aircraft)
        try dataStore.save()
        return aircraft
    }

    func save(_ aircraft: Aircraft) throws {
        aircraft.touch()
        try dataStore.save()
    }

    func deactivate(_ aircraft: Aircraft) throws {
        aircraft.isActive = false
        aircraft.touch()
        try dataStore.save()
    }

    func reactivate(_ aircraft: Aircraft) throws {
        aircraft.isActive = true
        aircraft.touch()
        try dataStore.save()
    }
}