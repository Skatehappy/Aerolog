import SwiftUI
import SwiftData

/// Sheet for selecting an aircraft or training device during flight entry.
struct AircraftPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Aircraft.registration) private var allAircraft: [Aircraft]
    @Binding var selectedAircraft: Aircraft?

    @State private var showNewAircraft = false
    @State private var newAircraft: Aircraft?
    @State private var searchText = ""

    private var activeAircraft: [Aircraft] {
        allAircraft.filter { $0.isActive }.filter { aircraft in
            guard !searchText.isEmpty else { return true }
            let q = searchText.lowercased()
            return aircraft.registration.lowercased().contains(q)
                || aircraft.make.lowercased().contains(q)
                || aircraft.model.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(activeAircraft) { aircraft in
                Button {
                    selectedAircraft = aircraft
                    dismiss()
                } label: {
                    HStack {
                        AircraftRowView(aircraft: aircraft)
                        Spacer()
                        if selectedAircraft?.persistentModelID == aircraft.persistentModelID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search aircraft")
            .navigationTitle("Select Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let aircraft = Aircraft()
                        modelContext.insert(aircraft)
                        newAircraft = aircraft
                        showNewAircraft = true
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewAircraft) {
                if let aircraft = newAircraft {
                    NavigationStack {
                        AircraftEditorView(aircraft: aircraft, isNew: true)
                            .onDisappear {
                                if aircraft.isActive && !aircraft.registration.isEmpty || !aircraft.make.isEmpty {
                                    selectedAircraft = aircraft
                                    dismiss()
                                }
                            }
                    }
                }
            }
        }
    }
}