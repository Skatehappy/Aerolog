import SwiftUI

/// Configure filters and generate a report.
struct ReportBuilderView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    let initialType: ReportType?
    let initialFilter: ReportFilter

    @State private var reportType: ReportType
    @State private var outputFormat: ReportOutputFormat
    @State private var useDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var finalizedOnly = true
    @State private var saveDefinition = false
    @State private var definitionName = ""
    @State private var generatedReport: GeneratedReport?
    @State private var showPreview = false
    @State private var errorMessage: String?

    init(initialType: ReportType? = nil, initialFilter: ReportFilter = .allTime) {
        self.initialType = initialType
        self.initialFilter = initialFilter
        _reportType = State(initialValue: initialType ?? .totalTimeSummary)
        _outputFormat = State(initialValue: (initialType ?? .totalTimeSummary).defaultFormat)
        _useDateRange = State(initialValue: initialFilter.startDate != nil || initialFilter.endDate != nil)
        _startDate = State(initialValue: initialFilter.startDate ?? Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now)
        _endDate = State(initialValue: initialFilter.endDate ?? .now)
        _finalizedOnly = State(initialValue: initialFilter.finalizedOnly)
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

    private func currentFilter() -> ReportFilter {
        var filter = ReportFilter(finalizedOnly: finalizedOnly)
        if useDateRange {
            filter.startDate = startDate
            filter.endDate = endDate
        }
        return filter
    }

    private func generate() {
        guard let service = environment?.reportService else { return }
        do {
            let report = try service.generate(type: reportType, filter: currentFilter(), format: outputFormat)
            generatedReport = report
            if saveDefinition, reportType.supportsSavedDefinition {
                let owner = try environment?.pilotProfileService.primaryProfile()
                _ = try environment?.reportDefinitionService.create(
                    name: definitionName.isEmpty ? reportType.displayName : definitionName,
                    reportType: reportType,
                    outputFormat: outputFormat,
                    filter: currentFilter(),
                    owner: owner
                )
            }
            showPreview = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}