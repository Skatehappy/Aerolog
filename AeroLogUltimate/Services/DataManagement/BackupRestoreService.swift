import Foundation
import SwiftData

/// Creates and restores full local backups including attachment binaries.
@MainActor
struct BackupRestoreService {
    let dataStore: DataStore
    let attachmentStorage: AttachmentStorageService
    private let importService: LogbookImportService

    init(dataStore: DataStore, attachmentStorage: AttachmentStorageService) {
        self.dataStore = dataStore
        self.attachmentStorage = attachmentStorage
        self.importService = LogbookImportService(dataStore: dataStore)
    }

    func createBackup(includeAttachments: Bool = true) throws -> BackupCreationResult {
        let builder = BackupSnapshotBuilder(dataStore: dataStore, attachmentStorage: attachmentStorage)
        let package = try builder.buildPackage(includeAttachments: includeAttachments)
        let archiveURL = try writeArchive(package: package, includeAttachments: includeAttachments)

        let totalBytes: Int64
        if let attributes = try? FileManager.default.attributesOfItem(atPath: archiveURL.path),
           let size = attributes[.size] as? Int64 {
            totalBytes = size
        } else {
            totalBytes = Int64((try? package.encode().count) ?? 0)
        }

        return BackupCreationResult(
            package: package,
            archiveURL: archiveURL,
            attachmentCount: package.attachments.count,
            totalBytes: totalBytes
        )
    }

    func restoreBackup(
        from url: URL,
        strategy: BackupRestoreStrategy = .merge
    ) throws -> BackupRestoreResult {
        let package: AeroLogBackupPackage
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true

        if isDirectory {
            let dataURL = url.appendingPathComponent("package.json")
            let attachmentRoot = url.appendingPathComponent("attachments", isDirectory: true)
            let rawData = try Data(contentsOf: dataURL)
            package = try AeroLogBackupPackage.decode(from: rawData)
            try restoreAttachmentFiles(from: attachmentRoot, package: package)
        } else {
            let rawData = try Data(contentsOf: url)
            package = try AeroLogBackupPackage.decode(from: rawData)
            try restoreEmbeddedAttachments(package: package)
        }

        let importResult = try importService.importBackupPackage(package, strategy: strategy)
        let restoredAttachments = try restoreAttachmentRecords(package: package, strategy: strategy)
        return BackupRestoreResult(
            restoredFlights: importResult.importedFlights,
            restoredAircraft: importResult.importedAircraft,
            restoredAttachments: restoredAttachments,
            strategy: strategy
        )
    }

    private func restoreAttachmentRecords(
        package: AeroLogBackupPackage,
        strategy: BackupRestoreStrategy
    ) throws -> Int {
        var restored = 0
        let flights = try dataStore.fetch(FetchDescriptor<Flight>())
        let flightMap = Dictionary(
            uniqueKeysWithValues: flights.compactMap { flight -> (UUID, Flight)? in
                guard let syncID = flight.syncMetadata?.syncID else { return nil }
                return (syncID, flight)
            }
        )

        for portable in package.attachments {
            if strategy == .merge {
                let existing = try dataStore.fetch(FetchDescriptor<Attachment>())
                if existing.contains(where: { $0.syncMetadata?.syncID == portable.syncID }) {
                    continue
                }
            }

            let attachment = Attachment(
                kind: portable.kind,
                linkType: portable.linkType,
                fileName: portable.fileName,
                mimeType: portable.mimeType,
                fileSizeBytes: portable.fileSizeBytes,
                relativeStoragePath: portable.relativeStoragePath
            )
            attachment.syncMetadata?.syncID = portable.syncID
            if let flightSyncID = portable.flightSyncID {
                attachment.flight = flightMap[flightSyncID]
            }
            dataStore.insert(attachment)
            restored += 1
        }

        if restored > 0 {
            try dataStore.save()
        }
        return restored
    }

    // MARK: - Archive IO

    private func backupTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    private func writeArchive(package: AeroLogBackupPackage, includeAttachments: Bool) throws -> URL {
        let fileManager = FileManager.default
        let timestamp = backupTimestamp(from: package.createdAt)
        let baseName = "AeroLog_Backup_\(timestamp)"

        if includeAttachments && !package.attachments.isEmpty {
            let directory = SettingsStore.backupsDirectory
                .appendingPathComponent("\(baseName).aerologbackup", isDirectory: true)
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let packageURL = directory.appendingPathComponent("package.json")
            try package.encode().write(to: packageURL, options: .atomic)

            let attachmentsDir = directory.appendingPathComponent("attachments", isDirectory: true)
            try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

            for attachment in package.attachments {
                guard let base64 = attachment.fileDataBase64,
                      let data = Data(base64Encoded: base64) else { continue }
                let destination = attachmentsDir.appendingPathComponent(attachment.relativeStoragePath)
                try fileManager.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: destination, options: .atomic)
            }
            return directory
        }

        let fileURL = SettingsStore.backupsDirectory.appendingPathComponent("\(baseName).json")
        try package.encode().write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func restoreEmbeddedAttachments(package: AeroLogBackupPackage) throws {
        for portable in package.attachments {
            guard let base64 = portable.fileDataBase64,
                  let data = Data(base64Encoded: base64) else { continue }
            try attachmentStorage.write(data: data, relativePath: portable.relativeStoragePath)
        }
    }

    private func restoreAttachmentFiles(from root: URL, package: AeroLogBackupPackage) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else { return }

        for portable in package.attachments {
            let source = root.appendingPathComponent(portable.relativeStoragePath)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let data = try Data(contentsOf: source)
            try attachmentStorage.write(data: data, relativePath: portable.relativeStoragePath)
        }
    }
}

// MARK: - Snapshot Builder

@MainActor
struct BackupSnapshotBuilder {
    let dataStore: DataStore
    let attachmentStorage: AttachmentStorageService?

    init(dataStore: DataStore, attachmentStorage: AttachmentStorageService? = nil) {
        self.dataStore = dataStore
        self.attachmentStorage = attachmentStorage
    }

    func buildPackage(includeAttachments: Bool) throws -> AeroLogBackupPackage {
        let pilots = try dataStore.fetch(FetchDescriptor<PilotProfile>()).map(portablePilot)
        let aircraft = try dataStore.fetch(FetchDescriptor<Aircraft>()).map(portableAircraft)
        let flights = try dataStore.fetch(FetchDescriptor<Flight>()).compactMap(portableFlight)
        let endorsements = try dataStore.fetch(FetchDescriptor<Endorsement>()).map(portableEndorsement)
        let attachments = includeAttachments
            ? try dataStore.fetch(FetchDescriptor<Attachment>()).compactMap(portableAttachment)
            : []

        return AeroLogBackupPackage(
            includesAttachments: includeAttachments,
            pilots: pilots,
            aircraft: aircraft,
            flights: flights,
            endorsements: endorsements,
            attachments: attachments
        )
    }

    private func portablePilot(_ profile: PilotProfile) -> PortablePilotProfile {
        PortablePilotProfile(
            syncID: profile.syncMetadata?.syncID ?? UUID(),
            firstName: profile.firstName,
            lastName: profile.lastName,
            email: profile.email,
            isPrimaryProfile: profile.isPrimaryProfile,
            isCFI: profile.isCFI,
            certificateNumber: profile.certificateNumber,
            certificateType: profile.certificateType,
            cfiCertificateNumber: profile.cfiCertificateNumber,
            homeAirportICAO: profile.homeAirportICAO
        )
    }

    private func portableAircraft(_ aircraft: Aircraft) -> PortableAircraft {
        PortableAircraft(
            syncID: aircraft.syncMetadata?.syncID ?? UUID(),
            registration: aircraft.registration,
            make: aircraft.make,
            model: aircraft.model,
            category: aircraft.category,
            aircraftClass: aircraft.aircraftClass,
            simulatorLevel: aircraft.simulatorLevel,
            isActive: aircraft.isActive
        )
    }

    private func portableFlight(_ flight: Flight) -> PortableFlight? {
        guard !(flight.syncMetadata?.isSoftDeleted ?? false) else { return nil }
        let legs = (flight.legs ?? []).sorted { $0.legOrder < $1.legOrder }.map {
            PortableFlightLeg(
                legOrder: $0.legOrder,
                departureICAO: $0.departureICAO,
                arrivalICAO: $0.arrivalICAO,
                legTime: $0.legTime
            )
        }
        let approaches = (flight.approaches ?? []).map {
            PortableInstrumentApproach(
                approachType: $0.approachType,
                airportICAO: $0.airportICAO,
                approachCount: $0.approachCount
            )
        }

        return PortableFlight(
            syncID: flight.syncMetadata?.syncID ?? UUID(),
            pilotSyncID: flight.pilot?.syncMetadata?.syncID,
            aircraftSyncID: flight.aircraft?.syncMetadata?.syncID,
            flightDate: flight.flightDate,
            status: flight.status,
            role: flight.role,
            departureICAO: flight.departureICAO,
            arrivalICAO: flight.arrivalICAO,
            route: flight.route,
            totalTime: flight.totalTime,
            picTime: flight.picTime,
            sicTime: flight.sicTime,
            dualReceived: flight.dualReceived,
            dualGiven: flight.dualGiven,
            soloTime: flight.soloTime,
            crossCountryTime: flight.crossCountryTime,
            nightTime: flight.nightTime,
            actualInstrumentTime: flight.actualInstrumentTime,
            simulatedInstrumentTime: flight.simulatedInstrumentTime,
            groundInstructionTime: flight.groundInstructionTime,
            simulatorTime: flight.simulatorTime,
            dayLandings: flight.dayLandings,
            nightLandings: flight.nightLandings,
            fullStopDayLandings: flight.fullStopDayLandings,
            fullStopNightLandings: flight.fullStopNightLandings,
            holds: flight.holds,
            conditionsRaw: flight.conditionsRaw,
            instructorName: flight.instructorName,
            instructorCertificateNumber: flight.instructorCertificateNumber,
            remarks: flight.remarks,
            externalID: flight.externalID,
            legs: legs,
            approaches: approaches
        )
    }

    private func portableEndorsement(_ endorsement: Endorsement) -> PortableEndorsement {
        PortableEndorsement(
            syncID: endorsement.syncMetadata?.syncID ?? UUID(),
            studentSyncID: endorsement.student?.syncMetadata?.syncID,
            instructorSyncID: endorsement.instructor?.syncMetadata?.syncID,
            templateID: endorsement.templateID.rawValue,
            title: endorsement.title,
            endorsementText: endorsement.endorsementText,
            status: endorsement.status,
            issuedDate: endorsement.issuedDate,
            studentNameSnapshot: endorsement.studentNameSnapshot,
            instructorNameSnapshot: endorsement.instructorNameSnapshot
        )
    }

    private func portableAttachment(_ attachment: Attachment) -> PortableAttachment? {
        var fileDataBase64: String?
        if let storage = attachmentStorage {
            fileDataBase64 = try? storage.read(relativePath: attachment.relativeStoragePath).base64EncodedString()
        }
        return PortableAttachment(
            syncID: attachment.syncMetadata?.syncID ?? UUID(),
            flightSyncID: attachment.flight?.syncMetadata?.syncID,
            kind: attachment.kind,
            linkType: attachment.linkType,
            fileName: attachment.fileName,
            mimeType: attachment.mimeType,
            fileSizeBytes: attachment.fileSizeBytes,
            relativeStoragePath: attachment.relativeStoragePath,
            fileDataBase64: fileDataBase64
        )
    }
}