import XCTest
import SwiftData
@testable import AeroLogUltimate

final class SchemaTests: XCTestCase {
    func testSchemaIncludesAllModelTypes() {
        XCTAssertEqual(AeroLogSchema.modelTypes.count, 13)
        XCTAssertTrue(AeroLogSchema.modelTypes.contains(where: { $0 == Flight.self }))
        XCTAssertTrue(AeroLogSchema.modelTypes.contains(where: { $0 == PilotProfile.self }))
    }

    func testInMemoryContainerInitializes() throws {
        let container = try ModelContainerConfiguration.inMemory
        XCTAssertNotNil(container)
    }
}