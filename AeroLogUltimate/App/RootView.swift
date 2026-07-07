import SwiftUI

/// iPad split-view shell optimized for cockpit and briefing workflows.
struct RootView: View {
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
        NavigationSplitView(columnVisibility: $navigation.columnVisibility) {
            sidebar
                .splitColumnStyle(.sidebar)
        } content: {
            contentColumn
                .splitColumnStyle(.content)
                // Bug A: force SwiftUI to treat each tab's column (and the
                // NavigationStack inside it) as a distinct identity so a prior
                // tab's pushed navigation state can't linger under the new tab.
                .id(navigation.selectedTab)
        } detail: {
            detailColumn
                .splitColumnStyle(.detail)
                .id(navigation.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .appShortcutNewFlight)) { _ in
            handleShortcut(.newFlight)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appShortcutFocusSearch)) { _ in
            handleShortcut(.focusSearch)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appShortcutToggleSidebar)) { _ in
            handleShortcut(.toggleSidebar)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appShortcutSave)) { _ in
            handleShortcut(.save)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appShortcutSelectTab)) { notification in
            guard let tab = notification.object as? AppTab else { return }
            handleShortcut(.selectTab(tab))
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List {
            ForEach(AppTab.allCases) { tab in
                Button {
                    navigation.selectedTab = tab
                } label: {
                    SidebarTabRow(tab: tab, isSelected: navigation.selectedTab == tab)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(SettingsStore.appName)
        .navigationSplitViewColumnWidth(
            min: 220,
            ideal: environment?.settings.compactSidebar == true ? 240 : AviationTheme.sidebarIdealWidth,
            max: 320
        )
        .onChange(of: navigation.selectedTab) { _, newTab in
            UserPreferences.shared.lastSelectedTab = newTab
            clearSelections(except: newTab)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentColumn: some View {
        switch navigation.selectedTab {
        case .logbook:
            FlightListView(
                selectedFlight: $selectedFlight,
                newFlightRequest: newFlightRequest,
                focusSearchRequest: focusSearchRequest,
                saveRequest: saveRequest
            )
        case .aircraft:
            NavigationStack { AircraftListView() }
        case .currency:
            NavigationStack { CurrencyDashboardView(selectedResult: $selectedCurrency) }
        case .endorsements:
            NavigationStack { EndorsementListView(selectedEndorsement: $selectedEndorsement) }
        case .reports:
            NavigationStack { ReportsDashboardView(selectedReportType: $selectedReportType) }
        case .training:
            NavigationStack { TrainingDashboardView(selectedRelationshipID: $selectedRelationshipID) }
        case .settings:
            NavigationStack { SettingsDashboardView() }
        default:
            PlaceholderTabView(tab: navigation.selectedTab)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailColumn: some View {
        switch navigation.selectedTab {
        case .logbook:
            if let flight = selectedFlight, flight.status == .finalized {
                NavigationStack { FlightDetailView(flight: flight) }
                    .readableContentWidth(maxWidth: AviationTheme.detailMaxReadableWidth)
            } else {
                AviationDetailPlaceholder(
                    title: "Select a Flight",
                    systemImage: "book.closed",
                    description: "Choose a finalized entry to view details, or press ⌘N to log a new flight.",
                    actionTitle: "Log Flight",
                    action: { AppShortcutNotifications.post(.newFlight) }
                )
            }
        case .currency:
            if let result = selectedCurrency {
                NavigationStack { CurrencyDetailView(result: result) }
            } else {
                AviationDetailPlaceholder(
                    title: "Currency Detail",
                    systemImage: "checkmark.shield",
                    description: "Select a currency item to view qualifying events and requirements."
                )
            }
        case .endorsements:
            if let endorsement = selectedEndorsement {
                NavigationStack { EndorsementDetailView(endorsement: endorsement) }
            } else {
                AviationDetailPlaceholder(
                    title: "Endorsement Detail",
                    systemImage: "signature",
                    description: "Select an endorsement to view the full text and signature."
                )
            }
        case .reports:
            if let reportType = selectedReportType {
                NavigationStack { ReportDetailView(reportType: reportType) }
            } else {
                AviationDetailPlaceholder(
                    title: "Report Detail",
                    systemImage: "chart.bar.doc.horizontal",
                    description: "Select a report type to view details and generate exports."
                )
            }
        case .training:
            if let relationshipID = selectedRelationshipID {
                NavigationStack { StudentDetailView(relationshipID: relationshipID) }
            } else {
                AviationDetailPlaceholder(
                    title: "Student Detail",
                    systemImage: "person.2",
                    description: "Select a student to view progress, log lessons, and check checkride readiness."
                )
            }
        case .aircraft:
            // Bug B: Aircraft has no lifted selection binding — AircraftListView
            // navigates via its own NavigationLink push inside the content column
            // (this is also the correct behavior in CompactRootView on iPhone, so
            // we intentionally do NOT lift selection out here). Give the detail
            // column a tab-appropriate placeholder instead of the generic default.
            // See report: converting this to a true detail-pane experience needs
            // Rob's sign-off + Mac verification.
            AviationDetailPlaceholder(
                title: "Aircraft",
                systemImage: "airplane",
                description: "Your fleet and training devices. Tap an aircraft to view its hub, performance notes, and maintenance."
            )
        case .settings:
            // Bug B: Settings is a self-contained push list (also single-column on
            // iPhone). It does not currently warrant a dedicated detail pane —
            // holding for Rob's confirmation before building out detail content.
            AviationDetailPlaceholder(
                title: "Settings",
                systemImage: "gearshape",
                description: "Choose a settings category from the list to manage your profile, data, sync, and display preferences."
            )
        default:
            AviationDetailPlaceholder(
                title: "Detail",
                systemImage: "sidebar.right",
                description: "Select an item from the list to view details."
            )
        }
    }

    // MARK: - Shortcuts

    private func handleShortcut(_ action: AppShortcutAction) {
        switch action {
        case .newFlight:
            navigation.selectedTab = .logbook
            newFlightRequest += 1
        case .focusSearch:
            navigation.selectedTab = .logbook
            focusSearchRequest += 1
        case .toggleSidebar:
            navigation.columnVisibility = navigation.columnVisibility == .all ? .detailOnly : .all
        case .save:
            saveRequest += 1
        case .selectTab(let tab):
            navigation.selectedTab = tab
        }
    }

    private func clearSelections(except tab: AppTab) {
        if tab != .logbook { selectedFlight = nil }
        if tab != .currency { selectedCurrency = nil }
        if tab != .endorsements { selectedEndorsement = nil }
        if tab != .reports { selectedReportType = nil }
        if tab != .training { selectedRelationshipID = nil }
    }
}

/// Placeholder for tabs not yet implemented.
private struct PlaceholderTabView: View {
    let tab: AppTab

    var body: some View {
        AviationDetailPlaceholder(
            title: tab.title,
            systemImage: tab.systemImage,
            description: "Coming in a future phase."
        )
        .navigationTitle(tab.title)
    }
}

#Preview {
    RootView(navigation: NavigationCoordinator())
}