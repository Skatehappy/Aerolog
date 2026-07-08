import Foundation
import SwiftData

/// The primary pilot identity for the logbook owner or a linked student/CFI contact.
@Model
final class PilotProfile {
    // MARK: Identity

    var firstName: String
    var lastName: String
    var email: String?
    var phone: String?

    /// When true, this profile represents the device owner's logbook identity.
    var isPrimaryProfile: Bool

    /// When true, this profile is a CFI who instructs students.
    var isCFI: Bool

    // MARK: Certificates

    var certificateNumber: String?
    var certificateType: CertificateType?
    var ratingsRaw: [String]
    var certificateIssueDate: Date?
    var certificateExpirationDate: Date?

    // MARK: CFI Credentials

    var cfiCertificateNumber: String?
    var cfiExpirationDate: Date?
    var cfiRenewalDate: Date?

    // MARK: Medical

    var medicalClass: MedicalClass?
    var medicalIssueDate: Date?
    var medicalExpirationDate: Date?
    // F1 BasicMed (schema 1.4.0, additive with defaults).
    var medicalMode: MedicalMode = MedicalMode.classMedical
    var basicMedExamDate: Date?
    var basicMedCourseDate: Date?
    // F2 recency sources (schema 1.4.0, additive with defaults).
    var flightReviewSource: FlightReviewSource = FlightReviewSource.flightReview
    var ipcSource: IPCSource = IPCSource.ipc

    // MARK: Recency Events (supplement logbook-derived currency)

    /// Date of last completed Flight Review (61.56), when not inferred from endorsements.
    var lastFlightReviewDate: Date?

    /// Date of last Instrument Proficiency Check (61.57(d)).
    var lastIPCDate: Date?

    // MARK: Address (optional, for 8710 / reports)

    var addressLine1: String?
    var addressLine2: String?
    var city: String?
    var state: String?
    var postalCode: String?
    var country: String?

    // MARK: Preferences

    var homeAirportICAO: String?
    var notes: String?

    // MARK: Audit

    var createdAt: Date
    var updatedAt: Date

    // MARK: Sync

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    // MARK: Relationships

    /// Flights logged as this pilot's own experience.
    @Relationship(deleteRule: .nullify, inverse: \Flight.pilot)
    var flights: [Flight]?

    /// Flights where this pilot was the instructor of record.
    @Relationship(deleteRule: .nullify, inverse: \Flight.instructor)
    var instructedFlights: [Flight]?

    /// Endorsements received by this pilot (typically a student).
    @Relationship(deleteRule: .nullify, inverse: \Endorsement.student)
    var endorsementsReceived: [Endorsement]?

    /// Endorsements issued by this pilot (typically a CFI).
    @Relationship(deleteRule: .nullify, inverse: \Endorsement.instructor)
    var endorsementsIssued: [Endorsement]?

    /// Active training relationships where this pilot is the student.
    @Relationship(deleteRule: .nullify, inverse: \TrainingRelationship.student)
    var trainingAsStudent: [TrainingRelationship]?

    /// Active training relationships where this pilot is the CFI.
    @Relationship(deleteRule: .nullify, inverse: \TrainingRelationship.instructor)
    var trainingAsInstructor: [TrainingRelationship]?

    @Relationship(deleteRule: .nullify, inverse: \CurrencySnapshot.pilot)
    var currencySnapshots: [CurrencySnapshot]?

    @Relationship(deleteRule: .nullify, inverse: \ReportDefinition.owner)
    var reportDefinitions: [ReportDefinition]?

    // MARK: Computed

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var ratings: [PilotRating] {
        ratingsRaw.compactMap { PilotRating(rawValue: $0) }
    }

    // MARK: Init

    init(
        firstName: String = "",
        lastName: String = "",
        isPrimaryProfile: Bool = false,
        isCFI: Bool = false
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.isPrimaryProfile = isPrimaryProfile
        self.isCFI = isCFI
        self.ratingsRaw = []
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func setRatings(_ ratings: [PilotRating]) {
        ratingsRaw = ratings.map(\.rawValue)
        touch()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}