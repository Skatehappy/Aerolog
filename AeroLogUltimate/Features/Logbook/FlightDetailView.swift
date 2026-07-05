import SwiftUI

/// Read-only flight detail for the iPad detail column.
struct FlightDetailView: View {
    @Environment(\.appEnvironment) private var environment

    let flight: Flight

    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                routeSection
                timesSection
                landingsSection
                if !(flight.approaches ?? []).isEmpty { approachesSection }
                if flight.usesMultiLeg { legsSection }
                if hasTrainingInfo { trainingSection }
                if let remarks = flight.remarks, !remarks.isEmpty { remarksSection(remarks) }
                if !(flight.attachments ?? []).isEmpty { attachmentsSection }
            }
            .padding()
        }
        .navigationTitle(flight.flightDate, format: .dateTime.month(.wide).day().year())
        .toolbar { toolbarContent }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                FlightEditorView(flight: flight, isNew: false)
            }
        }
        .deleteConfirmation(
            title: flight.isFinalized ? "Delete Finalized Entry?" : "Delete Draft?",
            message: deleteMessage,
            confirmLabel: "Delete",
            isPresented: $showDeleteConfirm,
            onConfirm: performDelete
        )
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    StatusBadge(status: flight.status)
                    Text(flight.role.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(flight.aircraftDisplay)
                    .font(.title2.weight(.semibold))
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(TimeFormatting.display(flight.totalTime))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("Total Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sections

    private var routeSection: some View {
        DetailSection(title: "Route", icon: "map") {
            DetailRow(label: "From", value: flight.departureICAO.isEmpty ? "—" : flight.departureICAO)
            DetailRow(label: "To", value: flight.arrivalICAO.isEmpty ? "—" : flight.arrivalICAO)
            if let route = flight.route, !route.isEmpty {
                DetailRow(label: "Route", value: route)
            }
        }
    }

    private var timesSection: some View {
        DetailSection(title: "Time Breakdown", icon: "clock") {
            timeRow("PIC", flight.picTime)
            timeRow("SIC", flight.sicTime)
            timeRow("Dual Received", flight.dualReceived)
            timeRow("Dual Given", flight.dualGiven)
            timeRow("Solo", flight.soloTime)
            timeRow("Cross Country", flight.crossCountryTime)
            timeRow("Night", flight.nightTime)
            timeRow("Actual Instrument", flight.actualInstrumentTime)
            timeRow("Simulated Instrument", flight.simulatedInstrumentTime)
            timeRow("Simulator", flight.simulatorTime)
            timeRow("Ground Instruction", flight.groundInstructionTime)
        }
    }

    private var landingsSection: some View {
        DetailSection(title: "Landings & Holds", icon: "airplane.arrival") {
            DetailRow(label: "Day Landings", value: "\(flight.dayLandings)")
            DetailRow(label: "Night Landings", value: "\(flight.nightLandings)")
            DetailRow(label: "Full Stop (Day)", value: "\(flight.fullStopDayLandings)")
            DetailRow(label: "Full Stop (Night)", value: "\(flight.fullStopNightLandings)")
            DetailRow(label: "Holds", value: "\(flight.holds)")
            if !flight.conditions.isEmpty {
                DetailRow(label: "Conditions", value: flight.conditions.map(\.displayName).joined(separator: ", "))
            }
        }
    }

    private var approachesSection: some View {
        DetailSection(title: "Approaches", icon: "arrow.down.to.line") {
            ForEach(flight.approaches ?? [], id: \.persistentModelID) { approach in
                DetailRow(
                    label: approach.approachType.displayName,
                    value: "\(approach.approachCount)× \(approach.airportICAO ?? "")"
                )
            }
        }
    }

    private var legsSection: some View {
        DetailSection(title: "Flight Legs", icon: "point.topleft.down.curvedto.point.bottomright.up") {
            ForEach(flight.sortedLegs, id: \.persistentModelID) { leg in
                DetailRow(
                    label: "Leg \(leg.legOrder + 1)",
                    value: "\(leg.departureICAO) → \(leg.arrivalICAO) (\(TimeFormatting.display(leg.legTime)))"
                )
            }
        }
    }

    private var trainingSection: some View {
        DetailSection(title: "Training", icon: "graduationcap") {
            if let title = flight.lessonTitle { DetailRow(label: "Lesson", value: title) }
            if let num = flight.lessonNumber { DetailRow(label: "Lesson #", value: num) }
            if let instructor = flight.instructorName { DetailRow(label: "Instructor", value: instructor) }
            if let cert = flight.instructorCertificateNumber { DetailRow(label: "CFI Cert #", value: cert) }
        }
    }

    private func remarksSection(_ remarks: String) -> some View {
        DetailSection(title: "Remarks", icon: "text.alignleft") {
            Text(remarks)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var attachmentsSection: some View {
        DetailSection(title: "Attachments", icon: "paperclip") {
            FlightAttachmentsGallery(flight: flight, readOnly: true)
        }
    }

    private var hasTrainingInfo: Bool {
        flight.lessonTitle != nil || flight.instructorName != nil
    }

    @ViewBuilder
    private func timeRow(_ label: String, _ value: Double) -> some View {
        if value > 0 {
            DetailRow(label: label, value: TimeFormatting.display(value))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showEditor = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            if flight.isDraft {
                Button {
                    finalizeFlight()
                } label: {
                    Label("Finalize", systemImage: "checkmark.seal")
                }
            } else {
                Button {
                    revertToDraft()
                } label: {
                    Label("Revert to Draft", systemImage: "arrow.uturn.backward")
                }
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var deleteMessage: String {
        if flight.isFinalized {
            return "This will permanently remove a finalized logbook entry. This action cannot be undone."
        }
        return "Delete this draft flight entry?"
    }

    private func finalizeFlight() {
        do {
            try environment?.flightService.finalize(flight)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revertToDraft() {
        try? environment?.flightService.revertToDraft(flight)
    }

    private func performDelete() {
        do {
            try environment?.flightService.delete(flight, force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Detail Helpers

struct DetailSection<Content: View>: View {
    let title: String
    var icon: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FormSectionHeader(title: title, systemImage: icon)
            VStack(spacing: 6) {
                content
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}