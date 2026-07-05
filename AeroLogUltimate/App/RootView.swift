import SwiftUI

/// iPad split-view shell with Phase 1 logbook and aircraft features.
struct RootView: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable private var navigation: NavigationCoordinator

    @State private var selectedFlight: Flight?
    @State private var selectedCurrency: CurrencyCalculationResult?
    @State private var selectedEndorsement: Endorsement?

    init(navigation: NavigationCoordinator) {
        self.navigation = navigation
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $navigation.columnVisibility) {
            sidebar
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(AppTab.allCases, selection: $navigation.selectedTab) { tab in
            Label(tab.title, systemImage: tab.systemImage)
                .tag(tab)
        }
        .navigationTitle(SettingsStore.appName)
        .onChange(of: navigation.selectedTab) { _, newTab in
            UserPreferences.shared.lastSelectedTab = newTab
            if newTab != .logbook { selectedFlight = nil }
            if newTab != .currency { selectedCurrency = nil }
            if newTab != .endorsements { selectedEndorsement = nil }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentColumn: some View {
        switch navigation.selectedTab {
        case .logbook:
            FlightListView(selectedFlight: $selectedFlight)
        case .aircraft:
            NavigationStack {
                AircraftListView()
            }
        case .currency:
            NavigationStack {
                CurrencyDashboardView(selectedResult: $selectedCurrency)
            }
        case .endorsements:
            NavigationStack {
                EndorsementListView(selectedEndorsement: $selectedEndorsement)
            }
        default:
            PlaceholderTabView(tab: navigation.selectedTab)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailColumn: some View {
        if navigation.selectedTab == .logbook {
            if let flight = selectedFlight, flight.status == .finalized {
                NavigationStack {
                    FlightDetailView(flight: flight)
                }
            } else {
                ContentUnavailableView {
                    Label("Select a Flight", systemImage: "book.closed")
                } description: {
                    Text("Choose a finalized entry to view details, or tap + to log a new flight.")
                }
            }
        } else if navigation.selectedTab == .currency {
            if let result = selectedCurrency {
                NavigationStack {
                    CurrencyDetailView(result: result)
                }
            } else {
                ContentUnavailableView {
                    Label("Currency Detail", systemImage: "checkmark.shield")
                } description: {
                    Text("Select a currency item to view qualifying events and requirements.")
                }
            }
        } else if navigation.selectedTab == .endorsements {
            if let endorsement = selectedEndorsement {
                NavigationStack {
                    EndorsementDetailView(endorsement: endorsement)
                }
            } else {
                ContentUnavailableView {
                    Label("Endorsement Detail", systemImage: "signature")
                } description: {
                    Text("Select an endorsement to view the full text and signature.")
                }
            }
        } else {
            ContentUnavailableView {
                Label("Detail", systemImage: "sidebar.right")
            } description: {
                Text("Select an item from the list to view details.")
            }
        }
    }
}

/// Placeholder for tabs not yet implemented (Phase 2+).
private struct PlaceholderTabView: View {
    let tab: AppTab

    var body: some View {
        ContentUnavailableView {
            Label(tab.title, systemImage: tab.systemImage)
        } description: {
            Text("Coming in a future phase.")
        }
        .navigationTitle(tab.title)
    }
}

#Preview {
    RootView(navigation: NavigationCoordinator())
}