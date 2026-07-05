import XCTest
@testable import AeroLogUltimate

final class FlightValidationTests: XCTestCase {
    func testTimeFormattingParsesDecimalAndColon() {
        XCTAssertEqual(TimeFormatting.parse("1.5"), 1.5)
        XCTAssertEqual(TimeFormatting.parse("1:30"), 1.5)
        XCTAssertEqual(TimeFormatting.display(1.5), "1.5")
    }
    func testFinalizeRequiresTime() {
        let flight = Flight()
        let result = FlightValidation.validateForFinalize(flight)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("time") }))
    }

    func testFinalizeRequiresAircraft() {
        let flight = Flight()
        flight.totalTime = 1.0
        let result = FlightValidation.validateForFinalize(flight)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("aircraft") }))
    }

    func testValidFlightPasses() {
        let flight = Flight()
        flight.totalTime = 1.5
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        let aircraft = Aircraft(registration: "N12345", make: "Cessna", model: "172")
        flight.aircraft = aircraft
        let result = FlightValidation.validateForFinalize(flight)
        XCTAssertTrue(result.isValid)
    }
}