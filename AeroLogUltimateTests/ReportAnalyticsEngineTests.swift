import XCTest
@testable import AeroLogUltimate

final class ReportAnalyticsEngineTests: XCTestCase {
    let engine = ReportAnalyticsEngine()

    func testTotalTimeSummary() {
        let pilot = PilotProfile(firstName: "Test", lastName: "Pilot", isPrimaryProfile: true)
        let flight = Flight(flightDate: .now, status: .finalized, role: .pic)
        flight.totalTime = 1.5
        flight.picTime = 1.5
        flight.dayLandings = 2
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"

        let summary = engine.totalTimeSummary(flights: [flight], filter: .allTime, pilot: pilot)
        XCTAssertEqual(summary.totalFlights, 1)
        XCTAssertEqual(summary.totalTime, 1.5)
        XCTAssertEqual(summary.picTime, 1.5)
        XCTAssertEqual(summary.dayLandings, 2)
    }

    func testAirportStatistics() {
        let flight = Flight(flightDate: .now, status: .finalized, role: .pic)
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        flight.totalTime = 0.8

        let stats = engine.airportStatistics(flights: [flight])
        XCTAssertEqual(stats.count, 2)
        XCTAssertTrue(stats.contains { $0.icao == "KPAO" })
        XCTAssertTrue(stats.contains { $0.icao == "KSQL" })
    }

    func testMonthlyBreakdown() {
        let flight = Flight(flightDate: .now, status: .finalized, role: .pic)
        flight.totalTime = 2.0
        let buckets = engine.monthlyBreakdown(flights: [flight])
        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets.first?.totalTime, 2.0)
    }

    func testFilterExcludesDrafts() {
        let pilot = PilotProfile(firstName: "Test", lastName: "Pilot")
        let draft = Flight(status: .draft, role: .pic)
        draft.totalTime = 5.0
        let finalized = Flight(status: .finalized, role: .pic)
        finalized.totalTime = 1.0

        var filter = ReportFilter()
        filter.finalizedOnly = true
        let summary = engine.totalTimeSummary(flights: [draft, finalized], filter: filter, pilot: pilot)
        XCTAssertEqual(summary.totalFlights, 1)
        XCTAssertEqual(summary.totalTime, 1.0)
    }

    func testCSVExport() throws {
        let pilot = PilotProfile(firstName: "Export", lastName: "Test")
        let flight = Flight(flightDate: .now, status: .finalized, role: .pic)
        flight.totalTime = 1.0
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KPAO"

        let report = GeneratedReport(
            type: .totalTimeSummary,
            title: "Total Time Summary",
            filter: .allTime,
            format: .csv,
            generatedAt: .now,
            dashboard: nil,
            totalTime: engine.totalTimeSummary(flights: [flight], filter: .allTime, pilot: pilot),
            faa8710: nil, flightLog: nil, airports: nil, aircraft: nil,
            studentProgress: nil, currencyResults: nil
        )

        let data = try ReportExporter().export(report)
        let text = String(data: data, encoding: .utf8)!
        XCTAssertTrue(text.contains("Total"))
        XCTAssertTrue(text.contains("1.0"))
    }
}