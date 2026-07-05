import SwiftUI

struct MaintenanceListView: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable var aircraft: Aircraft

    @State private var editorItem: MaintenanceItem?
    @State private var isCreatingNew = false

    private var items: [MaintenanceItem] {
        environment?.maintenanceService.items(for: aircraft, includeCompleted: false) ?? []
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No Maintenance Items", systemImage: "wrench.and.screwdriver")
                } description: {
                    Text("Track annuals, 100-hour inspections, oil changes, and AD compliance.")
                } actions: {
                    Button("Add Item") { createNew() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(items, id: \.persistentModelID) { item in
                        Button {
                            isCreatingNew = false
                            editorItem = item
                        } label: {
                            MaintenanceRowView(item: item)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .navigationTitle("Maintenance")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNew) {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorItem) { item in
            NavigationStack {
                MaintenanceEditorView(item: item, aircraft: aircraft, isNew: isCreatingNew)
            }
        }
        .task {
            guard environment?.settings.enableMaintenanceReminders == true else { return }
            await MaintenanceReminderScheduler.rescheduleAll(using: environment!.maintenanceService)
        }
    }

    private func createNew() {
        isCreatingNew = true
        let item = MaintenanceItem()
        editorItem = item
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            try? environment?.maintenanceService.delete(items[index])
        }
    }
}

private struct MaintenanceRowView: View {
    let item: MaintenanceItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.isEmpty ? item.maintenanceType.displayName : item.title)
                    .font(.headline)
                Text(item.maintenanceType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item.isOverdue {
                Text("Overdue")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let days = item.daysUntilDue {
                Text("\(days)d")
                    .font(.caption)
                    .foregroundStyle(days <= item.reminderLeadDays ? .orange : .secondary)
            }
        }
    }
}