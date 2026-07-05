import Foundation
import SwiftData

/// CFI endorsement issued to a student, with optional digital signature workflow.
@Model
final class Endorsement {
    // MARK: Template

    var templateID: EndorsementTemplateID
    var title: String
    var endorsementText: String
    var regulationReference: String?

    // MARK: Status

    var status: EndorsementStatus
    var issuedDate: Date?
    var expirationDate: Date?

    // MARK: Aircraft Context

    var aircraftMakeModel: String?
    var aircraftCategory: AircraftCategory?
    var aircraftClass: AircraftClass?

    // MARK: Remote Signing

    var remoteSigningToken: String?
    var remoteSigningRequestedAt: Date?
    var remoteSigningCompletedAt: Date?

    // MARK: Signature Storage

    /// PNG/SVG signature image data (Apple Pencil capture in Phase 3).
    @Attribute(.externalStorage)
    var signatureImageData: Data?

    var signedAt: Date?
    var signerName: String?
    var signerCertificateNumber: String?

    // MARK: Template Fields

    /// Sync ID of a user-created `EndorsementTemplate`, when applicable.
    var customTemplateSyncID: UUID?

    /// JSON map of filled placeholder values.
    var filledPlaceholdersJSON: String?

    // MARK: Denormalized (for export / history)

    var studentNameSnapshot: String?
    var instructorNameSnapshot: String?

    // MARK: Notes

    var notes: String?

    // MARK: Audit

    var createdAt: Date
    var updatedAt: Date

    // MARK: Sync

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    // MARK: Relationships

    @Relationship(deleteRule: .nullify)
    var student: PilotProfile?

    @Relationship(deleteRule: .nullify)
    var instructor: PilotProfile?

    @Relationship(deleteRule: .nullify, inverse: \Attachment.endorsement)
    var attachments: [Attachment]?

    init(
        templateID: EndorsementTemplateID = .custom,
        title: String = "",
        endorsementText: String = ""
    ) {
        self.templateID = templateID
        self.title = title
        self.endorsementText = endorsementText
        self.status = .draft
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }

    func markSigned(
        signerName: String,
        certificateNumber: String,
        signatureData: Data?,
        signedAt: Date = .now
    ) {
        self.signerName = signerName
        self.signerCertificateNumber = certificateNumber
        self.signatureImageData = signatureData
        self.signedAt = signedAt
        self.status = .signed
        self.issuedDate = signedAt
        remoteSigningCompletedAt = .now
        touch()
    }

    func markPendingSignature(token: String) {
        remoteSigningToken = token
        remoteSigningRequestedAt = .now
        status = .pendingSignature
        touch()
    }

    func revoke() {
        status = .revoked
        touch()
    }

    var syncID: UUID {
        syncMetadata?.syncID ?? UUID()
    }
}