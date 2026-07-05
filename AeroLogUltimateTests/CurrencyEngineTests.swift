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

    func testLandingCountUsesNumericCountNotDisplayLabel() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .passengerCarryingDay,
            displayName: "Day",
            lookbackDays: 90,
            isBuiltIn: true
        )
        requirement.requiredLandings = 3

        let flight = makeFlight(daysAgo: 10, dayLandings: 3, role: .pic)
        flight.pilot = pilot

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [flight])
        XCTAssertEqual(result.status, .current)
        XCTAssertEqual(result.detail.countedLandings, 3)
        XCTAssertEqual(
            result.detail.qualifyingEvents?.first?.contribution,
            "3 landing(s)"
        )
        XCTAssertEqual(result.detail.qualifyingEvents?.first?.count, 3)
    }

    func testInstrumentExpirationAnchorsToSixthNewestApproach() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .instrument,
            displayName: "IFR",
            lookbackDays: 180,
            isBuiltIn: true
        )
        requirement.requiredApproaches = 6

        // Seven recent approaches on one flight; one older flight with a single approach.
        // Buggy logic used oldest *flight* date; correct logic uses 6th-newest approach date.
        let recent = makeFlight(daysAgo: 3, role: .pic)
        recent.actualInstrumentTime = 1.5
        recent.conditionsRaw = [FlightCondition.actualInstrument.rawValue]
        recent.holds = 1
        let recentApproach = InstrumentApproach(approachType: .ils, approachCount: 7)
        recentApproach.flight = recent
        recent.approaches = [recentApproach]
        recent.pilot = pilot

        let older = makeFlight(daysAgo: 120, role: .pic)
        older.actualInstrumentTime = 1.0
        older.conditionsRaw = [FlightCondition.actualInstrument.rawValue]
        let olderApproach = InstrumentApproach(approachType: .rnav, approachCount: 1)
        olderApproach.flight = older
        older.approaches = [olderApproach]
        older.pilot = pilot

        let result = engine.calculate(
            requirement: requirement,
            pilot: pilot,
            flights: [recent, older]
        )

        XCTAssertEqual(result.status, .current)
        XCTAssertEqual(result.detail.countedApproaches, 8)

        let sixthNewestDate = Calendar.current.date(byAdding: .day, value: -3, to: referenceDate)!
        let expectedExpiration = Calendar.current.date(
            byAdding: .month,
            value: 6,
            to: Calendar.current.startOfDay(for: sixthNewestDate)
        )
        XCTAssertEqual(result.expiresAt, expectedExpiration)

        let buggyOldestFlightExpiration = Calendar.current.date(
            byAdding: .month,
            value: 6,
            to: Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: -120, to: referenceDate)!
            )
        )
        XCTAssertNotEqual(result.expiresAt, buggyOldestFlightExpiration)
    }

    func testTypeRatingPICHoursDoNotDoubleCount() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .typeRating,
            displayName: "B737",
            lookbackDays: 365,
            isBuiltIn: true
        )
        requirement.typeRatingDesignator = "B737"
        requirement.requiredFlightHours = 1.0

        let aircraft = Aircraft(registration: "N737AA", make: "Boeing", model: "737-800")
        aircraft.typeDesignator = "B737"
        aircraft.requiresTypeRating = true

        let flight = makeFlight(daysAgo: 20, role: .pic)
        flight.totalTime = 2.5
        flight.picTime = 2.5
        flight.aircraft = aircraft
        flight.pilot = pilot

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [flight])

        XCTAssertEqual(result.detail.countedFlightHours, 2.5, accuracy: 0.001)
        XCTAssertEqual(result.status, .current)
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