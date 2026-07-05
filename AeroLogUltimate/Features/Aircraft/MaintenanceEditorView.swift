import SwiftUI

struct MaintenanceEditorView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var item: MaintenanceItem
    let aircraft: Aircraft
    let isNew: Bool

    var body: some View {
        Form {
            Section("Item") {
                TextField("Title", text: $item.title)
                Picker("Type", selection: $item.maintenanceType) {
                    ForEach(MaintenanceType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

            Section("Due") {
                Toggle("Set Due Date", isOn: Binding(
                    get: { item.dueDate != nil },
                    set: { enabled in item.dueDate = enabled ? .now.addingTimeInterval(86400 * 30) : nil }
                ))
                if item.dueDate != nil {
                    DatePicker("Due Date", selection: Binding(
                        get: { item.dueDate ?? .now },
                        set: { item.dueDate = $0 }
                    ), displayedComponents: .date)
                }
                HStack {
                    Text("Due Hobbs")
                    Spacer()
                    TextField("Optional", value: $item.dueHobbs, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
                Stepper("Remind \(item.reminderLeadDays) days before", value: $item.reminderLeadDays, in: 1...60)
            }

            Section("Notes") {
                TextField("Notes", text: Binding(
                    get: { item.notes ?? "" },
                    set: { item.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...4)
            }

            if !isNew {
                Section {
                    Button("Mark Completed") {
                        try? environment?.maintenanceService.markCompleted(item)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(isNew ? "New Maintenance" : "Edit Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if isNew { modelContext.delete(item) }
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
    }

    private func save() {
        if isNew {
            item.aircraft = aircraft
            modelContext.insert(item)
            aircraft.touch()
        } else {
            item.touch()
        }
        try? environment?.dataStore.save()
        Task {
            await MaintenanceReminderScheduler.rescheduleAll(using: environment!.maintenanceService)
        }
        dismiss()
    }
}