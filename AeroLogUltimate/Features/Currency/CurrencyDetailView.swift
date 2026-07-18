import SwiftUI

/// Detailed breakdown for a single currency requirement.
struct CurrencyDetailView: View {
    @Environment(\.appEnvironment) private var environment
    let inputResult: CurrencyCalculationResult

    @State private var override: CurrencyCalculationResult?
    @State private var showManualPicker = false
    @State private var manualDate = Date()
    @State private var errorMessage: String?

    init(result: CurrencyCalculationResult) { self.inputResult = result }

    /// After a manual attestation we recompute and show the fresh result in place;
    /// `override` is cleared when the parent selects a different requirement so the
    /// reused view can't show a stale currency (iPad split-view detail reuse).
    private var result: CurrencyCalculationResult {
        if let override, override.requirementSyncID == inputResult.requirementSyncID { return override }
        return inputResult
    }

    private var supportsManualAttestation: Bool {
        switch result.currencyType {
        case .passengerCarryingDay, .passengerCarryingNight, .tailwheel,
             .instrument, .complex, .highPerformance, .custom:
            true
        default:
            false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                progressSection
                if let events = result.detail.qualifyingEvents, !events.isEmpty {
                    eventsSection(events)
                }
                if let action = result.detail.nextRequiredAction {
                    actionSection(action)
                }
                if supportsManualAttestation {
                    manualAttestationSection
                }
            }
            .padding()
        }
        .navigationTitle(result.requirementName)
        .sheet(isPresented: $showManualPicker) {
            manualPickerSheet
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        // Parent reused this view for a different requirement — drop the stale override.
        .onChange(of: inputResult.id) { _, _ in override = nil }
    }

    // Manual "current as of" attestation — for when a logbook import failed or
    // lacked the columns needed to compute landing/approach currency.
    private var manualAttestationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set Currency Manually")
                .font(.headline)
            if let manualDate = result.manualCurrentDate {
                Text("Marked current as of \(manualDate.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear Manual Attestation", role: .destructive) { save(nil) }
            } else {
                Text("If your logbook didn't import (or lacks full-stop landing / approach columns), record the date you last met this requirement. Logged flights still take over when they extend it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(result.manualCurrentDate == nil ? "Mark Current As Of…" : "Change Date…") {
                manualDate = result.manualCurrentDate ?? Date()
                showManualPicker = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var manualPickerSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Last met on", selection: $manualDate, in: ...Date(), displayedComponents: .date)
                Text("This is a self-attestation. As pilot in command you remain responsible for verifying your currency against the FARs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Mark Current")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showManualPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(manualDate); showManualPicker = false }
                }
            }
        }
    }

    private func save(_ date: Date?) {
        do {
            try environment?.currencyService.setManualCurrentDate(date, forRequirementSyncID: inputResult.requirementSyncID)
            // Recompute so this screen reflects the attestation immediately (the result
            // passed in is a snapshot; without this the status/date looked unchanged).
            if let updated = try environment?.currencyService.calculateDashboard().results
                .first(where: { $0.requirementSyncID == inputResult.requirementSyncID }) {
                override = updated
            }
            NotificationCenter.default.post(name: .currencyDataChanged, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: result.status.systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(statusColor)
                VStack(alignment: .leading) {
                    Text(result.status.displayName)
                        .font(.title2.weight(.bold))
                    if let reg = result.detail.regulationReference {
                        Text(reg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(result.summaryText)
                .font(.body)

            if let warning = result.warningText {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)

            if let fraction = result.detail.progressFraction {
                ProgressView(value: fraction)
                    .tint(statusColor)
                Text("\(Int(fraction * 100))% complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                progressRow("Day Landings", counted: result.detail.countedLandings, required: result.detail.requiredLandings)
                progressRow("Night Landings", counted: result.detail.countedNightLandings, required: result.detail.requiredNightLandings)
                progressRow("Approaches", counted: result.detail.countedApproaches, required: result.detail.requiredApproaches)
                progressRow("Holds", counted: result.detail.countedHolds, required: result.detail.requiredHolds)
                if let hours = result.detail.countedFlightHours, let req = result.detail.requiredFlightHours {
                    GridRow {
                        Text("Flight Hours")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(TimeFormatting.display(hours)) / \(TimeFormatting.display(req))")
                            .fontWeight(.medium)
                    }
                }
            }
            .font(.subheadline)

            if let expires = result.expiresAt {
                DetailRow(label: "Expires", value: expires.formatted(date: .abbreviated, time: .omitted))
            }
            if let start = result.windowStartDate, let end = result.windowEndDate {
                DetailRow(
                    label: "Lookback Window",
                    value: "\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func progressRow(_ label: String, counted: Int?, required: Int?) -> some View {
        if let required, let counted {
            GridRow {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(counted) / \(required)")
                    .fontWeight(.medium)
                    .foregroundStyle(counted >= required ? .green : .primary)
            }
        }
    }

    private func eventsSection(_ events: [QualifyingEvent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Qualifying Events")
                .font(.headline)

            ForEach(events) { event in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.subheadline.weight(.semibold))
                        Text(event.description)
                            .font(.subheadline)
                        Text(event.contribution)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                if event.id != events.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func actionSection(_ action: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To Regain Currency")
                .font(.headline)
            Text(action)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        switch result.status {
        case .current: .green
        case .expiringSoon: .orange
        case .expired: .red
        case .notApplicable: .gray
        case .unknown: .yellow
        }
    }
}