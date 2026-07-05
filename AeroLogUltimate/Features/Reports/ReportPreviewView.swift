import SwiftUI

/// Preview and export a generated report.
struct ReportPreviewView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    let report: GeneratedReport

    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                reportContent
            }
            .padding()
        }
        .navigationTitle(report.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportReport()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ShareSheet(items: [shareURL])
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
        VStack(alignment: .leading, spacing: 6) {
            Text(report.type.displayName)
                .font(.headline)
            Text(report.filter.displaySummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Format: \(report.format.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var reportContent: some View {
        if let totals = report.totalTime {
            timeSummarySection(totals)
        }
        if let faa = report.faa8710 {
            faa8710Section(faa)
        }
        if let rows = report.flightLog {
            flightLogSection(rows)
        }
        if let airports = report.airports {
            airportSection(airports)
        }
        if let aircraft = report.aircraft {
            aircraftSection(aircraft)
        }
        if let progress = report.studentProgress {
            studentSection(progress)
        }
        if let dashboard = report.dashboard {
            dashboardSection(dashboard)
        }
    }

    private func timeSummarySection(_ totals: TotalTimeSummary) -> some View {
        section(title: "Time Summary", icon: "clock") {
            StatisticRow(label: "Total Time", value: TimeFormatting.display(totals.totalTime) + " hrs")
            StatisticRow(label: "PIC", value: TimeFormatting.display(totals.picTime))
            StatisticRow(label: "Solo", value: TimeFormatting.display(totals.soloTime))
            StatisticRow(label: "Dual Received", value: TimeFormatting.display(totals.dualReceived))
            StatisticRow(label: "Dual Given", value: TimeFormatting.display(totals.dualGiven))
            StatisticRow(label: "Cross Country", value: TimeFormatting.display(totals.crossCountryTime))
            StatisticRow(label: "Night", value: TimeFormatting.display(totals.nightTime))
            StatisticRow(label: "Landings", value: "\(totals.dayLandings) day / \(totals.nightLandings) night")
        }
    }

    private func faa8710Section(_ faa: FAA8710Totals) -> some View {
        section(title: "FAA 8710 Totals", icon: "doc.text") {
            if let cert = faa.certificateNumber {
                StatisticRow(label: "Certificate #", value: cert)
            }
            StatisticRow(label: "Total Time", value: TimeFormatting.display(faa.totalTime))
            StatisticRow(label: "Airplane SEL", value: TimeFormatting.display(faa.airplaneSingleEngineLand))
            StatisticRow(label: "Airplane MEL", value: TimeFormatting.display(faa.airplaneMultiEngineLand))
            StatisticRow(label: "Rotorcraft", value: TimeFormatting.display(faa.rotorcraftHelicopter))
            StatisticRow(label: "Instructor Time", value: TimeFormatting.display(faa.instructorTime))
        }
    }

    private func flightLogSection(_ rows: [FlightLogRow]) -> some View {
        section(title: "Flight Log (\(rows.count))", icon: "book.closed") {
            ForEach(rows.prefix(50)) { row in
                StatisticRow(
                    label: row.date.formatted(date: .abbreviated, time: .omitted),
                    value: TimeFormatting.display(row.totalTime) + " hrs",
                    detail: "\(row.route) · \(row.aircraft)"
                )
            }
        }
    }

    private func airportSection(_ airports: [AirportStatistic]) -> some View {
        section(title: "Airports", icon: "mappin.and.ellipse") {
            ForEach(airports.prefix(25)) { stat in
                StatisticRow(label: stat.icao, value: TimeFormatting.display(stat.totalTime) + " hrs", detail: "\(stat.visitCount) visits")
            }
        }
    }

    private func aircraftSection(_ aircraft: [AircraftStatistic]) -> some View {
        section(title: "Aircraft", icon: "airplane") {
            ForEach(aircraft.prefix(25)) { stat in
                StatisticRow(label: stat.registration, value: TimeFormatting.display(stat.totalTime) + " hrs", detail: stat.makeModel)
            }
        }
    }

    private func studentSection(_ progress: StudentProgressReport) -> some View {
        section(title: "Student Progress", icon: "person.2") {
            ForEach(progress.students) { entry in
                StatisticRow(
                    label: entry.studentName,
                    value: TimeFormatting.display(entry.dualGivenTime) + " dual",
                    detail: "\(entry.flightCount) flights"
                )
            }
        }
    }

    private func dashboardSection(_ dashboard: AnalyticsDashboard) -> some View {
        section(title: "Analytics Snapshot", icon: "chart.bar") {
            StatisticRow(label: "Flights", value: "\(dashboard.totalFlights)")
            StatisticRow(label: "Total Time", value: TimeFormatting.display(dashboard.totalTime))
            TimeBreakdownChart(buckets: dashboard.monthlyBuckets)
        }
    }

    private func section<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func exportReport() {
        guard let service = environment?.reportService else { return }
        do {
            let exported = try service.export(report)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(exported.fileName)
            try exported.data.write(to: url)
            shareURL = url
            showShare = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}