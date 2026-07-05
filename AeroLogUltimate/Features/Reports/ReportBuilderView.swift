import SwiftUI
import SwiftData

/// Configure filters, columns, and generate a report.
struct ReportBuilderView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    let initialType: ReportType?
    let initialFilter: ReportFilter
    let initialConfiguration: ReportConfiguration?

    @Query(sort: \Aircraft.registration) private var aircraft: [Aircraft]

    @State private var reportType: ReportType
    @State private var outputFormat: ReportOutputFormat
    @State private var useDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var finalizedOnly = true
    @State private var selectedAircraftIDs: Set<UUID> = []
    @State private var selectedRoles: Set<FlightRole> = []
    @State private var selectedColumns: Set<ReportColumn>
    @State private var saveDefinition = false
    @State private var definitionName = ""
    @State private var generatedReport: GeneratedReport?
    @State private var showPreview = false
    @State private var errorMessage: String?

    init(
        initialType: ReportType? = nil,
        initialFilter: ReportFilter = .allTime,
        initialConfiguration: ReportConfiguration? = nil
    ) {
        self.initialType = initialType
        self.initialFilter = initialFilter
        self.initialConfiguration = initialConfiguration
        let type = initialType ?? .totalTimeSummary
        _reportType = State(initialValue: type)
        _outputFormat = State(initialValue: (initialType ?? .totalTimeSummary).defaultFormat)
        _useDateRange = State(initialValue: initialFilter.startDate != nil || initialFilter.endDate != nil)
        _startDate = State(initialValue: initialFilter.startDate ?? Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now)
        _endDate = State(initialValue: initialFilter.endDate ?? .now)
        _finalizedOnly = State(initialValue: initialFilter.finalizedOnly)
        _selectedAircraftIDs = State(initialValue: Set(initialFilter.aircraftSyncIDs ?? []))
        _selectedRoles = State(initialValue: Set(initialFilter.roles ?? []))
        let config = initialConfiguration ?? .defaultFor(type)
        _selectedColumns = State(initialValue: Set(config.columns))
    }

    var body: some View {
        Form {
            Section("Report Type") {
                Picker("Type", selection: $reportType) {
                    ForEach(ReportType.allCases.filter { $0 != .currencySummary }, id: \.self) { type in
                        Label(type.displayName, systemImage: type.systemImage).tag(type)
                    }
                }
                .onChange(of: reportType) { _, newType in
                    outputFormat = newType.defaultFormat
                    if selectedColumns.isEmpty || !newType.supportsColumnCustomization {
                        selectedColumns = Set(ReportConfiguration.defaultFor(newType).columns)
                    }
                }
                Picker("Format", selection: $outputFormat) {
                    ForEach(ReportOutputFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
            }

            Section("Filters") {
                Toggle("Date Range", isOn: $useDateRange)
                if useDateRange {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }
                Toggle("Finalized Flights Only", isOn: $finalizedOnly)
            }

            if !activeAircraft.isEmpty {
                Section("Aircraft") {
                    ForEach(activeAircraft) { item in
                        let id = item.syncID
                        Toggle(item.displayName, isOn: Binding(
                            get: { selectedAircraftIDs.contains(id) },
                            set: { isOn in
                                if isOn { selectedAircraftIDs.insert(id) }
                                else { selectedAircraftIDs.remove(id) }
                            }
                        ))
                    }
                    if !selectedAircraftIDs.isEmpty {
                        Button("Clear Aircraft Filter") { selectedAircraftIDs.removeAll() }
                    }
                }
            }

            Section("Flight Role") {
                ForEach(FlightRole.allCases, id: \.self) { role in
                    Toggle(role.displayName, isOn: Binding(
                        get: { selectedRoles.contains(role) },
                        set: { isOn in
                            if isOn { selectedRoles.insert(role) }
                            else { selectedRoles.remove(role) }
                        }
                    ))
                }
                if !selectedRoles.isEmpty {
                    Button("Clear Role Filter") { selectedRoles.removeAll() }
                }
            }

            if reportType.supportsColumnCustomization {
                Section("Columns") {
                    ForEach(ReportColumn.allCases) { column in
                        Toggle(column.displayName, isOn: Binding(
                            get: { selectedColumns.contains(column) },
                            set: { isOn in
                                if isOn { selectedColumns.insert(column) }
                                else { selectedColumns.remove(column) }
                            }
                        ))
                    }
                    HStack {
                        Button("FAA Logbook Defaults") {
                            selectedColumns = Set(ReportConfiguration.faaLogbook.columns)
                        }
                        Button("All Columns") {
                            selectedColumns = Set(ReportColumn.allCases)
                        }
                    }
                    .font(.caption)
                }
            }

            if reportType.supportsSavedDefinition {
                Section("Save Configuration") {
                    Toggle("Save for Repeat Use", isOn: $saveDefinition)
                    if saveDefinition {
                        TextField("Report Name", text: $definitionName)
                    }
                }
            }

            Section {
                Button("Generate Report") { generate() }
                    .fontWeight(.semibold)
                    .disabled(reportType.supportsColumnCustomization && selectedColumns.isEmpty)
            }
        }
        .navigationTitle("Report Builder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showPreview) {
            if let generatedReport {
                NavigationStack {
                    ReportPreviewView(report: generatedReport)
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
        .onAppear {
            if definitionName.isEmpty {
                definitionName = reportType.displayName
            }
        }
    }

    private var activeAircraft: [Aircraft] {
        aircraft.filter(\.isActive)
    }

    private func currentFilter() -> ReportFilter {
        var filter = ReportFilter(finalizedOnly: finalizedOnly)
        if useDateRange {
            filter.startDate = startDate
            filter.endDate = endDate
        }
        if !selectedAircraftIDs.isEmpty {
            filter.aircraftSyncIDs = Array(selectedAircraftIDs)
        }
        if !selectedRoles.isEmpty {
            filter.roles = Array(selectedRoles)
        }
        return filter
    }

    private func currentConfiguration() -> ReportConfiguration {
        ReportConfiguration(columns: Array(selectedColumns).sorted { lhs, rhs in
            let leftIndex = ReportColumn.allCases.firstIndex(of: lhs) ?? 0
            let rightIndex = ReportColumn.allCases.firstIndex(of: rhs) ?? 0
            return leftIndex < rightIndex
        })
    }

    private func generate() {
        guard let service = environment?.reportService else { return }
        do {
            let config = reportType.supportsColumnCustomization ? currentConfiguration() : .defaultFor(reportType)
            let report = try service.generate(
                type: reportType,
                filter: currentFilter(),
                format: outputFormat,
                configuration: config
            )
            generatedReport = report
            if saveDefinition, reportType.supportsSavedDefinition {
                let owner = try environment?.pilotProfileService.primaryProfile()
                _ = try environment?.reportDefinitionService.create(
                    name: definitionName.isEmpty ? reportType.displayName : definitionName,
                    reportType: reportType,
                    outputFormat: outputFormat,
                    filter: currentFilter(),
                    configuration: config,
                    owner: owner
                )
            }
            showPreview = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}