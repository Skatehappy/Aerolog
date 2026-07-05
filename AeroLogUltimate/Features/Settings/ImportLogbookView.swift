import SwiftUI
import UniformTypeIdentifiers

/// Import flights from CSV and portable backup formats.
struct ImportLogbookView: View {
    @Environment(\.appEnvironment) private var environment

    @State private var showFilePicker = false
    @State private var selectedStrategy: BackupRestoreStrategy = .merge
    @State private var isImporting = false
    @State private var importResult: LogbookImportResult?
    @State private var errorMessage: String?
    @State private var csvPreview: CSVImportPreview?
    @State private var pendingImportData: Data?
    @State private var pendingImportURL: URL?

    var body: some View {
        Form {
            Section("Import Strategy") {
                Picker("When duplicates exist", selection: $selectedStrategy) {
                    Text("Merge — skip duplicates").tag(BackupRestoreStrategy.merge)
                    Text("Replace — clear and import").tag(BackupRestoreStrategy.replaceAll)
                }
                .pickerStyle(.inline)
            }

            Section("Supported Formats") {
                Label("CSV — LogTen, ForeFlight, MyFlightbook, generic", systemImage: "tablecells")
                Label("JSON — AeroLog structured export", systemImage: "doc.text")
                Label("AeroLog Backup — full portable archive", systemImage: "archivebox")
            }

            Section {
                Button {
                    showFilePicker = true
                } label: {
                    Label(isImporting ? "Importing..." : "Choose File to Import", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isImporting)
            }

            if let result = importResult {
                Section("Last Import") {
                    LabeledContent("Flights imported", value: "\(result.importedFlights)")
                    LabeledContent("Aircraft added", value: "\(result.importedAircraft)")
                    if result.skippedDuplicates > 0 {
                        LabeledContent("Skipped duplicates", value: "\(result.skippedDuplicates)")
                    }
                    ForEach(result.warnings, id: \.self) { warning in
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle("Import")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .json, .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(item: $csvPreview) { preview in
            CSVImportPreviewSheet(
                preview: preview,
                strategy: selectedStrategy,
                onCancel: {
                    csvPreview = nil
                    pendingImportData = nil
                },
                onConfirm: {
                    confirmCSVImport(preview)
                }
            )
        }
        .alert("Import Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let service = environment?.dataManagementService else { return }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                guard let format = service.detectFormat(for: url) else {
                    throw DataManagementError.unsupportedFormat
                }
                if format == .csv {
                    pendingImportData = data
                    csvPreview = try service.previewCSVImport(data)
                } else {
                    isImporting = true
                    defer { isImporting = false }
                    importResult = try service.importData(data, format: format, strategy: selectedStrategy)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func confirmCSVImport(_ preview: CSVImportPreview) {
        guard let service = environment?.dataManagementService else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            importResult = try service.commitCSVImport(preview.rows, strategy: selectedStrategy)
            csvPreview = nil
            pendingImportData = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - CSV Preview Sheet

private struct CSVImportPreviewSheet: View {
    let preview: CSVImportPreview
    let strategy: BackupRestoreStrategy
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    ForEach(preview.summaryLines, id: \.self) { line in
                        Text(line)
                    }
                    if strategy == .replaceAll {
                        Text("Replace strategy will clear existing flights before import.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if preview.inferredTotalTimeCount > 0 {
                    Section("Inferred Total Time") {
                        Text("These rows had no total-time column; PIC, dual, or solo time was used instead.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(inferredRows.prefix(10), id: \.offset) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rowLabel(item.element))
                                    .font(.subheadline)
                                Text("Inferred \(TimeFormatting.display(item.element.totalTime ?? 0))h total")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        if inferredRows.count > 10 {
                            Text("+ \(inferredRows.count - 10) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Sample Flights") {
                    ForEach(sampleRows.prefix(8), id: \.offset) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rowLabel(item.element))
                                .font(.subheadline)
                            Text("\(TimeFormatting.display(item.element.totalTime ?? 0))h — \(item.element.departureICAO ?? "—") → \(item.element.arrivalICAO ?? "—")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if preview.flightCount > 8 {
                        Text("+ \(preview.flightCount - 8) more flights")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Review Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import \(preview.flightCount) Flights", action: onConfirm)
                }
            }
        }
    }

    private var inferredRows: [(offset: Int, element: CSVFlightImportRow)] {
        Array(preview.rows.enumerated()).filter { $0.element.totalTimeWasInferred }
    }

    private var sampleRows: [(offset: Int, element: CSVFlightImportRow)] {
        Array(preview.rows.enumerated())
    }

    private func rowLabel(_ row: CSVFlightImportRow) -> String {
        let date = row.flightDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown date"
        let aircraft = row.aircraftRegistration ?? "Unknown aircraft"
        return "\(date) — \(aircraft)"
    }
}

extension CSVImportPreview: Identifiable {
    var id: String { "\(sourceFormat)-\(flightCount)-\(inferredTotalTimeCount)" }
}