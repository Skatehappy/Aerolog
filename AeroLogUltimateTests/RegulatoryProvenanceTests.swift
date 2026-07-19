import XCTest
@testable import AeroLogUltimate

/// Phase 3 Regulatory Fix (2026-07-19) — locks the FAA regulatory constants AeroLog relies
/// on to their verified provenance record (RegulatoryConstants.plist), and pins the
/// complex/high-performance reframe: 14 CFR 61.31(e)/(f) are ONE-TIME endorsements with no
/// recurrency, so the tracker must never report a pilot as "Expired"/"Not current".
final class RegulatoryProvenanceTests: XCTestCase {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-06-15T12:00:00Z")!
    private lazy var engine = CurrencyEngine(referenceDate: referenceDate)

    // Load the provenance plist from the source tree (hermetic to app/test bundling).
    private func loadConstants() throws -> [String: Any] {
        let testFile = URL(fileURLWithPath: #filePath)
        let plistURL = testFile
            .deletingLastPathComponent()          // AeroLogUltimateTests/
            .deletingLastPathComponent()          // repo root
            .appendingPathComponent("AeroLogUltimate/Resources/RegulatoryConstants.plist")
        let data = try Data(contentsOf: plistURL)
        let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(obj as? [String: Any], "RegulatoryConstants.plist is not a dict")
    }

    // MARK: - Provenance

    func testProvenancePlistExistsAndVerified() throws {
        let c = try loadConstants()
        XCTAssertEqual(c["schemaVersion"] as? String, "1.0.0")
        XCTAssertEqual(c["verifiedOn"] as? String, "2026-07-19")
    }

    func testRecurrentCurrencyCitations() throws {
        let c = try loadConstants()
        let currencies = try XCTUnwrap(c["currencies"] as? [[String: Any]])
        let byId = Dictionary(uniqueKeysWithValues: currencies.map { ($0["id"] as? String ?? "", $0) })
        XCTAssertEqual(byId["passengerCarryingDay"]?["citation"] as? String, "14 CFR 61.57(a)")
        XCTAssertEqual(byId["passengerCarryingNight"]?["citation"] as? String, "14 CFR 61.57(b)")
        XCTAssertEqual(byId["instrument"]?["citation"] as? String, "14 CFR 61.57(c)")
        XCTAssertEqual(byId["flightReview"]?["citation"] as? String, "14 CFR 61.56")
        XCTAssertEqual(byId["passengerCarryingDay"]?["requiredLandings"] as? Int, 3)
        XCTAssertEqual(byId["instrument"]?["requiredApproaches"] as? Int, 6)
        XCTAssertEqual(byId["flightReview"]?["lookbackCalendarMonths"] as? Int, 24)
        // all genuine currencies are recurrent
        for cur in currencies { XCTAssertEqual(cur["recurrent"] as? Bool, true, "\(cur["id"] ?? "?") should be recurrent") }
    }

    func testBasicMedIntervalsProvenance() throws {
        let c = try loadConstants()
        let currencies = try XCTUnwrap(c["currencies"] as? [[String: Any]])
        let exam = currencies.first { $0["id"] as? String == "medicalBasicMedExam" }
        let course = currencies.first { $0["id"] as? String == "medicalBasicMedCourse" }
        XCTAssertEqual(exam?["lookbackCalendarMonths"] as? Int, 48)
        XCTAssertEqual(course?["lookbackCalendarMonths"] as? Int, 24)
    }

    func testMedicalCertificate6123IsImmune() throws {
        let c = try loadConstants()
        let med = try XCTUnwrap(c["medicalCertificate"] as? [String: Any])
        XCTAssertEqual(med["citation"] as? String, "14 CFR 61.23")
        XCTAssertTrue((med["note"] as? String ?? "").contains("IMMUNE"))
    }

    func testComplexAndHighPerformanceAreNonRecurrentInProvenance() throws {
        let c = try loadConstants()
        let adv = try XCTUnwrap(c["advisoryNonCurrencies"] as? [[String: Any]])
        let byId = Dictionary(uniqueKeysWithValues: adv.map { ($0["id"] as? String ?? "", $0) })
        XCTAssertEqual(byId["complex"]?["citation"] as? String, "14 CFR 61.31(e)")
        XCTAssertEqual(byId["highPerformance"]?["citation"] as? String, "14 CFR 61.31(f)")
        XCTAssertEqual(byId["complex"]?["recurrent"] as? Bool, false)
        XCTAssertEqual(byId["highPerformance"]?["recurrent"] as? Bool, false)
    }

    // MARK: - Engine behavior: complex/HP must never report Expired/Not current

    private func makeComplexAircraft(highPerf: Bool = false) -> Aircraft {
        let ac = Aircraft(registration: "N123AB", make: "Piper", model: "Arrow")
        ac.isComplex = true
        ac.isHighPerformance = highPerf
        return ac
    }

    private func makeFlight(daysAgo: Int, aircraft: Aircraft?, pilot: PilotProfile) -> Flight {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: referenceDate) ?? referenceDate
        let flight = Flight(flightDate: date, status: .finalized, role: .pic)
        flight.totalTime = 1.0
        flight.picTime = 1.0
        flight.aircraft = aircraft
        flight.pilot = pilot
        return flight
    }

    func testComplexWithNoRecentFlightsIsNotExpired() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(currencyType: .complex, displayName: "Complex Aircraft Proficiency (Advisory)", lookbackDays: 90, isBuiltIn: true)
        requirement.requiredFlightHours = 0.5

        // No qualifying flights in the window.
        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [])
        XCTAssertNotEqual(result.status, .expired, "Complex must never report Expired — it has no FAA recurrency")
        XCTAssertEqual(result.status, .notApplicable)
        XCTAssertNil(result.warningText, "No 'not current' warning for an advisory non-currency")
        XCTAssertNil(result.detail.nextRequiredAction, "No required action implied for an advisory non-currency")
        XCTAssertTrue(result.detail.regulationReference?.contains("one-time endorsement") == true)
    }

    func testHighPerformanceWithNoRecentFlightsIsNotExpired() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(currencyType: .highPerformance, displayName: "High Performance Proficiency (Advisory)", lookbackDays: 90, isBuiltIn: true)
        requirement.requiredFlightHours = 0.5

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [])
        XCTAssertNotEqual(result.status, .expired)
        XCTAssertEqual(result.status, .notApplicable)
        XCTAssertNil(result.warningText)
    }

    func testComplexWithRecentFlightShowsAdvisoryCurrent() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(currencyType: .complex, displayName: "Complex Aircraft Proficiency (Advisory)", lookbackDays: 90, isBuiltIn: true)
        requirement.requiredFlightHours = 0.5

        let ac = makeComplexAircraft()
        let flight = makeFlight(daysAgo: 10, aircraft: ac, pilot: pilot)

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [flight])
        XCTAssertEqual(result.status, .current)
        XCTAssertTrue(result.summaryText.lowercased().contains("advisory"))
        XCTAssertNotEqual(result.status, .expired)
    }
}
