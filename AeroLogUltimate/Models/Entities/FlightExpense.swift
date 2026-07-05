import Foundation
import SwiftData

/// Optional per-flight expense entry.
@Model
final class FlightExpense {
    var category: ExpenseCategory
    var amount: Double
    var currencyCode: String
    var vendor: String?
    var notes: String?
    var expenseDate: Date
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    @Relationship(deleteRule: .nullify)
    var flight: Flight?

    init(
        category: ExpenseCategory = .other,
        amount: Double = 0,
        currencyCode: String = "USD",
        expenseDate: Date = .now
    ) {
        self.category = category
        self.amount = amount
        self.currencyCode = currencyCode
        self.expenseDate = expenseDate
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}