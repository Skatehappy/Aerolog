import Foundation

// MARK: - Formats

enum LogbookImportFormat: String, Codable, CaseIterable, Sendable, Identifiable {
    case csv
    case aerologBackup
    case json

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .csv: "CSV Logbook"
        case .aerologBackup: "AeroLog Backup"
        case .json: "Structured JSON"
        }
    }

    var fileExtensions: [String] {
        switch self {
        case .csv: ["csv"]
        case .aerologBackup: ["aerologbackup", "json"]
        case .json: ["json"]
        }
    }
}

enum LogbookExportFormat: String, Codable, CaseIterable, Sendable, Identifiable {
    case csv
    case json
    case pdf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .csv: "CSV Spreadsheet"
        case .json: "Structured JSON"
        case .pdf: "Print-Ready PDF"
        }
    }

    var fileExtension: String { rawValue }
}

enum BackupRestoreStrategy: String, Codable, CaseIterable, Sendable {
    case merge
    case replaceAll
}

// MARK: - Results

struct LogbookImportResult: Sendable {
    let format: LogbookImportFormat
    let importedFlights: Int
    let importedAircraft: Int
    let skippedDuplicates: Int
    let warnings: [String]
}

struct LogbookExportResult: Sendable {
    let format: LogbookExportFormat
    let data: Data
    let fileName: String
    let mimeType: String
}

struct BackupCreationResult: Sendable {
    let package: AeroLogBackupPackage
    let archiveURL: URL
    let attachmentCount: Int
    let totalBytes: Int64
}

struct BackupRestoreResult: Sendable {
    let restoredFlights: Int
    let restoredAircraft: Int
    let restoredAttachments: Int
    let strategy: BackupRestoreStrategy
}

// MARK: - Portable Backup Package

/// Full portable snapshot of AeroLog data for backup, restore, and cloud sync foundations.
struct AeroLogBackupPackage: Codable, Identifiable, Sendable {
    let version: Int
    let createdAt: Date
    let schemaVersion: String
    let appName: String
    let includesAttachments: Bool
    let manifest: BackupManifest
    let pilots: [PortablePilotProfile]
    let aircraft: [PortableAircraft]
    let flights: [PortableFlight]
    let endorsements: [PortableEndorsement]
    let attachments: [PortableAttachment]

    var id: String { manifest.backupID }

    static let currentVersion = 1

    init(
        createdAt: Date = .now,
        includesAttachments: Bool,
        pilots: [PortablePilotProfile],
        aircraft: [PortableAircraft],
        flights: [PortableFlight],
        endorsements: [PortableEndorsement] = [],
        attachments: [PortableAttachment] = []
    ) {
        version = Self.currentVersion
        self.createdAt = createdAt
        schemaVersion = AeroLogSchema.versionIdentifier
        appName = SettingsStore.appName
        self.includesAttachments = includesAttachments
        manifest = BackupManifest(
            backupID: UUID().uuidString,
            entityCounts: BackupEntityCounts(
                pilots: pilots.count,
                aircraft: aircraft.count,
                flights: flights.count,
                endorsements: endorsements.count,
                attachments: attachments.count
            )
        )
        self.pilots = pilots
        self.aircraft = aircraft
        self.flights = flights
        self.endorsements = endorsements
        self.attachments = attachments
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> AeroLogBackupPackage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AeroLogBackupPackage.self, from: data)
    }

    var exportFileName: String {
        let date = createdAt.formatted(.iso8601.year().month().day())
        return "AeroLog_Backup_\(date).\(includesAttachments ? "aerologbackup" : "json")"
    }
}

struct BackupManifest: Codable, Sendable {
    let backupID: String
    let entityCounts: BackupEntityCounts
}

struct BackupEntityCounts: Codable, Sendable {
    let pilots: Int
    let aircraft: Int
    let flights: Int
    let endorsements: Int
    let attachments: Int
}

// MARK: - Portable Entities

struct PortableSyncMetadata: Codable, Sendable {
    let syncID: UUID
    let revision: Int
    let lastModifiedAt: Date
}

struct PortablePilotProfile: Codable, Sendable {
    let syncID: UUID
    let firstName: String
    let lastName: String
    let email: String?
    let isPrimaryProfile: Bool
    let isCFI: Bool
    let certificateNumber: String?
    let certificateType: CertificateType?
    let cfiCertificateNumber: String?
    let homeAirportICAO: String?
}

struct PortableAircraft: Codable, Sendable {
    let syncID: UUID
    let registration: String
    let make: String
    let model: String
    let category: AircraftCategory
    let aircraftClass: AircraftClass
    let simulatorLevel: SimulatorLevel
    let isActive: Bool
}

struct PortableFlightLeg: Codable, Sendable {
    let legOrder: Int
    let departureICAO: String
    let arrivalICAO: String
    let legTime: Double
}

struct PortableInstrumentApproach: Codable, Sendable {
    let approachType: ApproachType
    let airportICAO: String?
    let approachCount: Int
}

struct PortableFlight: Codable, Sendable {
    let syncID: UUID
    let pilotSyncID: UUID?
    let aircraftSyncID: UUID?
    let flightDate: Date
    let status: FlightStatus
    let role: FlightRole
    let departureICAO: String
    let arrivalICAO: String
    let route: String?
    let totalTime: Double
    let picTime: Double
    let sicTime: Double
    let dualReceived: Double
    let dualGiven: Double
    let soloTime: Double
    let crossCountryTime: Double
    let nightTime: Double
    let actualInstrumentTime: Double
    let simulatedInstrumentTime: Double
    let groundInstructionTime: Double
    let simulatorTime: Double
    let dayLandings: Int
    let nightLandings: Int
    let fullStopDayLandings: Int
    let fullStopNightLandings: Int
    let holds: Int
    let conditionsRaw: [String]
    let instructorName: String?
    let instructorCertificateNumber: String?
    let remarks: String?
    let externalID: String?
    let legs: [PortableFlightLeg]
    let approaches: [PortableInstrumentApproach]
}

struct PortableEndorsement: Codable, Sendable {
    let syncID: UUID
    let studentSyncID: UUID?
    let instructorSyncID: UUID?
    let templateID: String
    let title: String
    let endorsementText: String
    let status: EndorsementStatus
    let issuedDate: Date?
    let studentNameSnapshot: String?
    let instructorNameSnapshot: String?
}

struct PortableAttachment: Codable, Sendable {
    let syncID: UUID
    let flightSyncID: UUID?
    let kind: AttachmentKind
    let linkType: AttachmentLinkType
    let fileName: String
    let mimeType: String
    let fileSizeBytes: Int64
    let relativeStoragePath: String
    let fileDataBase64: String?
}

// MARK: - CSV Import Row

struct CSVFlightImportRow: Sendable {
    var flightDate: Date?
    var aircraftRegistration: String?
    var departureICAO: String?
    var arrivalICAO: String?
    var route: String?
    var role: FlightRole?
    var totalTime: Double?
    var picTime: Double?
    var sicTime: Double?
    var dualReceived: Double?
    var dualGiven: Double?
    var soloTime: Double?
    var crossCountryTime: Double?
    var nightTime: Double?
    var actualInstrumentTime: Double?
    var simulatedInstrumentTime: Double?
    var groundInstructionTime: Double?
    var simulatorTime: Double?
    var dayLandings: Int?
    var nightLandings: Int?
    var instructorName: String?
    var remarks: String?
    var externalID: String?
}

enum DataManagementError: LocalizedError {
    case unsupportedFormat
    case emptyImport
    case invalidBackup(String)
    case backupTooOld(Int)
    case restoreFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            "The selected file format is not supported."
        case .emptyImport:
            "No logbook entries were found in the import file."
        case .invalidBackup(let reason):
            "Invalid backup file: \(reason)"
        case .backupTooOld(let version):
            "Backup version \(version) is not supported by this app version."
        case .restoreFailed(let reason):
            "Restore failed: \(reason)"
        case .exportFailed(let reason):
            "Export failed: \(reason)"
        }
    }
}