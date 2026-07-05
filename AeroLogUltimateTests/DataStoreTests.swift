import XCTest
import SwiftData
@testable import AeroLogUltimate

@MainActor
final class DataStoreTests: XCTestCase {
    func testSeedCreatesPrimaryPilotAndCurrencyRequirements() throws {
        let store = try DataStore.makeInMemory()

        let pilot = try store.primaryPilotProfile()
        XCTAssertNotNil(pilot)
        XCTAssertTrue(pilot?.isPrimaryProfile == true)

        let requirements = try store.fetch(FetchDescriptor<CurrencyRequirement>())
        XCTAssertFalse(requirements.isEmpty)
        XCTAssertTrue(requirements.contains { $0.currencyType == .passengerCarryingDay })
    }

    func testFlightServiceCreatesDraft() throws {
        let store = try DataStore.makeInMemory()
        let service = FlightService(dataStore: store)

        let flight = try service.createDraft()
        XCTAssertEqual(flight.status, .draft)
        XCTAssertNotNil(flight.pilot)
    }

    func testAircraftServiceCreatesAircraft() throws {
        let store = try DataStore.makeInMemory()
        let service = AircraftService(dataStore: store)

        let aircraft = try service.create(
            registration: "N12345",
            make: "Cessna",
            model: "172S"
        )
        XCTAssertEqual(aircraft.registration, "N12345")
        XCTAssertTrue(aircraft.isActive)
    }
}