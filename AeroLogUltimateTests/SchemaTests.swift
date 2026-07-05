import XCTest
import SwiftData
@testable import AeroLogUltimate

final class SchemaTests: XCTestCase {
    func testSchemaIncludesAllModelTypes() {
        XCTAssertEqual(AeroLogSchema.modelTypes.count, 18)
        XCTAssertTrue(AeroLogSchema.modelTypes.contains(where: { $0 == Syllabus.self }))
        XCTAssertTrue(AeroLogSchema.modelTypes.contains(where: { $0 == SyllabusLesson.self }))
        XCTAssertTrue(AeroLogSchema.modelTypes.contains(where: { $0 == Flight.self }))
        XCTAssertTrue(AeroLogSchema.modelTypes.contains(where: { $0 == PilotProfile.self }))
    }

    func testInMemoryContainerInitializes() throws {
        let container = try ModelContainerConfiguration.inMemory
        XCTAssertNotNil(container)
    }
}