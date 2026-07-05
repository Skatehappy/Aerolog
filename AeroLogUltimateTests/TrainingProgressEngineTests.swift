import XCTest
@testable import AeroLogUltimate

final class TrainingProgressEngineTests: XCTestCase {
    let engine = TrainingProgressEngine()

    func testSyllabusCatalogHasBuiltInSyllabi() {
        XCTAssertEqual(SyllabusCatalog.all.count, 3)
        XCTAssertNotNil(SyllabusCatalog.definition(id: "ppl-part61"))
        XCTAssertEqual(SyllabusCatalog.privatePilot.lessons.count, 15)
    }

    func testLessonProgressTracksCompletion() {
        let instructor = PilotProfile(firstName: "CFI", lastName: "Test", isCFI: true)
        let student = PilotProfile(firstName: "Student", lastName: "Pilot")
        let relationship = TrainingRelationship(status: .active, goal: .privatePilot)
        relationship.instructor = instructor
        relationship.student = student
        relationship.syllabusCatalogID = SyllabusCatalog.privatePilot.id
        relationship.syllabusName = SyllabusCatalog.privatePilot.name

        let flight = Flight(flightDate: .now, status: .finalized, role: .dualReceived)
        flight.pilot = student
        flight.instructor = instructor
        flight.studentRelationship = relationship
        flight.lessonNumber = "1"
        flight.lessonTitle = "Introduction & Preflight"
        flight.dualReceived = 1.5
        flight.totalTime = 1.5

        let progress = engine.lessonProgress(relationship: relationship, flights: [flight])
        XCTAssertEqual(progress.count, 15)
        XCTAssertTrue(progress.first(where: { $0.lessonNumber == "1" })?.isCompleted == true)
        XCTAssertFalse(progress.first(where: { $0.lessonNumber == "2" })?.isCompleted == true)
    }

    func testCheckrideReadinessForPrivatePilot() {
        let instructor = PilotProfile(firstName: "CFI", lastName: "Test", isCFI: true)
        let student = PilotProfile(firstName: "Student", lastName: "Pilot")
        let relationship = TrainingRelationship(status: .active, goal: .privatePilot)
        relationship.instructor = instructor
        relationship.student = student
        relationship.syllabusCatalogID = SyllabusCatalog.privatePilot.id

        let flight = Flight(flightDate: .now, status: .finalized, role: .dualReceived)
        flight.pilot = student
        flight.dualReceived = 5.0
        flight.totalTime = 5.0
        flight.studentRelationship = relationship
        flight.lessonNumber = "1"

        let report = engine.checkrideReadiness(relationship: relationship, flights: [flight])
        XCTAssertEqual(report.goal, .privatePilot)
        XCTAssertFalse(report.isReady)
        XCTAssertFalse(report.requirements.isEmpty)
        XCTAssertFalse(report.recommendations.isEmpty)
    }

    func testStudentSummaryAggregatesTime() {
        let instructor = PilotProfile(firstName: "CFI", lastName: "Test", isCFI: true)
        let student = PilotProfile(firstName: "Student", lastName: "Pilot")
        let relationship = TrainingRelationship(status: .active, goal: .privatePilot)
        relationship.instructor = instructor
        relationship.student = student
        relationship.syllabusCatalogID = SyllabusCatalog.privatePilot.id
        relationship.syllabusName = "PPL"

        let dual = Flight(status: .finalized, role: .dualReceived)
        dual.pilot = student
        dual.dualReceived = 2.0
        dual.totalTime = 2.0
        dual.lessonNumber = "1"
        dual.studentRelationship = relationship

        let ground = Flight(status: .finalized, role: .dualReceived)
        ground.pilot = student
        ground.groundInstructionTime = 1.0
        ground.totalTime = 0
        ground.lessonNumber = "2"
        ground.studentRelationship = relationship

        let summary = engine.studentSummary(
            relationship: relationship,
            flights: [dual, ground],
            endorsementCount: 2
        )
        XCTAssertEqual(summary.dualReceived, 2.0)
        XCTAssertEqual(summary.groundInstruction, 1.0)
        XCTAssertEqual(summary.endorsementCount, 2)
        XCTAssertEqual(summary.lessonsCompleted, 2)
    }
}