import SwiftUI
import SwiftData

/// Main currency and recency dashboard with status summary and warnings.
struct CurrencyDashboardView: View {
    @Environment(\.appEnvironment) private var environment

    @Binding var selectedResult: CurrencyCalculationResult?
    @State private var summary: CurrencyDashboardSummary?

    init(selectedResult: Binding<CurrencyCalculationResult?> = .constant(nil)) {
        _selectedResult = selectedResult
    }
    @State private var showRecencySettings = false
    @State private var showCustomEditor = false
    @State private var editingRequirement: CurrencyRequirement?
    @State private var customRequirements: [CurrencyRequirement] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && summary == nil {
                ProgressView("Calculating currency...")
            } else if let summary {
                dashboardContent(summary)
            } else {
                ContentUnavailableView {
                    Label("Currency Unavailable", systemImage: "checkmark.shield")
                } description: {
                    Text("Set up your pilot profile and log flights to track currency.")
                } actions: {
                    Button("Refresh") { refresh() }
                }
            }
        }
        .navigationTitle("Currency")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showRecencySettings) {
            NavigationStack {
                PilotRecencySettingsView()
            }
        }
        .sheet(isPresented: $showCustomEditor, onDismiss: { refresh() }) {
            NavigationStack {
                CustomCurrencyEditorView()
            }
        }
        .sheet(item: $editingRequirement, onDismiss: { refresh() }) { requirement in
            NavigationStack {
                CustomCurrencyEditorView(requirement: requirement)
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
    private func dashboardContent(_ summary: CurrencyDashboardSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryHeader(summary)
                if !summary.attentionItems.isEmpty {
                    attentionSection(summary.attentionItems)
                }
                currencySections(summary.results)
            }
            .padding()
        }
    }

    private func summaryHeader(_ summary: CurrencyDashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currency Overview")
                .font(.title2.weight(.bold))

            HStack(spacing: 12) {
                SummaryPill(count: summary.currentCount, label: "Current", color: .green)
                SummaryPill(count: summary.expiringSoonCount, label: "Expiring", color: .orange)
                SummaryPill(count: summary.expiredCount, label: "Expired", color: .red)
                if summary.unknownCount > 0 {
                    SummaryPill(count: summary.unknownCount, label: "Setup", color: .yellow)
                }
            }

            Text("Updated \(summary.calculatedAt, format: .dateTime.hour().minute())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func attentionSection(_ items: [CurrencyCalculationResult]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Needs Attention", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(items) { result in
                Button {
                    print("[R2][item3] attention card tapped:", result.requirementName)  // TEMP DEBUG (Round 2)
                    selectedResult = result
                } label: {
                    CurrencyStatusCard(result: result, isSelected: selectedResult?.id == result.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func currencySections(_ results: [CurrencyCalculationResult]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            currencyGroup(title: "FAA 61.57 — Flight Experience", results: results, types: [
                .passengerCarryingDay, .passengerCarryingNight, .instrument, .tailwheel
            ])
            currencyGroup(title: "Certification & Recency", results: results, types: [
                .flightReview, .instrumentProficiencyCheck, .medical, .cfiCertificate
            ])
            currencyGroup(title: "Aircraft Proficiency", results: results, types: [
                .complex, .highPerformance, .typeRating
            ])
            currencyGroup(title: "Custom", results: results, types: [.custom])
        }
    }

    private func currencyGroup(
        title: String,
        results: [CurrencyCalculationResult],
        types: [CurrencyType]
    ) -> some View {
        let filtered = results.filter { types.contains($0.currencyType) && $0.status != .notApplicable }
        let customs = types.contains(.custom) ? results.filter { $0.currencyType == .custom } : []
        let items = types.contains(.custom) ? customs : filtered

        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ForEach(items) { result in
                        Button {
                            print("[R2][item3] group card tapped:", result.requirementName)  // TEMP DEBUG (Round 2)
                            selectedResult = result
                        } label: {
                            CurrencyStatusCard(
                                result: result,
                                isSelected: selectedResult?.id == result.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { refresh() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Menu {
                Button {
                    showRecencySettings = true
                } label: {
                    Label("Pilot Recency Dates", systemImage: "person.text.rectangle")
                }
                Button {
                    showCustomEditor = true
                } label: {
                    Label("Add Custom Currency", systemImage: "plus.circle")
                }
                if !customRequirements.isEmpty {
                    Menu {
                        ForEach(customRequirements, id: \.persistentModelID) { requirement in
                            Button(requirement.displayName) { editingRequirement = requirement }
                        }
                    } label: {
                        Label("Edit Custom Currency", systemImage: "pencil")
                    }
                }
            } label: {
                Label("Options", systemImage: "ellipsis.circle")
            }
        }
    }

    private func refresh() {
        guard let service = environment?.currencyService else { return }
        isLoading = true
        do {
            summary = try service.calculateDashboard()
            customRequirements = try service.allRequirements().filter { $0.currencyType == .custom }
            if selectedResult == nil {
                selectedResult = summary?.attentionItems.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct SummaryPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}