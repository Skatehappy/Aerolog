import SwiftUI

/// Export logbook data in multiple formats with share sheet delivery.
struct ExportOptionsView: View {
    @Environment(\.appEnvironment) private var environment

    @State private var selectedFormat: LogbookExportFormat = .pdf
    @State private var isExporting = false
    @State private var shareItem: ExportShareItem?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Export Format") {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(LogbookExportFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                formatDescription
            }

            Section {
                Button {
                    performExport()
                } label: {
                    Label(isExporting ? "Generating..." : "Export Logbook", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isExporting)
            }
        }
        .navigationTitle("Export")
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Export Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var formatDescription: some View {
        switch selectedFormat {
        case .pdf:
            Text("Professional print-ready PDF with FAA-style logbook columns, headers, and page footers.")
        case .csv:
            Text("Spreadsheet-compatible CSV for Excel, Google Sheets, or other logbook apps.")
        case .json:
            Text("Structured AeroLog JSON package for backup, migration, or programmatic access.")
        }
    }

    private func performExport() {
        guard let service = environment?.dataManagementService else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            let result = try service.exportLogbook(format: selectedFormat)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(result.fileName)
            try result.data.write(to: tempURL, options: .atomic)
            shareItem = ExportShareItem(url: tempURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}