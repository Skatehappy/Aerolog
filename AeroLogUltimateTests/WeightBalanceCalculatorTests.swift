import XCTest
@testable import AeroLogUltimate

final class WeightBalanceCalculatorTests: XCTestCase {
    func testCalculatesWeightAndCG() {
        let stations = [
            WeightBalanceStation(name: "Pilot", weight: 180, arm: 37),
            WeightBalanceStation(name: "Fuel", weight: 300, arm: 48)
        ]
        let result = WeightBalanceCalculator.calculate(
            emptyWeight: 1500,
            emptyArm: 40,
            stations: stations,
            forwardLimit: 35,
            aftLimit: 47
        )
        XCTAssertEqual(result.totalWeight, 1980, accuracy: 0.1)
        XCTAssertGreaterThan(result.centerOfGravity, 35)
        XCTAssertLessThan(result.centerOfGravity, 47)
        XCTAssertTrue(result.isWithinLimits)
    }

    func testDetectsCGOutOfLimits() {
        let stations = [WeightBalanceStation(name: "Aft baggage", weight: 500, arm: 90)]
        let result = WeightBalanceCalculator.calculate(
            emptyWeight: 1500,
            emptyArm: 40,
            stations: stations,
            forwardLimit: 35,
            aftLimit: 47
        )
        XCTAssertFalse(result.isWithinLimits)
    }
}