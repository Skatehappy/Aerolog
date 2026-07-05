import SwiftUI

/// Detail pane for a selected report type in the split view.
struct ReportDetailView: View {
    @Environment(\.appEnvironment) private var environment

    let reportType: ReportType

    @State private var previewReport: GeneratedReport?
    @State private var showPreview = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                descriptionSection
                actionsSection
            }
            .padding()
        }
        .navigationTitle(reportType.displayName)
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

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: reportType.systemImage)
                .font(.largeTitle)
                .foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(reportType.displayName)
                    .font(.title2.weight(.bold))
                Text("Default format: \(reportType.defaultFormat.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
            Text(reportType.detailDescription)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                quickGenerate()
            } label: {
                Label(isLoading ? "Generating..." : "Quick Generate", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || reportType == .currencySummary)

            NavigationLink {
                ReportBuilderView(initialType: reportType)
            } label: {
                Label("Customize Filters", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func quickGenerate() {
        guard let service = environment?.reportService else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            previewReport = try service.generate(type: reportType)
            showPreview = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}