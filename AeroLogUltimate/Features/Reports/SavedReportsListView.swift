import SwiftUI
import SwiftData

/// Saved report configurations for one-tap regeneration.
struct SavedReportsListView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ReportDefinition.name) private var definitions: [ReportDefinition]

    @State private var previewReport: GeneratedReport?
    @State private var showPreview = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if definitions.isEmpty {
                ContentUnavailableView {
                    Label("No Saved Reports", systemImage: "bookmark")
                } description: {
                    Text("Save a report configuration from the builder for quick reuse.")
                }
            } else {
                List(definitions) { definition in
                    Button {
                        regenerate(definition)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(definition.name)
                                .font(.headline)
                            Text(definition.reportType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let last = definition.lastGeneratedAt {
                                Text("Last run \(last.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            do {
                                try environment?.reportDefinitionService.delete(definition)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showPreview) {
            if let previewReport {
                NavigationStack {
                    ReportPreviewView(report: previewReport)
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
    }

    private func regenerate(_ definition: ReportDefinition) {
        do {
            previewReport = try environment?.reportService.generate(from: definition)
            showPreview = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}