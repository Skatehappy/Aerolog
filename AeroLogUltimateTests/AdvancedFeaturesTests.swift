import XCTest
@testable import AeroLogUltimate

@MainActor
final class AdvancedFeaturesTests: XCTestCase {
    func testExpenseServiceTracksFlightCosts() throws {
        let store = try DataStore.makeInMemory()
        let expenseService = ExpenseService(dataStore: store)
        let flightService = FlightService(dataStore: store)
        let flight = try flightService.createDraft()

        _ = try expenseService.addExpense(to: flight, category: .fuel, amount: 85.50, vendor: "Shell")
        _ = try expenseService.addExpense(to: flight, category: .ramp, amount: 15)

        XCTAssertEqual(expenseService.totalExpenses(for: flight), 100.50, accuracy: 0.01)
    }

    func testMaintenanceServiceFindsOverdueItems() throws {
        let store = try DataStore.makeInMemory()
        let maintenanceService = MaintenanceService(dataStore: store)
        let aircraftService = AircraftService(dataStore: store)
        let aircraft = try aircraftService.create(registration: "N99999", make: "Cessna", model: "172")

        _ = try maintenanceService.addItem(
            to: aircraft,
            title: "Annual",
            type: .annual,
            dueDate: .now.addingTimeInterval(-86400)
        )

        let overdue = try maintenanceService.overdueItems()
        XCTAssertEqual(overdue.count, 1)
        XCTAssertTrue(overdue.first?.isOverdue == true)
    }

    func testFlightFuelBurnComputation() {
        let flight = Flight()
        flight.fuelAdded = 40
        flight.fuelRemaining = 12
        XCTAssertEqual(flight.computedFuelBurn, 28, accuracy: 0.01)
    }
}