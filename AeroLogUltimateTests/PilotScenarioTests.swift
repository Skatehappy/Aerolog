import SwiftData
import XCTest
@testable import AeroLogUltimate

private typealias AppDataStore = AeroLogUltimate.DataStore

/// End-to-end validation using realistic private-pilot and CFI workflows.
///
/// Scenario pilot: Sarah Chen — PPL based at KPAO, flies a club C172 (N5283E).
@MainActor
final class PilotScenarioTests: XCTestCase {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-06-15T12:00:00Z")!

    // MARK: - Currency (14 CFR 61.57)

    func testSarahDayPassengerCurrencyAfterPatternWork() throws {
        let store = try AppDataStore.makeInMemory()
        let pilot = try configureSarah(store: store)
        let aircraft = try registerAircraft(store: store)

        // Three pattern sessions inside 90 days with 3+ day landings total.
        for daysAgo in [12, 28, 45] {
            let flight = try makeFinalizedFlight(
                store: store, pilot: pilot, aircraft: aircraft,
                daysAgo: daysAgo, dayLandings: 2, role: .pic
            )
            flight.departureICAO = "KPAO"
            flight.arrivalICAO = "KPAO"
        }

        let currency = CurrencyService(dataStore: store, referenceDate: referenceDate)
        let dashboard = try currency.calculateDashboard(for: pilot)
        let dayCurrency = dashboard.results.first { $0.currencyType == .passengerCarryingDay }

        XCTAssertEqual(dayCurrency?.status, .current)
        XCTAssertGreaterThanOrEqual(dayCurrency?.detail.countedLandings ?? 0, 3)
    }

    func testSarahNightCurrencyRejectsTouchAndGoLandings() throws {
        let store = try AppDataStore.makeInMemory()
        let pilot = try configureSarah(store: store)
        let aircraft = try registerAircraft(store: store)

        let touchAndGo = try makeFinalizedFlight(
            store: store, pilot: pilot, aircraft: aircraft,
            daysAgo: 14, nightLandings: 3, role: .pic
        )
        touchAndGo.fullStopNightLandings = 0
        touchAndGo.setConditions([.night])
        touchAndGo.nightTime = 1.2

        let currency = CurrencyService(dataStore: store, referenceDate: referenceDate)
        let nightResult = try currency.result(
            for: try builtInRequirement(store: store, type: .passengerCarryingNight),
            pilot: pilot
        )
        XCTAssertNotEqual(nightResult.status, .current)
    }

    func testSarahNightCurrencyWithFullStopLandings() throws {
        let store = try AppDataStore.makeInMemory()
        let pilot = try configureSarah(store: store)
        let aircraft = try registerAircraft(store: store)

        for daysAgo in [10, 22, 40] {
            let flight = try makeFinalizedFlight(
                store: store, pilot: pilot, aircraft: aircraft,
                daysAgo: daysAgo, nightLandings: 1, role: .pic
            )
            flight.fullStopNightLandings = 1
            flight.setConditions([.night])
            flight.nightTime = 1.0
        }

        let currency = CurrencyService(dataStore: store, referenceDate: referenceDate)
        let nightResult = try currency.result(
            for: try builtInRequirement(store: store, type: .passengerCarryingNight),
            pilot: pilot
        )
        XCTAssertEqual(nightResult.status, .current)
        XCTAssertGreaterThanOrEqual(nightResult.detail.countedLandings ?? 0, 3)
    }

    func testSarahFlightReviewFromSignedEndorsement() throws {
        let store = try AppDataStore.makeInMemory()
        let pilot = try configureSarah(store: store)
        let instructor = PilotProfile(firstName: "Mike", lastName: "Torres", isCFI: true)
        instructor.cfiCertificateNumber = "CFI2847103"
        store.insert(instructor)
        try store.save()

        let endorsementService = EndorsementService(dataStore: store)
        let definition = EndorsementTemplateCatalog.definition(for: .flightReview)!
        let endorsement = try endorsementService.createFromBuiltInTemplate(
            definition,
            student: pilot,
            instructor: instructor,
            values: [
                "student_name": pilot.fullName,
                "review_date": "June 1, 2026"
            ]
        )
        try endorsementService.sign(
            endorsement,
            signerName: instructor.fullName,
            certificateNumber: instructor.cfiCertificateNumber!,
            signatureData: Data([0x01]),
            instructor: instructor
        )

        let currency = CurrencyService(dataStore: store, referenceDate: referenceDate)
        let review = try currency.result(
            for: try builtInRequirement(store: store, type: .flightReview),
            pilot: pilot
        )
        XCTAssertEqual(review.status, .current)
    }

    // MARK: - Logbook & Import

    func testSarahImportsLegacyCSVLogbook() throws {
        let store = try AppDataStore.makeInMemory()
        _ = try configureSarah(store: store)

        let csv = """
        Date,Aircraft,From,To,Total Time,PIC,Night,Day Landings,Night Landings,Remarks
        2025-11-02,N5283E,KPAO,KMOD,2.1,2.1,0.0,1,0,Cross country brunch run
        2025-12-18,N5283E,KPAO,KPAO,1.0,1.0,0.0,4,0,Pattern proficiency
        2026-01-09,N5283E,KPAO,KSQL,0.9,0.9,0.0,2,0,Short field practice
        """
        let service = DataManagementService(
            dataStore: store,
            attachmentStorage: AttachmentStorageService()
        )
        let result = try service.importData(Data(csv.utf8), format: .csv)
        XCTAssertEqual(result.importedFlights, 3)
        XCTAssertEqual(result.importedAircraft, 1)

        let flights = try store.fetch(FetchDescriptor<Flight>())
        XCTAssertTrue(flights.contains { $0.arrivalICAO == "KMOD" })
        XCTAssertTrue(flights.allSatisfy { $0.status == FlightStatus.finalized })
    }

    // MARK: - Backup & Restore (offline-first)

    func testSarahFullBackupRestorePreservesLogbookEndorsementsAndAdvancedFields() throws {
        let store = try AppDataStore.makeInMemory()
        let pilot = try configureSarah(store: store)
        let aircraftService = AircraftService(dataStore: store)
        let flightService = FlightService(dataStore: store)
        let expenseService = ExpenseService(dataStore: store)
        let maintenanceService = MaintenanceService(dataStore: store)
        let endorsementService = EndorsementService(dataStore: store)

        let aircraft = try aircraftService.create(registration: "N5283E", make: "Cessna", model: "172S")
        aircraft.cruiseSpeedKIAS = 122
        aircraft.performanceNotes = "Vy 74 KIAS, cruise 2400 RPM"
        _ = try maintenanceService.addItem(
            to: aircraft,
            title: "Annual Inspection",
            type: .annual,
            dueDate: referenceDate.addingTimeInterval(86400 * 120)
        )

        let flight = try flightService.createDraft()
        flight.aircraft = aircraft
        flight.pilot = pilot
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KTRK"
        flight.totalTime = 2.4
        flight.picTime = 2.4
        flight.crossCountryTime = 2.4
        flight.setConditions([.crossCountry])
        flight.isPinned = true
        flight.isFavorite = true
        flight.fuelAdded = 42
        flight.fuelRemaining = 18
        _ = try expenseService.addExpense(to: flight, category: .fuel, amount: 124.50, vendor: "Truckee FBO")
        _ = try flightService.ensureWeightBalanceLog(for: flight)
        flight.weightBalanceLog?.emptyWeight = 1665
        flight.weightBalanceLog?.emptyArm = 39.2
        try flightService.finalize(flight)

        let instructor = PilotProfile(firstName: "Mike", lastName: "Torres", isCFI: true)
        store.insert(instructor)
        try store.save()
        let definition = EndorsementTemplateCatalog.definition(for: .soloFlight)!
        _ = try endorsementService.createFromBuiltInTemplate(
            definition,
            student: pilot,
            instructor: instructor,
            values: ["student_name": pilot.fullName, "aircraft_make_model": "Cessna 172S"]
        )

        let dataService = DataManagementService(
            dataStore: store,
            attachmentStorage: AttachmentStorageService()
        )
        let backup = try dataService.createBackup(includeAttachments: false)
        XCTAssertEqual(backup.package.flights.count, 1)
        XCTAssertEqual(backup.package.endorsements.count, 1)
        XCTAssertEqual(backup.package.aircraft.first?.maintenanceItems?.count, 1)
        XCTAssertEqual(backup.package.flights.first?.expenses?.count, 1)
        XCTAssertNotNil(backup.package.flights.first?.weightBalanceLog)

        let restoreStore = try AppDataStore.makeInMemory()
        let restoreService = DataManagementService(
            dataStore: restoreStore,
            attachmentStorage: AttachmentStorageService()
        )
        _ = try restoreService.restoreBackup(from: backup.archiveURL, strategy: .merge)

        let restoredFlights = try restoreStore.fetch(FetchDescriptor<Flight>())
        let restoredAircraft = try restoreStore.fetch(FetchDescriptor<Aircraft>())
        let restoredEndorsements = try restoreStore.fetch(FetchDescriptor<Endorsement>())
        let restoredMaintenance = try restoreStore.fetch(FetchDescriptor<MaintenanceItem>())
        let restoredExpenses = try restoreStore.fetch(FetchDescriptor<FlightExpense>())

        XCTAssertEqual(restoredFlights.count, 1)
        XCTAssertEqual(restoredFlights.first?.departureICAO, "KPAO")
        XCTAssertTrue(restoredFlights.first?.isPinned == true)
        XCTAssertEqual(restoredFlights.first?.fuelAdded, 42)
        XCTAssertNotNil(restoredFlights.first?.weightBalanceLog)
        XCTAssertEqual(restoredAircraft.first?.cruiseSpeedKIAS, 122)
        XCTAssertEqual(restoredEndorsements.count, 1)
        XCTAssertEqual(restoredMaintenance.count, 1)
        XCTAssertEqual(restoredExpenses.count, 1)
        XCTAssertEqual(restoredExpenses.first?.amount ?? 0, 124.50, accuracy: 0.01)
    }

    func testOfflineOperationWithSyncDisabled() async throws {
        let store = try AppDataStore.makeInMemory()
        let pilot = try configureSarah(store: store)
        let flightService = FlightService(dataStore: store)
        let aircraft = try registerAircraft(store: store)
        let flight = try flightService.createDraft()
        flight.pilot = pilot
        flight.aircraft = aircraft
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        flight.totalTime = 0.8
        flight.picTime = 0.8
        try flightService.finalize(flight)

        let sync = SyncCoordinator(configuration: .disabled)
        let dataService = DataManagementService(
            dataStore: store,
            attachmentStorage: AttachmentStorageService()
        )
        sync.attach(dataManagementService: dataService)

        try await sync.syncNow()
        XCTAssertFalse(sync.configuration.isEnabled)

        let flights = try flightService.allFlights(includeDrafts: false)
        XCTAssertEqual(flights.count, 1)
        XCTAssertEqual(flights.first?.departureICAO, "KPAO")
    }

    // MARK: - Reports

    func testSarahGeneratesFAA8710AndTotalTimeReports() throws {
        let store = try AppDataStore.makeInMemory()
        let pilot = try configureSarah(store: store)
        let aircraft = try registerAircraft(store: store)

        for daysAgo in [30, 60, 90] {
            let flight = try makeFinalizedFlight(
                store: store, pilot: pilot, aircraft: aircraft,
                daysAgo: daysAgo, dayLandings: 1, role: .pic
            )
            flight.totalTime = 1.5
            flight.picTime = 1.5
            flight.crossCountryTime = 1.0
            flight.setConditions([.crossCountry])
        }

        let reportService = ReportService(dataStore: store)
        let totalTime = try reportService.generate(type: .totalTimeSummary, pilot: pilot)
        XCTAssertEqual(totalTime.totalTime?.totalFlights, 3)
        XCTAssertEqual(totalTime.totalTime?.totalTime ?? 0, 4.5, accuracy: 0.01)

        let faa8710 = try reportService.generate(type: .faa8710, pilot: pilot)
        XCTAssertEqual(faa8710.faa8710?.totalTime ?? 0, 4.5, accuracy: 0.01)
        XCTAssertEqual(faa8710.faa8710?.picTime ?? 0, 4.5, accuracy: 0.01)
    }

    // MARK: - Advanced Features (Phase 8)

    func testSarahNaturalLanguageSearchFindsPinnedCrossCountry() throws {
        let store = try AppDataStore.makeInMemory()
        let pilot = try configureSarah(store: store)
        let aircraft = try registerAircraft(store: store)

        let routine = try makeFinalizedFlight(
            store: store, pilot: pilot, aircraft: aircraft,
            daysAgo: 5, dayLandings: 1, role: .pic
        )
        routine.departureICAO = "KPAO"
        routine.arrivalICAO = "KPAO"

        let favorite = try makeFinalizedFlight(
            store: store, pilot: pilot, aircraft: aircraft,
            daysAgo: 40, dayLandings: 1, role: .pic
        )
        favorite.departureICAO = "KPAO"
        favorite.arrivalICAO = "KTRK"
        favorite.crossCountryTime = 2.2
        favorite.totalTime = 2.2
        favorite.setConditions([.crossCountry])
        favorite.isPinned = true
        favorite.isFavorite = true
        favorite.remarks = "Lake Tahoe lunch trip"

        let criteria = NaturalLanguageSearchEngine.parse(
            "pinned cross country KTRK last month",
            referenceDate: referenceDate
        )
        XCTAssertTrue(criteria.pinnedOnly)
        XCTAssertTrue(criteria.requiresCrossCountry)
        XCTAssertEqual(criteria.arrivalICAO, "KTRK")

        let flights = try FlightService(dataStore: store).allFlights()
        let matches = flights.filter { NaturalLanguageSearchEngine.matches($0, criteria: criteria) }
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.arrivalICAO, "KTRK")
        _ = routine
    }

    func testSarahMaintenanceReminderIdentifiesOverdueAnnual() throws {
        let store = try AppDataStore.makeInMemory()
        let aircraftService = AircraftService(dataStore: store)
        let maintenanceService = MaintenanceService(dataStore: store)
        let aircraft = try aircraftService.create(registration: "N5283E", make: "Cessna", model: "172S")

        _ = try maintenanceService.addItem(
            to: aircraft,
            title: "Annual",
            type: .annual,
            dueDate: referenceDate.addingTimeInterval(-86400 * 3)
        )

        let overdue = try maintenanceService.overdueItems(asOf: referenceDate)
        XCTAssertEqual(overdue.count, 1)
        XCTAssertEqual(overdue.first?.title, "Annual")
        XCTAssertTrue(overdue.first?.isOverdue == true)
    }

    // MARK: - CFI Dual Instruction Scenario

    func testCFILogsDualGivenWithStudentProgress() throws {
        let store = try AppDataStore.makeInMemory()
        let student = PilotProfile(firstName: "Alex", lastName: "Rivera", isPrimaryProfile: true)
        store.insert(student)

        let cfi = PilotProfile(firstName: "Sarah", lastName: "Chen", isCFI: true)
        cfi.cfiCertificateNumber = "CFI3928104"
        store.insert(cfi)
        try store.save()

        let aircraft = try registerAircraft(store: store)
        let flightService = FlightService(dataStore: store)
        let flight = try flightService.createDraft(role: .dualGiven)
        flight.pilot = cfi
        flight.instructor = cfi
        flight.aircraft = aircraft
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KPAO"
        flight.totalTime = 1.2
        flight.dualGiven = 1.2
        flight.instructorName = cfi.fullName
        flight.instructorCertificateNumber = cfi.cfiCertificateNumber
        flight.lessonTitle = "Slow flight and stalls"
        try flightService.finalize(flight)

        let reportService = ReportService(dataStore: store)
        let summary = try reportService.generate(type: .totalTimeSummary, pilot: cfi)
        XCTAssertEqual(summary.totalTime?.dualGiven ?? 0, 1.2, accuracy: 0.01)
    }

    // MARK: - Helpers

    @discardableResult
    // MARK: - CFI Maria Vasquez (class-scoped currency, WS1)

    /// Maria instructs in a C172 (dual given), trains toward AMEL in a PA-44 (dual
    /// received), and we assert class isolation, H5 role-independent landing credit,
    /// and the endorsement signing rule.
    func testMariaVasquezClassScopedCurrency() throws {
        let store = try AppDataStore.makeInMemory()
        let maria = try XCTUnwrap(try store.primaryPilotProfile())
        maria.firstName = "Maria"
        maria.lastName = "Vasquez"
        maria.isCFI = true
        maria.cfiCertificateNumber = "CFI123456"
        maria.setRatings([.instrumentAirplane, .flightInstructor])  // holds SEL base, NOT AMEL yet
        try store.save()

        let aircraftSvc = AircraftService(dataStore: store)
        let c172 = try aircraftSvc.create(registration: "N172SP", make: "Cessna", model: "172S")
        c172.aircraftClass = .singleEngineLand
        c172.category = .airplane
        let pa44 = try aircraftSvc.create(registration: "N44PA", make: "Piper", model: "PA-44")
        pa44.aircraftClass = .multiEngineLand
        pa44.category = .airplane
        try store.save()

        // Instructs in the C172 (dual given) — 3 landings within 90 days.
        for d in [10, 20, 30] {
            _ = try makeFinalizedFlight(store: store, pilot: maria, aircraft: c172, daysAgo: d, dayLandings: 1, role: .dualGiven)
        }

        let currency = CurrencyService(dataStore: store, referenceDate: referenceDate)
        var dashboard = try currency.calculateDashboard(for: maria)
        func dayResult(_ cls: AircraftClass) -> CurrencyCalculationResult? {
            dashboard.results.first { $0.currencyType == .passengerCarryingDay && $0.applicableClass == cls }
        }

        // H5: dual-given landings count → SEL current. AMEL has no twin time yet.
        XCTAssertEqual(dayResult(.singleEngineLand)?.status, .current)
        XCTAssertNotEqual(dayResult(.multiEngineLand)?.status, .current)

        // Trains for AMEL: 3 dual-received twin landings → AMEL becomes current.
        for d in [5, 6, 7] {
            _ = try makeFinalizedFlight(store: store, pilot: maria, aircraft: pa44, daysAgo: d, dayLandings: 1, role: .dualReceived)
        }
        dashboard = try currency.calculateDashboard(for: maria)
        XCTAssertEqual(dayResult(.multiEngineLand)?.status, .current)

        // Endorsement signing rule: missing certificate number cannot sign.
        let endoSvc = EndorsementService(dataStore: store)
        let endo = Endorsement(templateID: .custom, title: "Test", endorsementText: "text")
        store.insert(endo)
        try store.save()
        XCTAssertThrowsError(try endoSvc.sign(endo, signerName: "Maria Vasquez", certificateNumber: "", signatureData: Data([1, 2, 3])))
    }

    private func configureSarah(store: AppDataStore) throws -> PilotProfile {
        let pilot = try store.primaryPilotProfile()!
        pilot.firstName = "Sarah"
        pilot.lastName = "Chen"
        pilot.certificateNumber = "PPL-4829103"
        pilot.certificateType = .privatePilot
        pilot.homeAirportICAO = "KPAO"
        pilot.medicalClass = .third
        pilot.medicalExpirationDate = Calendar.current.date(byAdding: .month, value: 8, to: referenceDate)
        try store.save()
        return pilot
    }

    private func registerAircraft(store: AppDataStore) throws -> Aircraft {
        let service = AircraftService(dataStore: store)
        return try service.create(registration: "N5283E", make: "Cessna", model: "172S")
    }

    private func builtInRequirement(
        store: AppDataStore,
        type: CurrencyType
    ) throws -> CurrencyRequirement {
        try store.ensureBuiltInCurrencyRequirements()
        let requirements = try store.fetch(FetchDescriptor<CurrencyRequirement>())
        guard let requirement = requirements.first(where: { $0.currencyType == type }) else {
            throw XCTSkip("Built-in requirement \(type) not seeded")
        }
        return requirement
    }

    @discardableResult
    private func makeFinalizedFlight(
        store: AppDataStore,
        pilot: PilotProfile,
        aircraft: Aircraft,
        daysAgo: Int,
        dayLandings: Int = 0,
        nightLandings: Int = 0,
        role: FlightRole
    ) throws -> Flight {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: referenceDate) ?? referenceDate
        let service = FlightService(dataStore: store)
        let flight = try service.createDraft(date: date, role: role)
        flight.pilot = pilot
        flight.aircraft = aircraft
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        flight.totalTime = 1.0
        flight.picTime = role == .pic || role == .solo ? 1.0 : 0
        flight.dayLandings = dayLandings
        flight.nightLandings = nightLandings
        try service.finalize(flight)
        return flight
    }
}