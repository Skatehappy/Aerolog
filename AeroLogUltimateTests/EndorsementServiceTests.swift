import XCTest
@testable import AeroLogUltimate

@MainActor
final class EndorsementServiceTests: XCTestCase {
    func testBuiltInTemplateRendering() {
        let definition = EndorsementTemplateCatalog.definition(for: .soloFlight)!
        let text = definition.renderedText(values: [
            "student_name": "Jane Pilot",
            "aircraft_make_model": "Cessna 172S"
        ])
        XCTAssertTrue(text.contains("Jane Pilot"))
        XCTAssertTrue(text.contains("Cessna 172S"))
    }

    func testCreateAndSignEndorsement() throws {
        let store = try DataStore.makeInMemory()
        let service = EndorsementService(dataStore: store)
        let student = try store.primaryPilotProfile()!
        let instructor = PilotProfile(firstName: "CFI", lastName: "Smith", isCFI: true)
        instructor.cfiCertificateNumber = "CFI1234567"
        store.insert(instructor)
        try store.save()

        let definition = EndorsementTemplateCatalog.definition(for: .flightReview)!
        let endorsement = try service.createFromBuiltInTemplate(
            definition,
            student: student,
            instructor: instructor,
            values: ["student_name": student.fullName, "review_date": "Jun 15, 2026"]
        )

        let signature = "test".data(using: .utf8)!
        try service.sign(
            endorsement,
            signerName: instructor.fullName,
            certificateNumber: "CFI1234567",
            signatureData: signature,
            instructor: instructor
        )

        XCTAssertEqual(endorsement.status, .signed)
        XCTAssertEqual(endorsement.signerCertificateNumber, "CFI1234567")
    }

    func testSignedEndorsementCannotBeEdited() throws {
        let store = try DataStore.makeInMemory()
        let service = EndorsementService(dataStore: store)
        let student = try store.primaryPilotProfile()!
        let instructor = PilotProfile(firstName: "CFI", lastName: "Smith", isCFI: true)
        instructor.cfiCertificateNumber = "CFI1234567"
        store.insert(instructor)
        try store.save()

        let definition = EndorsementTemplateCatalog.definition(for: .flightReview)!
        let endorsement = try service.createFromBuiltInTemplate(
            definition,
            student: student,
            instructor: instructor,
            values: ["student_name": student.fullName, "review_date": "Jun 15, 2026"]
        )

        try service.sign(
            endorsement,
            signerName: instructor.fullName,
            certificateNumber: "CFI1234567",
            signatureData: Data("sig".utf8),
            instructor: instructor
        )

        XCTAssertThrowsError(
            try service.updateDraft(
                endorsement,
                endorsementText: "Altered text",
                filledPlaceholders: [:],
                notes: nil,
                student: student,
                instructor: instructor
            )
        ) { error in
            guard case EndorsementServiceError.signedEndorsementImmutable = error else {
                return XCTFail("Expected signedEndorsementImmutable, got \(error)")
            }
        }
    }

    func testRemoteSigningPackageRoundTrip() throws {
        let store = try DataStore.makeInMemory()
        let service = EndorsementService(dataStore: store)
        let student = try store.primaryPilotProfile()!
        let instructor = PilotProfile(firstName: "CFI", lastName: "Jones", isCFI: true)
        store.insert(instructor)
        try store.save()

        let definition = EndorsementTemplateCatalog.definition(for: .preSoloFlightTraining)!
        let endorsement = try service.createFromBuiltInTemplate(
            definition,
            student: student,
            instructor: instructor,
            values: ["student_name": student.fullName, "aircraft_make_model": "C172"]
        )
        _ = try service.requestRemoteSignature(for: endorsement, instructor: instructor)
        let data = try service.exportPackage(for: endorsement)
        let package = try RemoteSigningPackage.decode(from: data)
        XCTAssertEqual(package.studentName, student.fullName)
        XCTAssertFalse(package.isSigned)
    }
}