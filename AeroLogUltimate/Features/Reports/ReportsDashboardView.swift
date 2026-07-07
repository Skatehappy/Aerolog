import SwiftUI
import SwiftData

/// Analytics overview and quick access to report generation.
struct ReportsDashboardView: View {
    @Environment(\.appEnvironment) private var environment

    @Binding var selectedReportType: ReportType?

    @Query(sort: \ReportDefinition.name) private var savedReports: [ReportDefinition]

    @State private var dashboard: AnalyticsDashboard?
    @State private var filter: ReportFilter = .allTime
    @State private var isLoading = true
    @State private var activeSheet: ActiveSheet?
    @State private var builderType: ReportType?
    @State private var errorMessage: String?

    // Single sheet driver — stacking .sheet(isPresented:) for the builder and the
    // saved-reports list made the report builder present blank. Route both
    // through one .sheet(item:).
    private enum ActiveSheet: Identifiable {
        case builder, saved
        var id: Self { self }
    }

    init(selectedReportType: Binding<ReportType?> = .constant(nil)) {
        _selectedReportType = selectedReportType
    }

    var body: some View {
        Group {
            if isLoading && dashboard == nil {
                ProgressView("Calculating analytics...")
            } else if let dashboard {
                dashboardContent(dashboard)
            } else {
                ContentUnavailableView {
                    Label("No Analytics", systemImage: "chart.bar.doc.horizontal")
                } description: {
                    Text("Log finalized flights to see totals and trends.")
                } actions: {
                    Button("Refresh") { refresh() }
                }
            }
        }
        .navigationTitle("Reports")
        .toolbar { toolbarContent }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .builder:
                NavigationStack {
                    ReportBuilderView(initialType: builderType, initialFilter: filter)
                }
            case .saved:
                NavigationStack {
                    SavedReportsListView()
                }
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
        .task { refresh() }
        .refreshable { refresh() }
    }

    @ViewBuilder
    private func dashboardContent(_ dashboard: AnalyticsDashboard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryGrid(dashboard)
                TimeCategoryChart(
                    picTime: dashboard.picTime,
                    soloTime: dashboard.soloTime,
                    dualReceived: dashboard.dualReceived,
                    dualGiven: dashboard.dualGiven,
                    crossCountryTime: dashboard.crossCountryTime,
                    nightTime: dashboard.nightTime,
                    instrumentTime: dashboard.actualInstrumentTime + dashboard.simulatedInstrumentTime
                )
                TimeBreakdownChart(buckets: dashboard.monthlyBuckets)
                quickReportsSection
                if !dashboard.topAirports.isEmpty {
                    RankingBarChart(
                        title: "Top Airports",
                        systemImage: "mappin.and.ellipse",
                        items: dashboard.topAirports.map {
                            ($0.icao, $0.totalTime, "\($0.visitCount) visits")
                        }
                    )
                }
                if !dashboard.topAircraft.isEmpty {
                    RankingBarChart(
                        title: "Top Aircraft",
                        systemImage: "airplane",
                        items: dashboard.topAircraft.map {
                            ($0.registration, $0.totalTime, "\($0.makeModel) · \($0.flightCount) flights")
                        }
                    )
                }
            }
            .padding()
        }
    }

    private func summaryGrid(_ dashboard: AnalyticsDashboard) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            AnalyticsSummaryCard(title: "Total Time", value: TimeFormatting.display(dashboard.totalTime), subtitle: "\(dashboard.totalFlights) flights", systemImage: "clock")
            AnalyticsSummaryCard(title: "PIC", value: TimeFormatting.display(dashboard.picTime), systemImage: "person.fill", tint: .blue)
            AnalyticsSummaryCard(title: "Cross Country", value: TimeFormatting.display(dashboard.crossCountryTime), systemImage: "map", tint: .green)
            AnalyticsSummaryCard(title: "Night", value: TimeFormatting.display(dashboard.nightTime), systemImage: "moon.stars", tint: .indigo)
            AnalyticsSummaryCard(title: "Instrument", value: TimeFormatting.display(dashboard.actualInstrumentTime + dashboard.simulatedInstrumentTime), systemImage: "cloud.fog", tint: .cyan)
            AnalyticsSummaryCard(title: "Landings", value: "\(dashboard.dayLandings + dashboard.nightLandings)", subtitle: "\(dashboard.dayLandings) day / \(dashboard.nightLandings) night", systemImage: "airplane.arrival", tint: .orange)
        }
    }

    private var quickReportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generate Report")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ReportType.allCases.filter { $0 != .custom && $0 != .currencySummary }, id: \.self) { type in
                    Button {
                        builderType = type
                        selectedReportType = type
                        activeSheet = .builder
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: type.systemImage)
                                .font(.title3)
                            Text(type.displayName)
                                .font(.caption.weight(.medium))
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func rankingSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                builderType = nil
                activeSheet = .builder
            } label: {
                Label("New Report", systemImage: "plus")
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Menu {
                Button { activeSheet = .saved } label: {
                    Label("Saved Reports", systemImage: "bookmark")
                }
                Button { refresh() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private func refresh() {
        isLoading = true
        defer { isLoading = false }
        dashboard = try? environment?.reportService.dashboard(filter: filter)
    }
}