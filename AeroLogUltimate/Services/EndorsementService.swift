import Foundation
import SwiftData

/// Endorsement lifecycle: creation, remote signing, signatures, and history.
@MainActor
final class EndorsementService {
    let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    // MARK: - Queries

    func allEndorsements(includeDeleted: Bool = false) throws -> [Endorsement] {
        let descriptor = FetchDescriptor<Endorsement>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let items = try dataStore.fetch(descriptor)
        if includeDeleted { return items }
        return items.filter { !($0.syncMetadata?.isSoftDeleted ?? false) }
    }

    func endorsementsForStudent(_ student: PilotProfile) throws -> [Endorsement] {
        try allEndorsements().filter { $0.student?.persistentModelID == student.persistentModelID }
    }

    func pendingForInstructor(_ instructor: PilotProfile) throws -> [Endorsement] {
        try allEndorsements().filter {
            $0.status == .pendingSignature
                && ($0.instructor?.persistentModelID == instructor.persistentModelID
                    || (instructor.isCFI && $0.instructor == nil))
        }
    }

    func endorsement(syncID: UUID) throws -> Endorsement? {
        try allEndorsements().first { $0.syncMetadata?.syncID == syncID }
    }

    // MARK: - Create

    @discardableResult
    func createFromBuiltInTemplate(
        _ definition: EndorsementTemplateDefinition,
        student: PilotProfile,
        instructor: PilotProfile?,
        values: [String: String],
        aircraft: Aircraft? = nil
    ) throws -> Endorsement {
        var merged = EndorsementTemplateCatalog.defaultValues(
            student: student,
            instructor: instructor,
            aircraft: aircraft
        )
        merged.merge(values) { _, new in new }

        let text = definition.renderedText(values: merged)
        let endorsement = Endorsement(
            templateID: definition.id,
            title: definition.title,
            endorsementText: text
        )
        endorsement.regulationReference = definition.regulationReference
        endorsement.student = student
        endorsement.instructor = instructor
        endorsement.studentNameSnapshot = student.fullName
        endorsement.instructorNameSnapshot = instructor?.fullName
        endorsement.filledPlaceholders = merged
        if let aircraft {
            endorsement.aircraftMakeModel = "\(aircraft.make) \(aircraft.model)"
            endorsement.aircraftCategory = aircraft.category
            endorsement.aircraftClass = aircraft.aircraftClass
        }
        dataStore.insert(endorsement)
        try dataStore.save()
        return endorsement
    }

    @discardableResult
    func createFromCustomTemplate(
        _ template: EndorsementTemplate,
        student: PilotProfile,
        instructor: PilotProfile?,
        values: [String: String]
    ) throws -> Endorsement {
        var merged = EndorsementTemplateCatalog.defaultValues(student: student, instructor: instructor)
        merged.merge(values) { _, new in new }

        var text = template.bodyText
        for (key, value) in merged {
            text = text.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        let endorsement = Endorsement(
            templateID: .custom,
            title: template.title,
            endorsementText: text
        )
        endorsement.regulationReference = template.regulationReference
        endorsement.customTemplateSyncID = template.syncID
        endorsement.student = student
        endorsement.instructor = instructor
        endorsement.studentNameSnapshot = student.fullName
        endorsement.instructorNameSnapshot = instructor?.fullName
        endorsement.filledPlaceholders = merged
        dataStore.insert(endorsement)
        try dataStore.save()
        return endorsement
    }

    // MARK: - Signing

    func requestRemoteSignature(for endorsement: Endorsement, instructor: PilotProfile) throws -> RemoteSigningPackage {
        let token = UUID().uuidString
        endorsement.instructor = instructor
        endorsement.instructorNameSnapshot = instructor.fullName
        endorsement.markPendingSignature(token: token)
        try dataStore.save()
        return RemoteSigningPackage(from: endorsement)
    }

    func sign(
        _ endorsement: Endorsement,
        signerName: String,
        certificateNumber: String,
        signatureData: Data?,
        instructor: PilotProfile? = nil
    ) throws {
        guard !certificateNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw EndorsementServiceError.certificateNumberRequired
        }
        guard signatureData != nil else {
            throw EndorsementServiceError.signatureRequired
        }

        if let instructor {
            endorsement.instructor = instructor
            endorsement.instructorNameSnapshot = instructor.fullName
        }

        endorsement.markSigned(
            signerName: signerName,
            certificateNumber: certificateNumber,
            signatureData: signatureData
        )
        try dataStore.save()
    }

    func applySignedPackage(_ package: RemoteSigningPackage) throws -> Endorsement {
        if let existing = try endorsement(syncID: package.endorsementSyncID) {
            try mergePackage(package, into: existing)
            return existing
        }

        if let byToken = try allEndorsements().first(where: { $0.remoteSigningToken == package.token }) {
            try mergePackage(package, into: byToken)
            return byToken
        }

        let endorsement = Endorsement(
            templateID: EndorsementTemplateID(rawValue: package.templateID) ?? .custom,
            title: package.title,
            endorsementText: package.endorsementText
        )
        endorsement.regulationReference = package.regulationReference
        endorsement.studentNameSnapshot = package.studentName
        endorsement.instructorNameSnapshot = package.instructorName
        endorsement.aircraftMakeModel = package.aircraftMakeModel
        endorsement.filledPlaceholders = package.filledPlaceholders
        endorsement.notes = package.notes
        endorsement.remoteSigningToken = package.token
        endorsement.remoteSigningRequestedAt = package.createdAt
        dataStore.insert(endorsement)
        try mergePackage(package, into: endorsement)
        return endorsement
    }

    private func mergePackage(_ package: RemoteSigningPackage, into endorsement: Endorsement) throws {
        if package.isSigned {
            endorsement.markSigned(
                signerName: package.signerName ?? "",
                certificateNumber: package.signerCertificateNumber ?? "",
                signatureData: package.signatureData,
                signedAt: package.signedAt ?? .now
            )
        } else {
            endorsement.markPendingSignature(token: package.token)
        }
        try dataStore.save()
    }

    func exportPackage(for endorsement: Endorsement, signatureData: Data? = nil) throws -> Data {
        try RemoteSigningPackage(from: endorsement, signatureData: signatureData).encode()
    }

    // MARK: - Lifecycle

    func save(_ endorsement: Endorsement) throws {
        endorsement.touch()
        try dataStore.save()
    }

    func revoke(_ endorsement: Endorsement) throws {
        endorsement.revoke()
        try dataStore.save()
    }

    func delete(_ endorsement: Endorsement) throws {
        endorsement.syncMetadata?.softDelete()
        try dataStore.save()
    }
}

enum EndorsementServiceError: LocalizedError {
    case certificateNumberRequired
    case signatureRequired
    case notFound

    var errorDescription: String? {
        switch self {
        case .certificateNumberRequired: "Instructor certificate number is required."
        case .signatureRequired: "A signature is required before completing the endorsement."
        case .notFound: "Endorsement not found."
        }
    }
}