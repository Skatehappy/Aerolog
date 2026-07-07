import SwiftUI

struct FlightExpensesSection: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable var flight: Flight

    @State private var showAddExpense = false
    @State private var newCategory: ExpenseCategory = .fuel
    @State private var newAmount = ""
    @State private var newVendor = ""
    @State private var errorMessage: String?

    private var expenses: [FlightExpense] {
        environment?.expenseService.expenses(for: flight) ?? []
    }

    var body: some View {
        Section {
            if expenses.isEmpty {
                Text("No expenses logged for this flight.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(expenses, id: \.persistentModelID) { expense in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.category.displayName)
                                .font(.subheadline)
                            if let vendor = expense.vendor, !vendor.isEmpty {
                                Text(vendor)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(expense.amount, format: .currency(code: expense.currencyCode))
                    }
                }
                .onDelete(perform: deleteExpenses)
            }

            HStack {
                Text("Total")
                    .fontWeight(.medium)
                Spacer()
                Text(flight.totalExpenses, format: .currency(code: "USD"))
            }

            Button("Add Expense") { showAddExpense = true }
        } header: {
            FormSectionHeader(title: "Expenses", systemImage: "dollarsign.circle")
        }
        .sheet(isPresented: $showAddExpense) {
            NavigationStack {
                Form {
                    Picker("Category", selection: $newCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    TextField("Amount", text: $newAmount)
                        .keyboardType(.decimalPad)
                    TextField("Vendor (optional)", text: $newVendor)
                }
                .navigationTitle("Add Expense")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddExpense = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveExpense() }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveExpense() {
        guard let amount = Double(newAmount), amount > 0 else { return }
        do {
            try environment?.expenseService.addExpense(
                to: flight,
                category: newCategory,
                amount: amount,
                vendor: newVendor.isEmpty ? nil : newVendor
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        newAmount = ""
        newVendor = ""
        showAddExpense = false
    }

    private func deleteExpenses(at offsets: IndexSet) {
        do {
            for index in offsets {
                let expense = expenses[index]
                try environment?.expenseService.delete(expense)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}