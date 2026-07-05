import SwiftUI
import SwiftData

/// Primary logbook list with search, filtering, and selection for iPad split view.
struct FlightListView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Flight.flightDate, order: .reverse) private var allFlights: [Flight]

    @Binding var selectedFlight: Flight?
    var newFlightRequest: Int = 0
    var focusSearchRequest: Int = 0
    var saveRequest: Int = 0

    @StateObject private var searchDebouncer = SearchDebouncer()
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var showDraftsOnly = false
    @State private var showFinalizedOnly = false
    @State private var editorFlight: Flight?
    @State private var isCreatingNew = false
    @FocusState private var isSearchFocused: Bool

    private var visibleFlights: [Flight] {
        let query = searchDebouncer.debouncedText.lowercased()
        return allFlights
            .filter { !($0.syncMetadata?.isSoftDeleted ?? false) }
            .filter { flight in
                if showDraftsOnly { return flight.status == .draft }
                if showFinalizedOnly { return flight.status == .finalized }
                return true
            }
            .filter { flight in
                guard !query.isEmpty else { return true }
                return flight.departureICAO.lowercased().contains(query)
                    || flight.arrivalICAO.lowercased().contains(query)
                    || (flight.aircraft?.registration.lowercased().contains(query) ?? false)
                    || (flight.remarks?.lowercased().contains(query) ?? false)
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
                        .controlSize(.large)
                }
            } else {
                List {
                    ForEach(visibleFlights) { flight in
                        Button {
                            selectedFlight = flight
                        } label: {
                            FlightRowView(flight: flight)
                        }
                        .buttonStyle(.plain)
                        .cockpitTouchTarget(minHeight: 52)
                        .listRowBackground(
                            selectedFlight?.persistentModelID == flight.persistentModelID
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .readableContentWidth()
        .navigationTitle("Logbook")
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            prompt: "Search route, aircraft, remarks"
        )
        .focused($isSearchFocused)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNewFlight) {
                    Label("Log Flight", systemImage: "plus")
                }
                .keyboardShortcut(KeyboardShortcutRegistry.newFlight)
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
                FlightEditorView(flight: flight, isNew: isCreatingNew, saveRequest: saveRequest)
            }
        }
        .onChange(of: searchText) { _, text in
            searchDebouncer.submit(text)
        }
        .onChange(of: selectedFlight) { _, flight in
            if let flight, flight.status == .draft {
                isCreatingNew = false
                editorFlight = flight
            }
        }
        .onChange(of: newFlightRequest) { _, _ in
            createNewFlight()
        }
        .onChange(of: focusSearchRequest) { _, _ in
            isSearchPresented = true
            isSearchFocused = true
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