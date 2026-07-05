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
            isImporting = true
            defer { isImporting = false }
            do {
                importResult = try service.importFile(at: url, strategy: selectedStrategy)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}