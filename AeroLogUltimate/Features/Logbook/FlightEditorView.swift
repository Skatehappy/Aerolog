import SwiftUI

/// Full flight entry and edit form — all logbook fields for Phase 1.
struct FlightEditorView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var flight: Flight
    let isNew: Bool
    var saveRequest: Int = 0

    @State private var useMultiLeg = false
    @State private var showAircraftPicker = false
    @State private var showDeleteConfirm = false
    @State private var showDiscardConfirm = false
    @State private var validationErrors: [String] = []
    @State private var validationWarnings: [String] = []
    @State private var showValidationAlert = false
    @State private var saveError: String?

    private var isSimulator: Bool {
        flight.aircraft?.isSimulator == true
    }

    var body: some View {
        Form {
            statusSection
            FlightBasicsSection(flight: flight, showAircraftPicker: $showAircraftPicker)
            FlightRouteSection(flight: flight, useMultiLeg: $useMultiLeg, onEnableMultiLeg: enableMultiLeg)
            if useMultiLeg {
                FlightLegsSection(flight: flight)
            }
            FlightTimesSection(flight: flight, isSimulator: isSimulator)
            FlightLandingsSection(flight: flight)
            FlightConditionsSection(flight: flight)
            if let aircraft = flight.aircraft, (aircraft.tracksHobbs || aircraft.tracksTach) {
                FlightHobbsSection(flight: flight, aircraft: aircraft)
            }
            FlightApproachesSection(flight: flight)
            FlightTrainingSection(flight: flight)
            FlightRemarksSection(flight: flight)
            FlightAttachmentsSection(flight: flight)

            if !isNew {
                Section {
                    Button("Delete Flight", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle(isNew ? "Log Flight" : "Edit Flight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { editorToolbar }
        .sheet(isPresented: $showAircraftPicker) {
            AircraftPickerSheet(selectedAircraft: $flight.aircraft)
        }
        .onAppear {
            useMultiLeg = flight.usesMultiLeg
        }
        .onChange(of: saveRequest) { _, _ in
            saveDraft()
        }
        .deleteConfirmation(
            title: flight.isFinalized ? "Delete Finalized Entry?" : "Delete Flight?",
            message: flight.isFinalized
                ? "This permanently removes a finalized logbook entry."
                : "Delete this flight entry?",
            isPresented: $showDeleteConfirm,
            onConfirm: deleteFlight
        )
        .alert("Validation", isPresented: $showValidationAlert) {
            if validationErrors.isEmpty {
                Button("Finalize Anyway") { performFinalize() }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text([validationErrors, validationWarnings].flatMap { $0 }.joined(separator: "\n"))
        }
        .alert("Error", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack {
                StatusBadge(status: flight.status)
                Spacer()
                if flight.isFinalized, let date = flight.finalizedAt {
                    Text("Finalized \(date, format: .dateTime.month().day().hour().minute())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                if isNew && flight.totalTime == 0 && flight.departureICAO.isEmpty {
                    modelContext.delete(flight)
                }
                dismiss()
            }
        }

        ToolbarItem(placement: .secondaryAction) {
            Button("Save Draft") { saveDraft() }
        }

        ToolbarItem(placement: .confirmationAction) {
            if flight.isDraft {
                Button("Finalize") { attemptFinalize() }
                    .fontWeight(.semibold)
            } else {
                Button("Done") {
                    saveDraft()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Actions

    private func enableMultiLeg() {
        if (flight.legs?.count ?? 0) == 0 {
            try? environment?.flightService.addLeg(to: flight)
            if (flight.legs?.count ?? 0) < 2 {
                try? environment?.flightService.addLeg(to: flight)
            }
        }
    }

    private func saveDraft() {
        if useMultiLeg { flight.syncRouteFromLegs() }
        flight.touch()
        do {
            try environment?.flightService.save(flight)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func attemptFinalize() {
        if useMultiLeg { flight.syncRouteFromLegs() }
        let result = FlightValidation.validateForFinalize(flight)
        validationErrors = result.errors
        validationWarnings = result.warnings

        if result.isValid && result.warnings.isEmpty {
            performFinalize()
        } else {
            showValidationAlert = true
        }
    }

    private func performFinalize() {
        do {
            try environment?.flightService.finalize(flight)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func deleteFlight() {
        do {
            try environment?.flightService.delete(flight, force: true)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}