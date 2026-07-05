import XCTest
@testable import AeroLogUltimate

@MainActor
final class FlightEditHistoryTests: XCTestCase {
    func testFinalizedFlightEditAppendsAuditTrail() throws {
        let store = try DataStore.makeInMemory()
        let service = FlightService(dataStore: store)
        let aircraft = Aircraft(registration: "N12345", make: "Cessna", model: "172")

        let flight = try service.createDraft()
        flight.aircraft = aircraft
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        flight.totalTime = 1.0
        flight.picTime = 1.0
        try service.finalize(flight)

        flight.remarks = "Corrected remarks"
        try service.save(flight)

        XCTAssertEqual(flight.editHistory.count, 1)
        XCTAssertEqual(flight.editHistory.first?.action, "Edited finalized entry")
    }

    func testRevertToDraftRecordsAuditTrail() throws {
        let store = try DataStore.makeInMemory()
        let service = FlightService(dataStore: store)
        let aircraft = Aircraft(registration: "N12345", make: "Cessna", model: "172")

        let flight = try service.createDraft()
        flight.aircraft = aircraft
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        flight.totalTime = 1.0
        flight.picTime = 1.0
        try service.finalize(flight)
        try service.revertToDraft(flight)

        XCTAssertEqual(flight.editHistory.count, 1)
        XCTAssertEqual(flight.editHistory.first?.action, "Reverted to draft")
        XCTAssertEqual(flight.editHistory.first?.previousStatus, FlightStatus.finalized.rawValue)
    }
}