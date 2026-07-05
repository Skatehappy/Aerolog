import XCTest
@testable import AeroLogUltimate

final class CurrencyEngineTests: XCTestCase {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-06-15T12:00:00Z")!
    private lazy var engine = CurrencyEngine(referenceDate: referenceDate)

    func testDayPassengerCurrencyWithThreeLandings() {
        let pilot = PilotProfile(firstName: "Test", lastName: "Pilot", isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .passengerCarryingDay,
            displayName: "Day",
            lookbackDays: 90,
            isBuiltIn: true
        )
        requirement.requiredLandings = 3

        let flight1 = makeFlight(daysAgo: 10, dayLandings: 2, role: .pic)
        let flight2 = makeFlight(daysAgo: 20, dayLandings: 2, role: .solo)
        flight1.pilot = pilot
        flight2.pilot = pilot

        let result = engine.calculate(
            requirement: requirement,
            pilot: pilot,
            flights: [flight1, flight2]
        )

        XCTAssertEqual(result.status, .current)
        XCTAssertEqual(result.detail.countedLandings, 4)
    }

    func testInstrumentCurrencyRequiresApproachesAndHolds() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .instrument,
            displayName: "IFR",
            lookbackDays: 180,
            isBuiltIn: true
        )
        requirement.requiredApproaches = 6

        var flights: [Flight] = []
        for i in 0..<3 {
            let flight = makeFlight(daysAgo: 30 + i * 10, role: .pic)
            flight.actualInstrumentTime = 1.0
            flight.conditionsRaw = [FlightCondition.actualInstrument.rawValue]
            flight.holds = 1
            let approach = InstrumentApproach(approachType: .ils, approachCount: 2)
            approach.flight = flight
            flight.approaches = [approach]
            flight.pilot = pilot
            flights.append(flight)
        }

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: flights)
        XCTAssertEqual(result.status, .current)
        XCTAssertEqual(result.detail.countedApproaches, 6)
    }

    func testMedicalExpired() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        pilot.medicalExpirationDate = Calendar.current.date(byAdding: .day, value: -10, to: referenceDate)
        pilot.medicalClass = .third

        let requirement = CurrencyRequirement(currencyType: .medical, displayName: "Medical", isBuiltIn: true)

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [])
        XCTAssertEqual(result.status, .expired)
    }

    func testNightPassengerCurrencyCountsOnlyFullStopLandings() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .passengerCarryingNight,
            displayName: "Night",
            lookbackDays: 90,
            isBuiltIn: true
        )
        requirement.requiredNightLandings = 3

        let touchAndGo = makeFlight(daysAgo: 10, nightLandings: 3, role: .pic)
        touchAndGo.fullStopNightLandings = 0
        touchAndGo.setConditions([.night])
        touchAndGo.nightTime = 1.0
        touchAndGo.pilot = pilot

        let touchResult = engine.calculate(
            requirement: requirement,
            pilot: pilot,
            flights: [touchAndGo]
        )
        XCTAssertNotEqual(touchResult.status, .current)

        let fullStop = makeFlight(daysAgo: 15, nightLandings: 3, role: .pic)
        fullStop.fullStopNightLandings = 3
        fullStop.setConditions([.night])
        fullStop.nightTime = 1.2
        fullStop.pilot = pilot

        let fullStopResult = engine.calculate(
            requirement: requirement,
            pilot: pilot,
            flights: [fullStop]
        )
        XCTAssertEqual(fullStopResult.status, .current)
    }

    func testIPCNotApplicableWhenInstrumentCurrent() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .instrumentProficiencyCheck,
            displayName: "IPC",
            isBuiltIn: true
        )

        let result = engine.calculate(
            requirement: requirement,
            pilot: pilot,
            flights: [],
            instrumentCurrencyCurrent: true
        )
        XCTAssertEqual(result.status, .notApplicable)
    }

    // MARK: - Helpers

    private func makeFlight(
        daysAgo: Int,
        dayLandings: Int = 0,
        nightLandings: Int = 0,
        role: FlightRole = .pic
    ) -> Flight {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: referenceDate) ?? referenceDate
        let flight = Flight(flightDate: date, status: .finalized, role: role)
        flight.dayLandings = dayLandings
        flight.nightLandings = nightLandings
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        flight.totalTime = 1.0
        flight.picTime = role == .pic ? 1.0 : 0
        return flight
    }
}