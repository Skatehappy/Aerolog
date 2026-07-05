import Foundation

/// Portable endorsement package for remote CFI signing between devices.
struct RemoteSigningPackage: Codable, Identifiable, Sendable {
    let version: Int
    let token: String
    let createdAt: Date
    let endorsementSyncID: UUID

    let templateID: String
    let title: String
    let endorsementText: String
    let regulationReference: String?

    let studentName: String
    let instructorName: String?
    let instructorCertificateNumber: String?

    let aircraftMakeModel: String?
    let filledPlaceholders: [String: String]
    let notes: String?

    var isSigned: Bool
    let signedAt: Date?
    let signerName: String?
    let signerCertificateNumber: String?
    let signatureImageBase64: String?

    var id: String { token }

    static let currentVersion = 1

    init(from endorsement: Endorsement, signatureData: Data? = nil) {
        version = Self.currentVersion
        token = endorsement.remoteSigningToken ?? UUID().uuidString
        createdAt = endorsement.remoteSigningRequestedAt ?? endorsement.createdAt
        endorsementSyncID = endorsement.syncID
        templateID = endorsement.templateID.rawValue
        title = endorsement.title
        endorsementText = endorsement.endorsementText
        regulationReference = endorsement.regulationReference
        studentName = endorsement.displayStudentName
        instructorName = endorsement.displayInstructorName
        instructorCertificateNumber = endorsement.instructor?.cfiCertificateNumber
        aircraftMakeModel = endorsement.aircraftMakeModel
        filledPlaceholders = endorsement.filledPlaceholders
        notes = endorsement.notes
        isSigned = endorsement.isSigned
        signedAt = endorsement.signedAt
        signerName = endorsement.signerName
        signerCertificateNumber = endorsement.signerCertificateNumber
        signatureImageBase64 = (signatureData ?? endorsement.signatureImageData)?.base64EncodedString()
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> RemoteSigningPackage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RemoteSigningPackage.self, from: data)
    }

    var signatureData: Data? {
        guard let base64 = signatureImageBase64 else { return nil }
        return Data(base64Encoded: base64)
    }

    var exportFileName: String {
        let slug = title.replacingOccurrences(of: " ", with: "_")
        return "AeroLog_Endorsement_\(slug)_\(token.prefix(8)).json"
    }
}