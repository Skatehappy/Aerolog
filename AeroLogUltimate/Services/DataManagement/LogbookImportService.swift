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

    func previewCSV(_ data: Data) throws -> CSVImportPreview {
        let rows = try csvImporter.parse(data)
        let headers = try csvHeaderLine(from: data)
        let source = csvImporter.detectSource(headers: headers)
        let inferred = rows.filter(\.totalTimeWasInferred).count
        let duplicates = try countDuplicateRows(in: rows)
        return CSVImportPreview(
            sourceFormat: source,
            rows: rows,
            inferredTotalTimeCount: inferred,
            duplicateCount: duplicates
        )
    }

    func importCSVRows(
        _ rows: [CSVFlightImportRow],
        strategy: BackupRestoreStrategy = .merge
    ) throws -> LogbookImportResult {
        if strategy == .replaceAll {
            try clearUserData()
        }
        return try commitCSVRows(rows, strategy: strategy)
    }

    func importCSV(
        _ data: Data,
        strategy: BackupRestoreStrategy = .merge
    ) throws -> LogbookImportResult {
        let rows = try csvImporter.parse(data)
        if strategy == .replaceAll {
            try clearUserData()
        }
        return try commitCSVRows(rows, strategy: strategy)
    }

    private func commitCSVRows(
        _ rows: [CSVFlightImportRow],
        strategy: BackupRestoreStrategy
    ) throws -> LogbookImportResult {
        let pilot = try dataStore.primaryPilotProfile()
        var importedFlights = 0
        var importedAircraft = 0
        var skipped = 0
        var warnings: [String] = []

        let inferredCount = rows.filter(\.totalTimeWasInferred).count
        if inferredCount > 0 {
            warnings.append("\(inferredCount) flight(s) had total time inferred from PIC/dual/solo columns.")
        }

        var aircraftCache = try buildAircraftCache()
        // M4: index existing external IDs once rather than scanning every flight
        // per row (O(n²) → O(n)). Grows as we insert so intra-file dupes still skip.
        var seenExternalIDs = Set(try dataStore.fetch(FetchDescriptor<Flight>()).compactMap { $0.externalID })

        for row in rows {
            if let externalID = row.externalID, seenExternalIDs.contains(externalID) {
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
            flight.fullStopDayLandings = row.fullStopDayLandings ?? 0
            flight.fullStopNightLandings = row.fullStopNightLandings ?? 0
            flight.holds = row.holds ?? 0
            flight.instructorName = row.instructorName
            flight.remarks = row.remarks
            flight.externalID = row.externalID
            flight.finalize()

            dataStore.insert(flight)

            // C1: synthesize an approach record so instrument currency counts the
            // imported approaches (the engine sums InstrumentApproach.approachCount).
            if let approaches = row.approachCount, approaches > 0 {
                let airport = flight.arrivalICAO.isEmpty ? flight.departureICAO : flight.arrivalICAO
                let approach = InstrumentApproach(
                    approachType: .other,
                    airportICAO: airport.isEmpty ? nil : airport,
                    approachCount: approaches
                )
                approach.flight = flight
                dataStore.insert(approach)
            }

            if let externalID = row.externalID { seenExternalIDs.insert(externalID) }
            importedFlights += 1
        }

        // C1: if the source carried no full-stop / hold / approach data but did
        // carry night or instrument time, warn that those currencies can't be
        // computed from it — rather than silently showing NOT CURRENT.
        let hasCurrencyDetail = rows.contains {
            ($0.fullStopDayLandings ?? 0) > 0 || ($0.fullStopNightLandings ?? 0) > 0
                || ($0.holds ?? 0) > 0 || ($0.approachCount ?? 0) > 0
        }
        let hasNightOrInstrument = rows.contains {
            ($0.nightLandings ?? 0) > 0 || ($0.nightTime ?? 0) > 0
                || ($0.actualInstrumentTime ?? 0) > 0 || ($0.simulatedInstrumentTime ?? 0) > 0
        }
        if !hasCurrencyDetail && hasNightOrInstrument {
            warnings.append("This file has no full-stop landing columns — night, tailwheel, and class landing currency cannot be computed from imported flights.")
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

        // M4: index existing records by syncID ONCE. The merge branches below
        // otherwise re-fetched an entire table per package record (O(n²)), which
        // froze the UI for minutes on a large restore.
        let existingProfiles = indexBySyncID(try dataStore.fetch(FetchDescriptor<PilotProfile>())) { $0.syncMetadata?.syncID }
        let existingAircraft = indexBySyncID(try dataStore.fetch(FetchDescriptor<Aircraft>())) { $0.syncMetadata?.syncID }
        let existingFlights = indexBySyncID(try dataStore.fetch(FetchDescriptor<Flight>())) { $0.syncMetadata?.syncID }
        let existingMaintenance = indexBySyncID(try dataStore.fetch(FetchDescriptor<MaintenanceItem>())) { $0.syncMetadata?.syncID }
        let existingExpenses = indexBySyncID(try dataStore.fetch(FetchDescriptor<FlightExpense>())) { $0.syncMetadata?.syncID }
        let existingEndorsements = indexBySyncID(try dataStore.fetch(FetchDescriptor<Endorsement>())) { $0.syncMetadata?.syncID }

        var pilotMap: [UUID: PilotProfile] = [:]
        for portable in package.pilots {
            if strategy == .merge, let existing = existingProfiles[portable.syncID] {
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
            if strategy == .merge, let existing = existingAircraft[portable.syncID] {
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
                if strategy == .merge, existingMaintenance[item.syncID] != nil {
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
            if strategy == .merge, let existing = existingFlights[portable.syncID] {
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
            // H4: restore the fields v1 backups dropped. Optional → old backups
            // (nil) fall back to the previous behavior without crashing.
            flight.hobbsStart = portable.hobbsStart
            flight.hobbsEnd = portable.hobbsEnd
            flight.tachStart = portable.tachStart
            flight.tachEnd = portable.tachEnd
            flight.lessonTitle = portable.lessonTitle
            flight.lessonNumber = portable.lessonNumber
            flight.maneuversPracticed = portable.maneuversPracticed
            if let editHistoryJSON = portable.editHistoryJSON {
                flight.editHistoryJSON = editHistoryJSON
            }
            if let createdAt = portable.createdAt {
                flight.createdAt = createdAt
            }
            if portable.status == .finalized {
                // L5/H4: preserve the original finalization timestamp; only fall
                // back to flightDate for pre-v2 backups that didn't carry it.
                flight.finalizedAt = portable.finalizedAt ?? portable.flightDate
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
                if strategy == .merge, existingExpenses[expense.syncID] != nil {
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
            if strategy == .merge, existingEndorsements[portable.syncID] != nil {
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

        // C2: a restored package can carry its own primary pilot alongside the
        // seeded blank one. Collapse to a single primary (the one that owns the
        // restored flights) so currency/reports/new-flights bind correctly.
        try dataStore.reconcilePrimaryProfiles()

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

    /// M4: build a syncID → model index once so restore merge checks are O(1).
    private func indexBySyncID<T>(_ models: [T], _ syncID: (T) -> UUID?) -> [UUID: T] {
        var map: [UUID: T] = [:]
        for model in models {
            if let id = syncID(model) { map[id] = model }
        }
        return map
    }

    private func csvHeaderLine(from data: Data) throws -> [String] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw DataManagementError.unsupportedFormat
        }
        guard let firstLine = text.split(whereSeparator: \.isNewline).first else {
            throw DataManagementError.emptyImport
        }
        return firstLine.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func countDuplicateRows(in rows: [CSVFlightImportRow]) throws -> Int {
        // M4: index once instead of scanning all flights per row.
        let existing = Set(try dataStore.fetch(FetchDescriptor<Flight>()).compactMap { $0.externalID })
        return rows.reduce(0) { count, row in
            if let externalID = row.externalID, existing.contains(externalID) { return count + 1 }
            return count
        }
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
        // M6: delete ALL aircraft — the previous `registration.isEmpty == false`
        // guard left blank-registration aircraft behind as orphans.
        for aircraft in try dataStore.fetch(FetchDescriptor<Aircraft>()) {
            dataStore.delete(aircraft)
        }
        // M6: remove attachment records and their on-disk files so pilot/report
        // linked attachments don't survive as orphans pointing at deleted files.
        let storage = AttachmentStorageService()
        for attachment in try dataStore.fetch(FetchDescriptor<Attachment>()) {
            try? storage.delete(relativePath: attachment.relativeStoragePath)
            dataStore.delete(attachment)
        }
        try dataStore.save()
    }
}