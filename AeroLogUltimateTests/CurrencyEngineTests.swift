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

        XCTAssertEqual(result.detail.countedFlightHours ?? 0, 2.5, accuracy: 0.001)
        XCTAssertEqual(result.status, .current)
    }

    func testDayPassengerCurrencyWordingMentionsCarryingPassengers() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .passengerCarryingDay,
            displayName: "Day",
            lookbackDays: 90,
            isBuiltIn: true
        )
        requirement.requiredLandings = 3

        let flight = makeFlight(daysAgo: 10, dayLandings: 1, role: .pic)
        flight.pilot = pilot

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [flight])
        XCTAssertEqual(result.status, .expired)
        XCTAssertTrue(result.warningText?.contains("carry passengers") == true)
        XCTAssertTrue(result.detail.nextRequiredAction?.contains("carrying passengers") == true)
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

    // MARK: - Audit regression tests

    /// H1: 24 calendar months after Jul 5 2024 = valid through Jul 31 2026.
    func testEndOfCalendarMonthHelper_H1() {
        let jul5 = ISO8601DateFormatter().date(from: "2024-07-05T12:00:00Z")!
        let expiry = CurrencyDateUtilities.endOfCalendarMonth(afterAdding: 24, to: jul5)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: expiry)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 7)
        XCTAssertEqual(comps.day, 31)
    }

    /// H1: flight review is valid through the LAST day of the 24th calendar month.
    /// Review 2024-06-10 → exact-day math expires 2026-06-10 (before the 2026-06-15
    /// reference), but the calendar-month rule keeps it valid through 2026-06-30.
    func testFlightReviewValidThroughEndOfCalendarMonth_H1() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        pilot.lastFlightReviewDate = ISO8601DateFormatter().date(from: "2024-06-10T12:00:00Z")
        let requirement = CurrencyRequirement(currencyType: .flightReview, displayName: "BFR", isBuiltIn: true)

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [])
        XCTAssertNotEqual(result.status, .expired, "calendar-month review should still be valid")
    }

    /// H2: 61.57(a) day-passenger currency counts landings made at night too.
    func testDayPassengerCountsNightLandings_H2() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .passengerCarryingDay, displayName: "Day", lookbackDays: 90, isBuiltIn: true
        )
        requirement.requiredLandings = 3

        let flight = makeFlight(daysAgo: 10, nightLandings: 3, role: .pic)
        flight.dayLandings = 0
        flight.pilot = pilot

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [flight])
        XCTAssertEqual(result.status, .current)
        XCTAssertEqual(result.detail.countedLandings, 3)
    }

    /// H2: tailwheel currency counts night full-stop landings too.
    func testTailwheelCountsNightFullStops_H2() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .tailwheel, displayName: "TW", lookbackDays: 90, isBuiltIn: true
        )
        requirement.requiredLandings = 3

        let aircraft = Aircraft(registration: "N1TW")
        aircraft.isTailwheel = true
        let flight = makeFlight(daysAgo: 5, role: .pic)
        flight.fullStopDayLandings = 0
        flight.fullStopNightLandings = 3
        flight.aircraft = aircraft
        flight.pilot = pilot

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [flight])
        XCTAssertEqual(result.status, .current)
    }

    /// H3: landing-currency expiry anchors on the Nth-most-recent LANDING, not the
    /// Nth-most-recent flight. 1 landing 100d ago, 1 at 70d, 2 at 40d, need 3 →
    /// the 3rd landing back is 70 days ago, so ~20 days remain (the old per-flight
    /// anchor used 100 days ago and would have shown expired).
    func testLandingExpiryExpandsByLandingCount_H3() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let requirement = CurrencyRequirement(
            currencyType: .passengerCarryingDay, displayName: "Day", lookbackDays: 90, isBuiltIn: true
        )
        requirement.requiredLandings = 3

        let a = makeFlight(daysAgo: 100, dayLandings: 1, role: .pic); a.pilot = pilot
        let b = makeFlight(daysAgo: 70, dayLandings: 1, role: .pic); b.pilot = pilot
        let c = makeFlight(daysAgo: 40, dayLandings: 2, role: .pic); c.pilot = pilot

        let result = engine.calculate(requirement: requirement, pilot: pilot, flights: [a, b, c])
        XCTAssertEqual(result.status, .current)
        XCTAssertEqual(result.detail.daysRemaining ?? -999, 20, accuracy: 1)
    }

    // MARK: - WS1 class/category scoping

    private func makeAircraft(_ cls: AircraftClass, category: AircraftCategory = .airplane, sim: SimulatorLevel = .none) -> Aircraft {
        let a = Aircraft(registration: "N\(cls.rawValue.prefix(4))")
        a.aircraftClass = cls
        a.category = category
        a.simulatorLevel = sim
        return a
    }

    /// C4: SEL landings must not satisfy an AMEL passenger row.
    func testPerClassIsolation_C4() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let req = CurrencyRequirement(currencyType: .passengerCarryingDay, displayName: "Day AMEL", lookbackDays: 90, isBuiltIn: true)
        req.applicableClass = .multiEngineLand
        req.requiredLandings = 3
        let flight = makeFlight(daysAgo: 5, dayLandings: 3, role: .pic)
        flight.aircraft = makeAircraft(.singleEngineLand)
        flight.pilot = pilot
        let result = engine.calculate(requirement: req, pilot: pilot, flights: [flight])
        XCTAssertNotEqual(result.status, .current)
    }

    /// H5: dual-received landings count toward recency (role-independent).
    func testDualReceivedLandingsCount_H5() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let req = CurrencyRequirement(currencyType: .passengerCarryingDay, displayName: "Day AMEL", lookbackDays: 90, isBuiltIn: true)
        req.applicableClass = .multiEngineLand
        req.requiredLandings = 3
        let flight = makeFlight(daysAgo: 5, dayLandings: 3, role: .dualReceived)
        flight.aircraft = makeAircraft(.multiEngineLand)
        flight.pilot = pilot
        let result = engine.calculate(requirement: req, pilot: pilot, flights: [flight])
        XCTAssertEqual(result.status, .current)
    }

    /// WS1.6: training-device landings are excluded, but approaches count.
    func testSimulatorLandingsExcludedApproachesIncluded_WS1_6() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let sim = makeAircraft(.singleEngineLand, sim: .aatd)
        let flight = makeFlight(daysAgo: 5, dayLandings: 3, role: .pic)
        flight.aircraft = sim
        flight.actualInstrumentTime = 1.0
        flight.holds = 1
        let approach = InstrumentApproach(approachType: .ils, approachCount: 6)
        approach.flight = flight
        flight.approaches = [approach]
        flight.pilot = pilot

        let dayReq = CurrencyRequirement(currencyType: .passengerCarryingDay, displayName: "Day ASEL", lookbackDays: 90, isBuiltIn: true)
        dayReq.applicableClass = .singleEngineLand
        dayReq.requiredLandings = 3
        XCTAssertNotEqual(engine.calculate(requirement: dayReq, pilot: pilot, flights: [flight]).status, .current)

        let instReq = CurrencyRequirement(currencyType: .instrument, displayName: "Inst Airplane", lookbackDays: 180, isBuiltIn: true)
        instReq.applicableCategory = .airplane
        instReq.requiredApproaches = 6
        XCTAssertEqual(engine.calculate(requirement: instReq, pilot: pilot, flights: [flight]).status, .current)
    }

    /// C4: airplane approaches must not satisfy a rotorcraft instrument row.
    func testInstrumentPerCategoryIsolation_C4() {
        let pilot = PilotProfile(isPrimaryProfile: true)
        let req = CurrencyRequirement(currencyType: .instrument, displayName: "Inst Rotorcraft", lookbackDays: 180, isBuiltIn: true)
        req.applicableCategory = .rotorcraft
        req.requiredApproaches = 6
        let flight = makeFlight(daysAgo: 10, role: .pic)
        flight.aircraft = makeAircraft(.singleEngineLand, category: .airplane)
        flight.actualInstrumentTime = 1.0
        flight.holds = 1
        let approach = InstrumentApproach(approachType: .ils, approachCount: 6)
        approach.flight = flight
        flight.approaches = [approach]
        flight.pilot = pilot
        XCTAssertNotEqual(engine.calculate(requirement: req, pilot: pilot, flights: [flight]).status, .current)
    }

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