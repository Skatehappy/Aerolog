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
    @State private var activeSheet: ActiveSheet?
    @State private var customRequirements: [CurrencyRequirement] = []
    @State private var heldRatings: Set<PilotRating> = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Single sheet driver. Three stacked .sheet modifiers meant the recency
    // editor (needed to update currency dates) could present blank; route all
    // three through one .sheet(item:).
    private enum ActiveSheet: Identifiable {
        case recency
        case customEditor
        case editRequirement(CurrencyRequirement)
        var id: String {
            switch self {
            case .recency: "recency"
            case .customEditor: "customEditor"
            case .editRequirement(let requirement): "edit-\(requirement.persistentModelID)"
            }
        }
    }

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
        .sheet(item: $activeSheet, onDismiss: { refresh() }) { sheet in
            switch sheet {
            case .recency:
                NavigationStack { PilotRecencySettingsView() }
            case .customEditor:
                NavigationStack { CustomCurrencyEditorView() }
            case .editRequirement(let requirement):
                NavigationStack { CustomCurrencyEditorView(requirement: requirement) }
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
        .onReceive(NotificationCenter.default.publisher(for: .currencyDataChanged)) { _ in
            refresh()
        }
    }

    @ViewBuilder
    private func dashboardContent(_ summary: CurrencyDashboardSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryHeader(summary)
                if !summary.anomalyWarnings.isEmpty {
                    anomalyBanner(summary.anomalyWarnings)
                }
                if !summary.attentionItems.isEmpty {
                    attentionSection(summary.attentionItems)
                }
                scopedSections(summary.results)
                currencySections(summary.results)
                // F4: persistent disclaimer footer.
                Text("Currency figures are a planning aid — verify against the FARs. As pilot in command you are responsible for your currency and privileges.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
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
                    selectedResult = result
                } label: {
                    CurrencyStatusCard(result: result, isSelected: selectedResult?.id == result.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func anomalyBanner(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Heads up", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            ForEach(warnings, id: \.self) { warning in
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func resultCard(_ result: CurrencyCalculationResult) -> some View {
        Button {
            selectedResult = result
        } label: {
            CurrencyStatusCard(result: result, isSelected: selectedResult?.id == result.id)
        }
        .buttonStyle(.plain)
    }

    /// C4: class/category-grouped sections for scoped passenger/instrument currency.
    /// A class the pilot doesn't hold the rating for is shown as "Training toward".
    @ViewBuilder
    private func scopedSections(_ results: [CurrencyCalculationResult]) -> some View {
        let classResults = results.filter { $0.applicableClass != nil && $0.status != .notApplicable }
        let classes = AircraftClass.allCases.filter { cls in classResults.contains { $0.applicableClass == cls } }
        let catResults = results.filter { $0.applicableCategory != nil && $0.currencyType == .instrument && $0.status != .notApplicable }
        let categories = AircraftCategory.allCases.filter { cat in catResults.contains { $0.applicableCategory == cat } }

        VStack(alignment: .leading, spacing: 16) {
            ForEach(classes, id: \.self) { cls in
                let items = classResults.filter { $0.applicableClass == cls }
                let held = cls.matchingRating.map { heldRatings.contains($0) } ?? true
                VStack(alignment: .leading, spacing: 10) {
                    Text(held ? cls.displayName : "Training toward \(cls.displayName)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if !held {
                        Text("Currency shown for reference — rating not yet held.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(items) { resultCard($0) }
                }
            }
            ForEach(categories, id: \.self) { cat in
                let items = catResults.filter { $0.applicableCategory == cat }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Instrument — \(cat.displayName)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    ForEach(items) { resultCard($0) }
                }
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
        // Exclude class/category-scoped results — those render in scopedSections.
        let filtered = results.filter {
            types.contains($0.currencyType) && $0.status != .notApplicable
                && $0.applicableClass == nil && $0.applicableCategory == nil
        }
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
                    activeSheet = .recency
                } label: {
                    Label("Pilot Recency Dates", systemImage: "person.text.rectangle")
                }
                Button {
                    activeSheet = .customEditor
                } label: {
                    Label("Add Custom Currency", systemImage: "plus.circle")
                }
                if !customRequirements.isEmpty {
                    Menu {
                        ForEach(customRequirements, id: \.persistentModelID) { requirement in
                            Button(requirement.displayName) { activeSheet = .editRequirement(requirement) }
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
            heldRatings = Set((try? environment?.pilotProfileService.primaryProfile()?.ratings) ?? [])
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