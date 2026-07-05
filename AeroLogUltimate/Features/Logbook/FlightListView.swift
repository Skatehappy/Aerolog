import SwiftUI
import SwiftData

/// Primary logbook list with search, filtering, and selection for iPad split view.
struct FlightListView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Flight.flightDate, order: .reverse) private var allFlights: [Flight]

    @Binding var selectedFlight: Flight?
    @State private var searchText = ""
    @State private var showDraftsOnly = false
    @State private var showFinalizedOnly = false
    @State private var editorFlight: Flight?
    @State private var isCreatingNew = false

    private var visibleFlights: [Flight] {
        allFlights.filter { !($0.syncMetadata?.isSoftDeleted ?? false) }
            .filter { flight in
                if showDraftsOnly { return flight.status == .draft }
                if showFinalizedOnly { return flight.status == .finalized }
                return true
            }
            .filter { flight in
                guard !searchText.isEmpty else { return true }
                let q = searchText.lowercased()
                return flight.departureICAO.lowercased().contains(q)
                    || flight.arrivalICAO.lowercased().contains(q)
                    || (flight.aircraft?.registration.lowercased().contains(q) ?? false)
                    || (flight.remarks?.lowercased().contains(q) ?? false)
            }
    }

    var body: some View {
        NavigationStack {
            listContent
        }
    }

    @ViewBuilder
    private var listContent: some View {
        Group {
            if visibleFlights.isEmpty {
                ContentUnavailableView {
                    Label("No Flights", systemImage: "book.closed")
                } description: {
                    Text("Log your first flight to start building your logbook.")
                } actions: {
                    Button("Log Flight") { createNewFlight() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: $selectedFlight) {
                    ForEach(visibleFlights) { flight in
                        FlightRowView(flight: flight)
                            .tag(flight)
                    }
                }
            }
        }
        .navigationTitle("Logbook")
        .searchable(text: $searchText, prompt: "Search route, aircraft, remarks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNewFlight) {
                    Label("Log Flight", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Toggle("Drafts Only", isOn: $showDraftsOnly)
                        .onChange(of: showDraftsOnly) { _, on in if on { showFinalizedOnly = false } }
                    Toggle("Finalized Only", isOn: $showFinalizedOnly)
                        .onChange(of: showFinalizedOnly) { _, on in if on { showDraftsOnly = false } }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(item: $editorFlight) { flight in
            NavigationStack {
                FlightEditorView(flight: flight, isNew: isCreatingNew)
            }
        }
        .onChange(of: selectedFlight) { _, flight in
            if let flight, flight.status == .draft {
                isCreatingNew = false
                editorFlight = flight
            }
        }
    }

    private func createNewFlight() {
        guard let env = environment else { return }
        do {
            let flight = try env.flightService.createDraft()
            isCreatingNew = true
            selectedFlight = flight
            editorFlight = flight
        } catch {
            // Production: surface error toast
        }
    }
}