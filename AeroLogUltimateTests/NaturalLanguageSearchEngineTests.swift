import XCTest
@testable import AeroLogUltimate

final class NaturalLanguageSearchEngineTests: XCTestCase {
    func testParsesPinnedAndNightPIC() {
        let criteria = NaturalLanguageSearchEngine.parse("pinned night PIC last month")
        XCTAssertTrue(criteria.pinnedOnly)
        XCTAssertTrue(criteria.requiresNightCondition)
        XCTAssertEqual(criteria.role, .pic)
        XCTAssertNotNil(criteria.dateRange)
    }

    func testParsesICAOAndTailNumber() {
        let criteria = NaturalLanguageSearchEngine.parse("to kord n12345")
        XCTAssertEqual(criteria.arrivalICAO, "KORD")
        XCTAssertEqual(criteria.aircraftRegistration, "N12345")
    }

    func testMatchesMinimumHours() {
        let flight = Flight()
        flight.totalTime = 2.5
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        let criteria = NaturalLanguageSearchEngine.parse("over 2 hours")
        XCTAssertEqual(criteria.minimumTotalTime, 2)
        XCTAssertTrue(NaturalLanguageSearchEngine.matches(flight, criteria: criteria))
    }

    @MainActor
    func testPinnedFlightsSortFirst() {
        let recent = Flight(flightDate: .now)
        recent.isPinned = false
        let pinned = Flight(flightDate: .now.addingTimeInterval(-86400))
        pinned.isPinned = true
        let sorted = FlightService.sortedForDisplay([recent, pinned])
        XCTAssertTrue(sorted.first?.isPinned == true)
    }
}