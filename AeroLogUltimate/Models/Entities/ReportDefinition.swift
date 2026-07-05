import Foundation
import SwiftData

/// Saved report configuration for repeatable exports and analytics.
@Model
final class ReportDefinition {
    var name: String
    var reportType: ReportType
    var outputFormat: ReportOutputFormat
    var isTemplate: Bool
    var isFavorite: Bool

    /// JSON-encoded filter criteria (date range, aircraft, role, etc.).
    var filterJSON: String?

    /// JSON-encoded column/field selection for custom reports.
    var columnsJSON: String?

    /// JSON-encoded sort and grouping preferences.
    var layoutJSON: String?

    var notes: String?

    var createdAt: Date
    var updatedAt: Date
    var lastGeneratedAt: Date?

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    @Relationship(deleteRule: .nullify)
    var owner: PilotProfile?

    @Relationship(deleteRule: .nullify, inverse: \Attachment.report)
    var attachments: [Attachment]?

    init(
        name: String,
        reportType: ReportType = .custom,
        outputFormat: ReportOutputFormat = .pdf
    ) {
        self.name = name
        self.reportType = reportType
        self.outputFormat = outputFormat
        self.isTemplate = false
        self.isFavorite = false
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }

    func markGenerated(at date: Date = .now) {
        lastGeneratedAt = date
        touch()
    }
}