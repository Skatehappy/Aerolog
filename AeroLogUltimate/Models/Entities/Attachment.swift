import Foundation
import SwiftData

/// File attachment linked to flights, endorsements, aircraft, or reports.
///
/// Binary payload is stored on disk; this model holds metadata and the local path reference.
@Model
final class Attachment {
    var kind: AttachmentKind
    var linkType: AttachmentLinkType

    var fileName: String
    var mimeType: String
    var fileSizeBytes: Int64

    /// Relative path within the app's attachments directory.
    var relativeStoragePath: String

    /// Optional inline thumbnail for quick gallery display.
    @Attribute(.externalStorage)
    var thumbnailData: Data?

    var caption: String?
    var sortOrder: Int

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    // MARK: Polymorphic Links (exactly one should be set)

    @Relationship(deleteRule: .nullify)
    var flight: Flight?

    @Relationship(deleteRule: .nullify)
    var endorsement: Endorsement?

    @Relationship(deleteRule: .nullify)
    var aircraft: Aircraft?

    @Relationship(deleteRule: .nullify)
    var pilotProfile: PilotProfile?

    @Relationship(deleteRule: .nullify)
    var report: ReportDefinition?

    init(
        kind: AttachmentKind,
        linkType: AttachmentLinkType,
        fileName: String,
        mimeType: String,
        fileSizeBytes: Int64,
        relativeStoragePath: String
    ) {
        self.kind = kind
        self.linkType = linkType
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileSizeBytes = fileSizeBytes
        self.relativeStoragePath = relativeStoragePath
        self.sortOrder = 0
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}