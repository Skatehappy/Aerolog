import Foundation
import SwiftData

/// Imports flights from CSV and portable AeroLog backup packages.
@MainActor
struct LogbookImportService {
    let dataStore: DataStore
    private let csvImporter = CSVLogbookImporter()

    func detectFormat(for url: URL) -> LogbookImportFormat? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "csv": return .csv
        case "aerologbackup": return .aerologBackup
        case "json": return .json
        default: return nil
        }
    }

    func importData(
        _ data: Data,
        format: LogbookImportFormat,
        strategy: BackupRestoreStrategy = .merge
    ) throws -> LogbookImportResult {
        switch format {
        case .csv:
            return try importCSV(data, strategy: strategy)
        case .aerologBackup, .json:
            let package = try AeroLogBackupPackage.decode(from: data)
            return try importBackupPackage(package, strategy: strategy)
        }
    }

    func importCSV(
        _ data: Data,
        strategy: BackupRestoreStrategy = .merge
    ) throws -> LogbookImportResult {
        let rows = try csvImporter.parse(data)
        let pilot = try dataStore.primaryPilotProfile()
        var importedFlights = 0
        var importedAircraft = 0
        var skipped = 0
        var warnings: [String] = []

        var aircraftCache = try buildAircraftCache()

        for row in rows {
            if let externalID = row.externalID,
               try flightExists(externalID: externalID) {
                skipped += 1
                continue
            }

            let aircraft = try resolveAircraft(
                registration: row.aircraftRegistration,
                cache: &aircraftCache,
                importedCount: &importedAircraft
            )

            let flight = Flight(
                flightDate: row.flightDate ?? .now,
                status: .finalized,
                role: row.role ?? .pic
            )
            flight.pilot = pilot
            flight.aircraft = aircraft
            flight.departureICAO = row.departureICAO ?? ""
            flight.arrivalICAO = row.arrivalICAO ?? ""
            flight.route = row.route
            flight.totalTime = row.totalTime ?? 0
            flight.picTime = row.picTime ?? 0
            flight.sicTime = row.sicTime ?? 0
            flight.dualReceived = row.dualReceived ?? 0
            flight.dualGiven = row.dualGiven ?? 0
            flight.soloTime = row.soloTime ?? 0
            flight.crossCountryTime = row.crossCountryTime ?? 0
            flight.nightTime = row.nightTime ?? 0
            flight.actualInstrumentTime = row.actualInstrumentTime ?? 0
            flight.simulatedInstrumentTime = row.simulatedInstrumentTime ?? 0
            flight.groundInstructionTime = row.groundInstructionTime ?? 0
            flight.simulatorTime = row.simulatorTime ?? 0
            flight.dayLandings = row.dayLandings ?? 0
            flight.nightLandings = row.nightLandings ?? 0
            flight.instructorName = row.instructorName
            flight.remarks = row.remarks
            flight.externalID = row.externalID
            flight.finalize()

            dataStore.insert(flight)
            importedFlights += 1
        }

        if importedFlights == 0 && skipped > 0 {
            warnings.append("All \(skipped) entries were skipped as duplicates.")
        }

        try dataStore.save()

        return LogbookImportResult(
            format: .csv,
            importedFlights: importedFlights,
            importedAircraft: importedAircraft,
            skippedDuplicates: skipped,
            warnings: warnings
        )
    }

    func importBackupPackage(
        _ package: AeroLogBackupPackage,
        strategy: BackupRestoreStrategy = .merge
    ) throws -> LogbookImportResult {
        guard package.version <= AeroLogBackupPackage.currentVersion else {
            throw DataManagementError.invalidBackup(
                "This backup was created by a newer version of AeroLog Ultimate."
            )
        }

        if strategy == .replaceAll {
            try clearUserData()
        }

        var pilotMap: [UUID: PilotProfile] = [:]
        for portable in package.pilots {
            if strategy == .merge, let existing = try profile(syncID: portable.syncID) {
                pilotMap[portable.syncID] = existing
                continue
            }
            let profile = PilotProfile(
                firstName: portable.firstName,
                lastName: portable.lastName,
                isPrimaryProfile: portable.isPrimaryProfile,
                isCFI: portable.isCFI
            )
            profile.email = portable.email
            profile.certificateNumber = portable.certificateNumber
            profile.certificateType = portable.certificateType
            profile.cfiCertificateNumber = portable.cfiCertificateNumber
            profile.homeAirportICAO = portable.homeAirportICAO
            profile.syncMetadata?.syncID = portable.syncID
            dataStore.insert(profile)
            pilotMap[portable.syncID] = profile
        }

        var aircraftMap: [UUID: Aircraft] = [:]
        var importedAircraft = 0
        for portable in package.aircraft {
            if strategy == .merge, let existing = try aircraft(syncID: portable.syncID) {
                aircraftMap[portable.syncID] = existing
                continue
            }
            let aircraft = Aircraft(
                registration: portable.registration,
                make: portable.make,
                model: portable.model,
                category: portable.category,
                aircraftClass: portable.aircraftClass,
                simulatorLevel: portable.simulatorLevel
            )
            aircraft.isActive = portable.isActive
            aircraft.performanceNotes = portable.performanceNotes
            aircraft.cruiseSpeedKIAS = portable.cruiseSpeedKIAS
            aircraft.bestGlideSpeedKIAS = portable.bestGlideSpeedKIAS
            aircraft.fuelCapacity = portable.fuelCapacity
            aircraft.defaultFuelBurnGPH = portable.defaultFuelBurnGPH
            aircraft.syncMetadata?.syncID = portable.syncID
            dataStore.insert(aircraft)
            aircraftMap[portable.syncID] = aircraft
            importedAircraft += 1

            for item in portable.maintenanceItems ?? [] {
                if strategy == .merge, try maintenanceItem(syncID: item.syncID) != nil {
                    continue
                }
                let maintenance = MaintenanceItem(
                    title: item.title,
                    maintenanceType: item.maintenanceType,
                    reminderLeadDays: item.reminderLeadDays
                )
                maintenance.syncMetadata?.syncID = item.syncID
                maintenance.dueDate = item.dueDate
                maintenance.dueHobbs = item.dueHobbs
                maintenance.completedDate = item.completedDate
                maintenance.notes = item.notes
                maintenance.isCompleted = item.isCompleted
                maintenance.aircraft = aircraft
                dataStore.insert(maintenance)
            }
        }

        var importedFlights = 0
        var skipped = 0
        for portable in package.flights {
            if strategy == .merge, let existing = try flight(syncID: portable.syncID) {
                _ = existing
                skipped += 1
                continue
            }

            let flight = Flight(
                flightDate: portable.flightDate,
                status: portable.status,
                role: portable.role
            )
            flight.syncMetadata?.syncID = portable.syncID
            if let pilotSyncID = portable.pilotSyncID, let pilot = pilotMap[pilotSyncID] {
                flight.pilot = pilot
            } else {
                flight.pilot = try dataStore.primaryPilotProfile()
            }
            flight.aircraft = portable.aircraftSyncID.flatMap { aircraftMap[$0] }
            flight.departureICAO = portable.departureICAO
            flight.arrivalICAO = portable.arrivalICAO
            flight.route = portable.route
            flight.totalTime = portable.totalTime
            flight.picTime = portable.picTime
            flight.sicTime = portable.sicTime
            flight.dualReceived = portable.dualReceived
            flight.dualGiven = portable.dualGiven
            flight.soloTime = portable.soloTime
            flight.crossCountryTime = portable.crossCountryTime
            flight.nightTime = portable.nightTime
            flight.actualInstrumentTime = portable.actualInstrumentTime
            flight.simulatedInstrumentTime = portable.simulatedInstrumentTime
            flight.groundInstructionTime = portable.groundInstructionTime
            flight.simulatorTime = portable.simulatorTime
            flight.dayLandings = portable.dayLandings
            flight.nightLandings = portable.nightLandings
            flight.fullStopDayLandings = portable.fullStopDayLandings
            flight.fullStopNightLandings = portable.fullStopNightLandings
            flight.holds = portable.holds
            flight.conditionsRaw = portable.conditionsRaw
            flight.instructorName = portable.instructorName
            flight.instructorCertificateNumber = portable.instructorCertificateNumber
            flight.remarks = portable.remarks
            flight.externalID = portable.externalID
            flight.isPinned = portable.isPinned ?? false
            flight.isFavorite = portable.isFavorite ?? false
            flight.fuelAdded = portable.fuelAdded
            flight.fuelBurn = portable.fuelBurn
            flight.fuelRemaining = portable.fuelRemaining
            if let fuelUnit = portable.fuelUnit {
                flight.fuelUnit = fuelUnit
            }
            if portable.status == .finalized {
                flight.finalizedAt = portable.flightDate
            }

            for leg in portable.legs {
                let flightLeg = FlightLeg(
                    legOrder: leg.legOrder,
                    departureICAO: leg.departureICAO,
                    arrivalICAO: leg.arrivalICAO,
                    legTime: leg.legTime
                )
                flightLeg.flight = flight
                dataStore.insert(flightLeg)
            }

            for approach in portable.approaches {
                let instrumentApproach = InstrumentApproach(
                    approachType: approach.approachType,
                    airportICAO: approach.airportICAO,
                    approachCount: approach.approachCount
                )
                instrumentApproach.flight = flight
                dataStore.insert(instrumentApproach)
            }

            if let portableLog = portable.weightBalanceLog {
                if strategy == .merge, flight.weightBalanceLog != nil {
                    // Keep existing worksheet on merge.
                } else {
                    let log = WeightBalanceLog(
                        emptyWeight: portableLog.emptyWeight,
                        emptyArm: portableLog.emptyArm
                    )
                    log.syncMetadata?.syncID = portableLog.syncID
                    log.rampWeight = portableLog.rampWeight
                    log.rampCG = portableLog.rampCG
                    log.forwardCGLimit = portableLog.forwardCGLimit
                    log.aftCGLimit = portableLog.aftCGLimit
                    log.stationEntriesJSON = portableLog.stationEntriesJSON
                    log.notes = portableLog.notes
                    log.flight = flight
                    dataStore.insert(log)
                }
            }

            for expense in portable.expenses ?? [] {
                if strategy == .merge, try expenseItem(syncID: expense.syncID) != nil {
                    continue
                }
                let flightExpense = FlightExpense(
                    category: expense.category,
                    amount: expense.amount,
                    currencyCode: expense.currencyCode,
                    expenseDate: expense.expenseDate
                )
                flightExpense.syncMetadata?.syncID = expense.syncID
                flightExpense.vendor = expense.vendor
                flightExpense.notes = expense.notes
                flightExpense.flight = flight
                dataStore.insert(flightExpense)
            }

            dataStore.insert(flight)
            importedFlights += 1
        }

        for portable in package.endorsements {
            if strategy == .merge, try endorsement(syncID: portable.syncID) != nil {
                continue
            }
            let endorsement = Endorsement(
                templateID: EndorsementTemplateID(rawValue: portable.templateID) ?? .custom,
                title: portable.title,
                endorsementText: portable.endorsementText
            )
            endorsement.syncMetadata?.syncID = portable.syncID
            endorsement.status = portable.status
            endorsement.issuedDate = portable.issuedDate
            endorsement.signedAt = portable.signedAt
            endorsement.signerName = portable.signerName
            endorsement.signerCertificateNumber = portable.signerCertificateNumber
            endorsement.studentNameSnapshot = portable.studentNameSnapshot
            endorsement.instructorNameSnapshot = portable.instructorNameSnapshot
            if let studentSyncID = portable.studentSyncID {
                endorsement.student = pilotMap[studentSyncID]
            }
            if let instructorSyncID = portable.instructorSyncID {
                endorsement.instructor = pilotMap[instructorSyncID]
            }
            dataStore.insert(endorsement)
        }

        try dataStore.save()

        return LogbookImportResult(
            format: .aerologBackup,
            importedFlights: importedFlights,
            importedAircraft: importedAircraft,
            skippedDuplicates: skipped,
            warnings: []
        )
    }

    // MARK: - Helpers

    private func buildAircraftCache() throws -> [String: Aircraft] {
        let aircraft = try dataStore.fetch(FetchDescriptor<Aircraft>())
        var cache: [String: Aircraft] = [:]
        for item in aircraft {
            let key = item.registration.uppercased()
            if !key.isEmpty {
                cache[key] = item
            }
        }
        return cache
    }

    private func resolveAircraft(
        registration: String?,
        cache: inout [String: Aircraft],
        importedCount: inout Int
    ) throws -> Aircraft? {
        guard let registration, !registration.isEmpty else { return nil }
        let key = registration.uppercased()
        if let existing = cache[key] { return existing }

        let aircraft = Aircraft(registration: registration)
        dataStore.insert(aircraft)
        cache[key] = aircraft
        importedCount += 1
        return aircraft
    }

    private func flightExists(externalID: String) throws -> Bool {
        let flights = try dataStore.fetch(FetchDescriptor<Flight>())
        return flights.contains { $0.externalID == externalID }
    }

    private func flight(syncID: UUID) throws -> Flight? {
        let flights = try dataStore.fetch(FetchDescriptor<Flight>())
        return flights.first { $0.syncMetadata?.syncID == syncID }
    }

    private func aircraft(syncID: UUID) throws -> Aircraft? {
        let aircraft = try dataStore.fetch(FetchDescriptor<Aircraft>())
        return aircraft.first { $0.syncMetadata?.syncID == syncID }
    }

    private func profile(syncID: UUID) throws -> PilotProfile? {
        let profiles = try dataStore.fetch(FetchDescriptor<PilotProfile>())
        return profiles.first { $0.syncMetadata?.syncID == syncID }
    }

    private func endorsement(syncID: UUID) throws -> Endorsement? {
        let endorsements = try dataStore.fetch(FetchDescriptor<Endorsement>())
        return endorsements.first { $0.syncMetadata?.syncID == syncID }
    }

    private func maintenanceItem(syncID: UUID) throws -> MaintenanceItem? {
        let items = try dataStore.fetch(FetchDescriptor<MaintenanceItem>())
        return items.first { $0.syncMetadata?.syncID == syncID }
    }

    private func expenseItem(syncID: UUID) throws -> FlightExpense? {
        let expenses = try dataStore.fetch(FetchDescriptor<FlightExpense>())
        return expenses.first { $0.syncMetadata?.syncID == syncID }
    }

    private func clearUserData() throws {
        for flight in try dataStore.fetch(FetchDescriptor<Flight>()) {
            dataStore.delete(flight)
        }
        for endorsement in try dataStore.fetch(FetchDescriptor<Endorsement>()) {
            dataStore.delete(endorsement)
        }
        for item in try dataStore.fetch(FetchDescriptor<MaintenanceItem>()) {
            dataStore.delete(item)
        }
        for aircraft in try dataStore.fetch(FetchDescriptor<Aircraft>()) {
            if aircraft.registration.isEmpty == false {
                dataStore.delete(aircraft)
            }
        }
        try dataStore.save()
    }
}