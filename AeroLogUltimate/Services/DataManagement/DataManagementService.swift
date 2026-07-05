import Foundation

/// Facade for import, export, backup, and restore operations.
@MainActor
final class DataManagementService {
    let dataStore: DataStore
    let attachmentStorage: AttachmentStorageService

    private let importService: LogbookImportService
    private let exportService: LogbookExportService
    private let backupService: BackupRestoreService

    init(dataStore: DataStore, attachmentStorage: AttachmentStorageService) {
        self.dataStore = dataStore
        self.attachmentStorage = attachmentStorage
        self.importService = LogbookImportService(dataStore: dataStore)
        self.exportService = LogbookExportService(dataStore: dataStore)
        self.backupService = BackupRestoreService(
            dataStore: dataStore,
            attachmentStorage: attachmentStorage
        )
    }

    // MARK: - Import

    func detectFormat(for url: URL) -> LogbookImportFormat? {
        importService.detectFormat(for: url)
    }

    func importFile(
        at url: URL,
        strategy: BackupRestoreStrategy = .merge
    ) throws -> LogbookImportResult {
        let data = try Data(contentsOf: url)
        guard let format = detectFormat(for: url) else {
            throw DataManagementError.unsupportedFormat
        }
        return try importService.importData(data, format: format, strategy: strategy)
    }

    func importData(
        _ data: Data,
        format: LogbookImportFormat,
        strategy: BackupRestoreStrategy = .merge
    ) throws -> LogbookImportResult {
        try importService.importData(data, format: format, strategy: strategy)
    }

    // MARK: - Export

    func exportLogbook(
        format: LogbookExportFormat,
        filter: ReportFilter = .allTime
    ) throws -> LogbookExportResult {
        try exportService.export(format: format, filter: filter)
    }

    // MARK: - Backup & Restore

    func createBackup(includeAttachments: Bool = true) throws -> BackupCreationResult {
        try backupService.createBackup(includeAttachments: includeAttachments)
    }

    func restoreBackup(
        from url: URL,
        strategy: BackupRestoreStrategy = .merge
    ) throws -> BackupRestoreResult {
        try backupService.restoreBackup(from: url, strategy: strategy)
    }

    /// Produces an encrypted-ready payload for cloud sync (foundation for SyncCoordinator).
    func cloudBackupPayload() throws -> Data {
        let package = try BackupSnapshotBuilder(
            dataStore: dataStore,
            attachmentStorage: attachmentStorage
        ).buildPackage(includeAttachments: true)
        return try package.encode()
    }
}