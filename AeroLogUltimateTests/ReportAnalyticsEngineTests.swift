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

    func testFlightLogRowIncludesAllFields() {
        let flight = Flight(flightDate: .now, status: .finalized, role: .dualReceived)
        flight.totalTime = 1.2
        flight.picTime = 0
        flight.sicTime = 0
        flight.dualReceived = 1.2
        flight.dualGiven = 0
        flight.soloTime = 0
        flight.nightTime = 0.3
        flight.crossCountryTime = 1.0
        flight.actualInstrumentTime = 0.2
        flight.simulatedInstrumentTime = 0.1
        flight.groundInstructionTime = 0.5
        flight.simulatorTime = 0
        flight.dayLandings = 2
        flight.nightLandings = 1
        flight.fullStopDayLandings = 1
        flight.fullStopNightLandings = 1
        flight.holds = 2
        flight.instructorName = "CFI Smith"
        flight.remarks = "Pattern work"
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KPAO"

        let rows = engine.flightLogRows(flights: [flight], filter: .allTime)
        XCTAssertEqual(rows.count, 1)
        let row = rows[0]
        XCTAssertEqual(row.dualReceived, 1.2)
        XCTAssertEqual(row.nightTime, 0.3)
        XCTAssertEqual(row.actualInstrumentTime, 0.2)
        XCTAssertEqual(row.groundInstructionTime, 0.5)
        XCTAssertEqual(row.fullStopDayLandings, 1)
        XCTAssertEqual(row.holds, 2)
        XCTAssertEqual(row.instructorName, "CFI Smith")
        XCTAssertEqual(row.role, .dualReceived)
    }

    func testFAA8710CategoryBreakdown() {
        let pilot = PilotProfile(firstName: "Applicant", lastName: "Pilot", certificateNumber: "1234567")
        let selAircraft = Aircraft(registration: "N12345", make: "Cessna", model: "172")
        selAircraft.category = .airplane
        selAircraft.aircraftClass = .singleEngineLand

        let melAircraft = Aircraft(registration: "N67890", make: "Piper", model: "Seneca")
        melAircraft.category = .airplane
        melAircraft.aircraftClass = .multiEngineLand

        let selFlight = Flight(flightDate: .now, status: .finalized, role: .pic)
        selFlight.aircraft = selAircraft
        selFlight.totalTime = 10.0
        selFlight.picTime = 10.0

        let melFlight = Flight(flightDate: .now, status: .finalized, role: .pic)
        melFlight.aircraft = melAircraft
        melFlight.totalTime = 5.0
        melFlight.picTime = 5.0

        let totals = engine.faa8710Totals(flights: [selFlight, melFlight], filter: .allTime, pilot: pilot)
        XCTAssertEqual(totals.totalTime, 15.0)
        XCTAssertEqual(totals.airplaneSingleEngineLand, 10.0)
        XCTAssertEqual(totals.airplaneMultiEngineLand, 5.0)
        XCTAssertEqual(totals.certificateNumber, "1234567")
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
            configuration: .defaultFor(.totalTimeSummary),
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

    func testCSVExportWithCustomColumns() throws {
        let flight = Flight(flightDate: .now, status: .finalized, role: .pic)
        flight.totalTime = 1.5
        flight.picTime = 1.5
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"

        let rows = engine.flightLogRows(flights: [flight], filter: .allTime)
        let config = ReportConfiguration(columns: [.date, .route, .picTime, .nightTime])
        let report = GeneratedReport(
            type: .flightLog,
            title: "Flight Log Export",
            filter: .allTime,
            format: .csv,
            configuration: config,
            generatedAt: .now,
            dashboard: nil, totalTime: nil, faa8710: nil,
            flightLog: rows, airports: nil, aircraft: nil,
            studentProgress: nil, currencyResults: nil
        )

        let text = String(data: try ReportExporter().export(report), encoding: .utf8)!
        XCTAssertTrue(text.contains("Date,Route,PIC,Night"))
        XCTAssertTrue(text.contains("KPAO"))
        XCTAssertFalse(text.contains("Dual Received"))
    }

    func testPDFExportProducesValidDocument() throws {
        let pilot = PilotProfile(firstName: "PDF", lastName: "Pilot", certificateNumber: "9999999")
        let flight = Flight(flightDate: .now, status: .finalized, role: .pic)
        flight.totalTime = 2.5
        flight.picTime = 2.5
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"

        let report = GeneratedReport(
            type: .faa8710,
            title: "FAA 8710 Totals",
            filter: .allTime,
            format: .pdf,
            configuration: .faaLogbook,
            generatedAt: .now,
            dashboard: nil,
            totalTime: nil,
            faa8710: engine.faa8710Totals(flights: [flight], filter: .allTime, pilot: pilot),
            flightLog: engine.flightLogRows(flights: [flight], filter: .allTime),
            airports: nil, aircraft: nil,
            studentProgress: nil, currencyResults: nil
        )

        let data = try ReportExporter().export(report)
        XCTAssertGreaterThan(data.count, 500)
        XCTAssertTrue(String(data: data.prefix(4), encoding: .ascii) == "%PDF")
    }

    func testReportConfigurationDefaults() {
        let flightLogConfig = ReportConfiguration.defaultFor(.flightLog)
        XCTAssertTrue(flightLogConfig.columns.contains(.date))
        XCTAssertTrue(flightLogConfig.columns.contains(.picTime))

        let resolved = ReportConfiguration(columns: []).resolvedColumns(for: .flightLog)
        XCTAssertFalse(resolved.isEmpty)
    }
}