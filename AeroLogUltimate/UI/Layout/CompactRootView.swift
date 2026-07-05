import SwiftUI

/// iPhone companion layout using tab navigation and single-column stacks.
struct CompactRootView: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable private var navigation: NavigationCoordinator

    @State private var selectedFlight: Flight?
    @State private var selectedCurrency: CurrencyCalculationResult?
    @State private var selectedEndorsement: Endorsement?
    @State private var selectedReportType: ReportType?
    @State private var selectedRelationshipID: UUID?
    @State private var newFlightRequest = 0
    @State private var focusSearchRequest = 0
    @State private var saveRequest = 0

    init(navigation: NavigationCoordinator) {
        self.navigation = navigation
    }

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            tabRoot(.logbook, title: "Logbook", systemImage: "book.closed") {
                FlightListView(
                    selectedFlight: $selectedFlight,
                    newFlightRequest: newFlightRequest,
                    focusSearchRequest: focusSearchRequest,
                    saveRequest: saveRequest
                )
            }
            tabRoot(.aircraft, title: "Aircraft", systemImage: "airplane") {
                AircraftListView()
            }
            tabRoot(.currency, title: "Currency", systemImage: "checkmark.shield") {
                CurrencyDashboardView(selectedResult: $selectedCurrency)
            }
            tabRoot(.endorsements, title: "Endorsements", systemImage: "signature") {
                EndorsementListView(selectedEndorsement: $selectedEndorsement)
            }
            tabRoot(.training, title: "Training", systemImage: "person.2") {
                TrainingDashboardView(selectedRelationshipID: $selectedRelationshipID)
            }
            tabRoot(.reports, title: "Reports", systemImage: "chart.bar.doc.horizontal") {
                ReportsDashboardView(selectedReportType: $selectedReportType)
            }
            tabRoot(.settings, title: "Settings", systemImage: "gearshape") {
                SettingsDashboardView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appShortcutNewFlight)) { _ in
            handleShortcut(.newFlight)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appShortcutFocusSearch)) { _ in
            handleShortcut(.focusSearch)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appShortcutSave)) { _ in
            handleShortcut(.save)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appShortcutSelectTab)) { notification in
            guard let tab = notification.object as? AppTab else { return }
            handleShortcut(.selectTab(tab))
        }
    }

    @ViewBuilder
    private func tabRoot<Content: View>(
        _ tab: AppTab,
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
        }
        .tabItem { Label(title, systemImage: systemImage) }
        .tag(tab)
    }

    private func handleShortcut(_ action: AppShortcutAction) {
        switch action {
        case .newFlight:
            navigation.selectedTab = .logbook
            newFlightRequest += 1
        case .focusSearch:
            navigation.selectedTab = .logbook
            focusSearchRequest += 1
        case .toggleSidebar:
            break
        case .save:
            saveRequest += 1
        case .selectTab(let tab):
            navigation.selectedTab = tab
        }
    }
}