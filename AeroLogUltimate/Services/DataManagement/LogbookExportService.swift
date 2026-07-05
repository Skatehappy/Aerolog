import Foundation
import SwiftData

/// Exports logbook data to CSV, JSON, and print-ready PDF via ReportExporter.
@MainActor
struct LogbookExportService {
    let dataStore: DataStore
    private let reportService: ReportService
    private let exporter = ReportExporter()

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        self.reportService = ReportService(dataStore: dataStore)
    }

    func export(
        format: LogbookExportFormat,
        filter: ReportFilter = .allTime,
        configuration: ReportConfiguration = .faaLogbook
    ) throws -> LogbookExportResult {
        switch format {
        case .csv:
            return try exportCSV(filter: filter, configuration: configuration)
        case .json:
            return try exportJSON(filter: filter)
        case .pdf:
            return try exportPDF(filter: filter, configuration: configuration)
        }
    }

    func exportCSV(
        filter: ReportFilter = .allTime,
        configuration: ReportConfiguration = .faaLogbook
    ) throws -> LogbookExportResult {
        let report = try reportService.generate(
            type: .flightLog,
            filter: filter,
            format: .csv,
            configuration: configuration
        )
        let data = try exporter.export(report)
        return LogbookExportResult(
            format: .csv,
            data: data,
            fileName: exporter.suggestedFileName(for: report),
            mimeType: "text/csv"
        )
    }

    func exportJSON(filter: ReportFilter = .allTime) throws -> LogbookExportResult {
        let package = try BackupSnapshotBuilder(dataStore: dataStore).buildPackage(includeAttachments: false)
        let data = try package.encode()
        return LogbookExportResult(
            format: .json,
            data: data,
            fileName: package.exportFileName,
            mimeType: "application/json"
        )
    }

    func exportPDF(
        filter: ReportFilter = .allTime,
        configuration: ReportConfiguration = .faaLogbook
    ) throws -> LogbookExportResult {
        let report = try reportService.generate(
            type: .flightLog,
            filter: filter,
            format: .pdf,
            configuration: configuration
        )
        let data = try exporter.export(report)
        return LogbookExportResult(
            format: .pdf,
            data: data,
            fileName: exporter.suggestedFileName(for: report),
            mimeType: "application/pdf"
        )
    }
}