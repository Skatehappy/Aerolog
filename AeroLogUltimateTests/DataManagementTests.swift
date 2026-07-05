import XCTest
import SwiftData
@testable import AeroLogUltimate

@MainActor
final class DataManagementTests: XCTestCase {
    func testCSVImportCreatesFlights() throws {
        let store = try DataStore.makeInMemory()
        let service = DataManagementService(
            dataStore: store,
            attachmentStorage: AttachmentStorageService()
        )

        let csv = """
        Date,Aircraft,From,To,Total Time,PIC,Day Landings,Night Landings,Remarks
        2024-06-15,N12345,KPAO,KSQL,1.5,1.5,2,0,Pattern work
        2024-06-20,N12345,KSQL,KPAO,1.2,1.2,1,0,Cross country
        """
        let data = Data(csv.utf8)
        let result = try service.importData(data, format: .csv)

        XCTAssertEqual(result.importedFlights, 2)
        XCTAssertEqual(result.importedAircraft, 1)

        let flights = try store.fetch(FetchDescriptor<Flight>())
        XCTAssertEqual(flights.count, 2)
        XCTAssertTrue(flights.allSatisfy { $0.status == .finalized })
    }

    func testBackupPackageRoundTrip() throws {
        let store = try DataStore.makeInMemory()
        let flightService = FlightService(dataStore: store)
        let aircraftService = AircraftService(dataStore: store)

        let aircraft = try aircraftService.create(registration: "N99999", make: "Piper", model: "PA-28")
        let flight = try flightService.createDraft()
        flight.aircraft = aircraft
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        flight.totalTime = 1.4
        flight.picTime = 1.4
        try flightService.finalize(flight)
        XCTAssertEqual(flight.status, .finalized)

        let exportService = DataManagementService(
            dataStore: store,
            attachmentStorage: AttachmentStorageService()
        )
        let backup = try exportService.createBackup(includeAttachments: false)

        XCTAssertEqual(backup.package.flights.count, 1)
        XCTAssertEqual(backup.package.aircraft.count, 1)

        let decoded = try AeroLogBackupPackage.decode(from: backup.package.encode())
        XCTAssertEqual(decoded.flights.first?.departureICAO, "KPAO")
        XCTAssertEqual(decoded.aircraft.first?.registration, "N99999")
    }

    func testBackupRestoreMerge() throws {
        let store = try DataStore.makeInMemory()
        let flightService = FlightService(dataStore: store)
        let aircraftService = AircraftService(dataStore: store)

        let aircraft = try aircraftService.create(registration: "N54321", make: "Cessna", model: "172")
        let flight = try flightService.createDraft()
        flight.aircraft = aircraft
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        flight.totalTime = 1.0
        flight.picTime = 1.0
        try flightService.finalize(flight)

        let service = DataManagementService(
            dataStore: store,
            attachmentStorage: AttachmentStorageService()
        )
        let backup = try service.createBackup(includeAttachments: false)

        let restoreStore = try DataStore.makeInMemory()
        let restoreService = DataManagementService(
            dataStore: restoreStore,
            attachmentStorage: AttachmentStorageService()
        )
        let result = try restoreService.restoreBackup(from: backup.archiveURL, strategy: .merge)

        XCTAssertEqual(result.restoredFlights, 1)
        let restoredFlights = try restoreStore.fetch(FetchDescriptor<Flight>())
        XCTAssertEqual(restoredFlights.count, 1)
        XCTAssertEqual(restoredFlights.first?.departureICAO, "KPAO")
    }

    func testLogbookExportCSV() throws {
        let store = try DataStore.makeInMemory()
        let flightService = FlightService(dataStore: store)
        let aircraftService = AircraftService(dataStore: store)

        let aircraft = try aircraftService.create(registration: "N11111", make: "Cessna", model: "172")
        let flight = try flightService.createDraft()
        flight.aircraft = aircraft
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        flight.totalTime = 1.5
        flight.picTime = 1.5
        try flightService.finalize(flight)

        let service = DataManagementService(
            dataStore: store,
            attachmentStorage: AttachmentStorageService()
        )
        let export = try service.exportLogbook(format: .csv)

        XCTAssertFalse(export.data.isEmpty)
        XCTAssertTrue(export.fileName.hasSuffix(".csv"))
        let text = String(data: export.data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("KPAO"))
        XCTAssertTrue(text.contains("Total Time"))
    }

    func testLogbookExportPDF() throws {
        let store = try DataStore.makeInMemory()
        let flightService = FlightService(dataStore: store)
        let aircraftService = AircraftService(dataStore: store)

        let aircraft = try aircraftService.create(registration: "N22222", make: "Cessna", model: "172")
        let flight = try flightService.createDraft()
        flight.aircraft = aircraft
        flight.departureICAO = "KPAO"
        flight.arrivalICAO = "KSQL"
        flight.totalTime = 1.0
        flight.picTime = 1.0
        try flightService.finalize(flight)

        let service = DataManagementService(
            dataStore: store,
            attachmentStorage: AttachmentStorageService()
        )
        let export = try service.exportLogbook(format: .pdf)

        XCTAssertGreaterThan(export.data.count, 100)
        XCTAssertTrue(export.fileName.hasSuffix(".pdf"))
        XCTAssertEqual(String(data: export.data.prefix(4), encoding: .ascii), "%PDF")
    }

    func testBackupRestoreIncludesSignedEndorsements() throws {
        let store = try DataStore.makeInMemory()
        let student = try store.primaryPilotProfile()!
        let instructor = PilotProfile(firstName: "CFI", lastName: "Adams", isCFI: true)
        instructor.cfiCertificateNumber = "CFI9988776"
        store.insert(instructor)
        try store.save()

        let endorsementService = EndorsementService(dataStore: store)
        let definition = EndorsementTemplateCatalog.definition(for: .flightReview)!
        let endorsement = try endorsementService.createFromBuiltInTemplate(
            definition,
            student: student,
            instructor: instructor,
            values: ["student_name": student.fullName, "review_date": "Jun 1, 2026"]
        )
        try endorsementService.sign(
            endorsement,
            signerName: instructor.fullName,
            certificateNumber: instructor.cfiCertificateNumber!,
            signatureData: Data([0xAB]),
            instructor: instructor
        )

        let service = DataManagementService(
            dataStore: store,
            attachmentStorage: AttachmentStorageService()
        )
        let backup = try service.createBackup(includeAttachments: false)
        XCTAssertEqual(backup.package.endorsements.count, 1)
        XCTAssertEqual(backup.package.endorsements.first?.status, .signed)

        let restoreStore = try DataStore.makeInMemory()
        let restoreService = DataManagementService(
            dataStore: restoreStore,
            attachmentStorage: AttachmentStorageService()
        )
        _ = try restoreService.restoreBackup(from: backup.archiveURL, strategy: .merge)

        let restored = try restoreStore.fetch(FetchDescriptor<Endorsement>())
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.status, .signed)
        XCTAssertEqual(restored.first?.templateID, .flightReview)
    }

    func testCSVImporterDetectsLogTenHeaders() throws {
        let csv = "Date,Aircraft ID,From,To,Total Duration,PIC\n2024-01-01,N123,KPAO,KSQL,1.0,1.0\n"
        let importer = CSVLogbookImporter()
        let rows = try importer.parse(Data(csv.utf8))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.departureICAO, "KPAO")
        XCTAssertEqual(rows.first?.aircraftRegistration, "N123")
    }
}