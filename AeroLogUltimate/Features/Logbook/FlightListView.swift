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
    @State private var showPinnedOnly = false
    @State private var showFavoritesOnly = false
    @State private var parsedCriteria = FlightSearchCriteria()
    @State private var editorFlight: Flight?
    @State private var isCreatingNew = false
    @FocusState private var isSearchFocused: Bool

    private var visibleFlights: [Flight] {
        let query = searchDebouncer.debouncedText
        var criteria = parsedCriteria
        if showPinnedOnly { criteria.pinnedOnly = true }
        if showFavoritesOnly { criteria.favoritesOnly = true }
        if showDraftsOnly { criteria.status = .draft }
        if showFinalizedOnly { criteria.status = .finalized }

        let filtered = allFlights
            .filter { !($0.syncMetadata?.isSoftDeleted ?? false) }
            .filter { flight in
                if criteria.isEmpty && query.isEmpty { return true }
                if !query.isEmpty {
                    let nlCriteria = NaturalLanguageSearchEngine.parse(query)
                    var merged = nlCriteria
                    if criteria.pinnedOnly { merged.pinnedOnly = true }
                    if criteria.favoritesOnly { merged.favoritesOnly = true }
                    if let status = criteria.status { merged.status = status }
                    return NaturalLanguageSearchEngine.matches(flight, criteria: merged)
                }
                return NaturalLanguageSearchEngine.matches(flight, criteria: criteria)
            }

        return FlightService.sortedForDisplay(filtered)
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
                        .swipeActions(edge: .trailing) {
                            Button(flight.isDraft ? "Delete Draft" : "Delete", role: .destructive) {
                                deleteFromList(flight)
                            }
                        }
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
            prompt: "Try: night PIC last month, pinned, KORD"
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
                    Toggle("Pinned Only", isOn: $showPinnedOnly)
                    Toggle("Favorites Only", isOn: $showFavoritesOnly)
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
            parsedCriteria = NaturalLanguageSearchEngine.parse(text)
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

    /// Swipe-to-delete from the logbook: drafts are hard-deleted (clears the old
    /// abandoned "double" drafts); finalized entries are removed via the service.
    private func deleteFromList(_ flight: Flight) {
        if selectedFlight?.persistentModelID == flight.persistentModelID {
            selectedFlight = nil
        }
        do {
            if flight.isDraft {
                try environment?.flightService.permanentlyDelete(flight)
            } else {
                try environment?.flightService.delete(flight, force: true)
            }
        } catch {
            // Best-effort; leave the row if deletion fails.
        }
    }

    private func createNewFlight() {
        guard let env = environment else { return }
        do {
            let flight = try env.flightService.createDraft()
            // Open the editor directly via editorFlight. Do NOT assign
            // selectedFlight here: that fires .onChange(of: selectedFlight),
            // which flips isCreatingNew back to false and makes the editor treat
            // a brand-new draft as an existing one — so Cancel wouldn't discard
            // it and the eagerly-saved draft was left behind (looking doubled).
            isCreatingNew = true
            editorFlight = flight
        } catch {
            // Production: surface error toast
        }
    }
}