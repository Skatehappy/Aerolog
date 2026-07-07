import SwiftUI
import SwiftData

/// Fleet and simulator management list.
struct AircraftListView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Aircraft.registration) private var allAircraft: [Aircraft]

    // On iPad this drives RootView's detail column via the lifted binding; on
    // iPhone it is unused and rows fall back to a NavigationLink push.
    @Binding var selectedAircraft: Aircraft?

    // Passed explicitly by the parent layout (true from the iPad RootView, false
    // from the iPhone CompactRootView). We must NOT infer this from
    // horizontalSizeClass: inside a NavigationSplitView column that environment
    // value is unreliable, which left the aircraft hub stuck via a stray push.
    let usesColumnSelection: Bool

    @State private var showInactive = false
    @State private var editorAircraft: Aircraft?
    @State private var isCreatingNew = false
    @State private var searchText = ""
    @State private var errorMessage: String?

    init(
        selectedAircraft: Binding<Aircraft?> = .constant(nil),
        usesColumnSelection: Bool = false
    ) {
        _selectedAircraft = selectedAircraft
        self.usesColumnSelection = usesColumnSelection
    }

    private var filteredAircraft: [Aircraft] {
        allAircraft.filter { aircraft in
            if !showInactive && !aircraft.isActive { return false }
            if searchText.isEmpty { return true }
            let query = searchText.lowercased()
            return aircraft.registration.lowercased().contains(query)
                || aircraft.make.lowercased().contains(query)
                || aircraft.model.lowercased().contains(query)
        }
    }

    var body: some View {
        Group {
            if filteredAircraft.isEmpty {
                ContentUnavailableView {
                    Label("No Aircraft", systemImage: "airplane")
                } description: {
                    Text("Add your aircraft and training devices to log flights.")
                } actions: {
                    Button("Add Aircraft") { createNew() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    if !allAircraft.filter({ $0.isSimulator }).isEmpty {
                        Section("Simulators & Training Devices") {
                            aircraftRows(simulators: true)
                        }
                    }
                    Section("Aircraft") {
                        aircraftRows(simulators: false)
                    }
                }
                .searchable(text: $searchText, prompt: "Search tail number or model")
            }
        }
        .navigationTitle("Aircraft")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNew) {
                    Label("Add", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Toggle("Show Inactive", isOn: $showInactive)
            }
        }
        .sheet(item: $editorAircraft) { aircraft in
            NavigationStack {
                AircraftEditorView(aircraft: aircraft, isNew: isCreatingNew)
            }
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

    @ViewBuilder
    private func aircraftRows(simulators: Bool) -> some View {
        ForEach(filteredAircraft.filter { $0.isSimulator == simulators }) { aircraft in
            aircraftRow(aircraft)
                .swipeActions(edge: .trailing) {
                    if aircraft.isActive {
                        Button("Deactivate", role: .destructive) {
                            do {
                                try environment?.aircraftService.deactivate(aircraft)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } else {
                        Button("Reactivate") {
                            do {
                                try environment?.aircraftService.reactivate(aircraft)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                        .tint(.green)
                    }
                }
        }
    }

    // iPad: tap selects into the detail column via the lifted binding.
    // iPhone: tap pushes the hub onto the tab's own NavigationStack.
    @ViewBuilder
    private func aircraftRow(_ aircraft: Aircraft) -> some View {
        if usesColumnSelection {
            Button {
                selectedAircraft = aircraft
            } label: {
                AircraftRowView(aircraft: aircraft)
            }
            .buttonStyle(.plain)
            .listRowBackground(
                selectedAircraft?.persistentModelID == aircraft.persistentModelID
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear
            )
        } else {
            NavigationLink {
                AircraftHubView(aircraft: aircraft)
            } label: {
                AircraftRowView(aircraft: aircraft)
            }
        }
    }

    private func createNew() {
        let aircraft = Aircraft()
        modelContext.insert(aircraft)
        isCreatingNew = true
        editorAircraft = aircraft
    }
}

struct AircraftRowView: View {
    let aircraft: Aircraft

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(aircraft.displayName)
                        .font(.headline)
                    if aircraft.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    if !aircraft.isActive {
                        Text("Inactive")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(aircraft.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if aircraft.isSimulator {
                Text(aircraft.simulatorLevel.shortName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}