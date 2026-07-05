import Foundation
import SwiftData

@MainActor
struct ExpenseService {
    let dataStore: DataStore

    func expenses(for flight: Flight) -> [FlightExpense] {
        (flight.expenses ?? []).sorted { $0.expenseDate > $1.expenseDate }
    }

    @discardableResult
    func addExpense(
        to flight: Flight,
        category: ExpenseCategory,
        amount: Double,
        vendor: String? = nil,
        notes: String? = nil,
        date: Date = .now
    ) throws -> FlightExpense {
        let expense = FlightExpense(category: category, amount: amount, expenseDate: date)
        expense.vendor = vendor
        expense.notes = notes
        expense.flight = flight
        dataStore.insert(expense)
        flight.touch()
        try dataStore.save()
        return expense
    }

    func delete(_ expense: FlightExpense) throws {
        if let metadata = expense.syncMetadata {
            metadata.softDelete()
        } else {
            dataStore.delete(expense)
        }
        try dataStore.save()
    }

    func totalExpenses(for flight: Flight) -> Double {
        expenses(for: flight).reduce(0) { $0 + $1.amount }
    }
}