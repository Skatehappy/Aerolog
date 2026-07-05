import Foundation
import SwiftData

/// Orchestrates analytics calculation and report generation/export.
@MainActor
final class ReportService {
    let dataStore: DataStore
    private let engine = ReportAnalyticsEngine()
    private let exporter = ReportExporter()

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    // MARK: - Analytics

    func dashboard(for pilot: PilotProfile? = nil, filter: ReportFilter = .allTime) throws -> AnalyticsDashboard {
        let profile = try resolvedPilot(pilot)
        let flights = try pilotFlights(for: profile)
        return engine.dashboard(flights: flights, filter: filter, pilot: profile)
    }

    // MARK: - Generate

    func generate(
        type: ReportType,
        filter: ReportFilter = .allTime,
        format: ReportOutputFormat? = nil,
        pilot: PilotProfile? = nil
    ) throws -> GeneratedReport {
        let profile = try resolvedPilot(pilot)
        let flights = try pilotFlights(for: profile)
        let outputFormat = format ?? type.defaultFormat
        let title = type.displayName

        switch type {
        case .totalTimeSummary:
            return GeneratedReport(
                type: type, title: title, filter: filter, format: outputFormat, generatedAt: .now,
                dashboard: nil,
                totalTime: engine.totalTimeSummary(flights: flights, filter: filter, pilot: profile),
                faa8710: nil, flightLog: nil, airports: nil, aircraft: nil,
                studentProgress: nil, currencyResults: nil
            )
        case .faa8710:
            return GeneratedReport(
                type: type, title: title, filter: filter, format: outputFormat, generatedAt: .now,
                dashboard: nil, totalTime: nil,
                faa8710: engine.faa8710Totals(flights: flights, filter: filter, pilot: profile),
                flightLog: nil, airports: nil, aircraft: nil,
                studentProgress: nil, currencyResults: nil
            )
        case .flightLog:
            return GeneratedReport(
                type: type, title: title, filter: filter, format: outputFormat, generatedAt: .now,
                dashboard: nil, totalTime: nil, faa8710: nil,
                flightLog: engine.flightLogRows(flights: flights, filter: filter),
                airports: nil, aircraft: nil, studentProgress: nil, currencyResults: nil
            )
        case .airportStatistics:
            return GeneratedReport(
                type: type, title: title, filter: filter, format: outputFormat, generatedAt: .now,
                dashboard: nil, totalTime: nil, faa8710: nil, flightLog: nil,
                airports: engine.airportStatistics(flights: flights, filter: filter),
                aircraft: nil, studentProgress: nil, currencyResults: nil
            )
        case .aircraftStatistics:
            return GeneratedReport(
                type: type, title: title, filter: filter, format: outputFormat, generatedAt: .now,
                dashboard: nil, totalTime: nil, faa8710: nil, flightLog: nil, airports: nil,
                aircraft: engine.aircraftStatistics(flights: flights, filter: filter),
                studentProgress: nil, currencyResults: nil
            )
        case .studentProgress:
            guard profile.isCFI else { throw ReportServiceError.cfiRequired }
            return GeneratedReport(
                type: type, title: title, filter: filter, format: outputFormat, generatedAt: .now,
                dashboard: nil, totalTime: nil, faa8710: nil, flightLog: nil, airports: nil, aircraft: nil,
                studentProgress: engine.studentProgress(flights: flights, filter: filter, instructor: profile),
                currencyResults: nil
            )
        case .currencySummary:
            throw ReportServiceError.useCurrencyService
        case .custom:
            return GeneratedReport(
                type: type, title: "Custom Report", filter: filter, format: outputFormat, generatedAt: .now,
                dashboard: engine.dashboard(flights: flights, filter: filter, pilot: profile),
                totalTime: engine.totalTimeSummary(flights: flights, filter: filter, pilot: profile),
                faa8710: nil, flightLog: engine.flightLogRows(flights: flights, filter: filter),
                airports: engine.airportStatistics(flights: flights, filter: filter),
                aircraft: engine.aircraftStatistics(flights: flights, filter: filter),
                studentProgress: nil, currencyResults: nil
            )
        }
    }

    func generate(from definition: ReportDefinition) throws -> GeneratedReport {
        let report = try generate(
            type: definition.reportType,
            filter: definition.filter,
            format: definition.outputFormat,
            pilot: definition.owner
        )
        definition.markGenerated()
        try dataStore.save()
        return report
    }

    // MARK: - Export

    func export(_ report: GeneratedReport) throws -> (data: Data, fileName: String) {
        let data = try exporter.export(report)
        return (data, exporter.suggestedFileName(for: report))
    }

    // MARK: - Helpers

    private func resolvedPilot(_ pilot: PilotProfile?) throws -> PilotProfile {
        if let pilot { return pilot }
        guard let profile = try dataStore.primaryPilotProfile() else {
            throw ReportServiceError.pilotRequired
        }
        return profile
    }

    private func pilotFlights(for pilot: PilotProfile) throws -> [Flight] {
        let descriptor = FetchDescriptor<Flight>(
            sortBy: [SortDescriptor(\.flightDate, order: .reverse)]
        )
        let all = try dataStore.fetch(descriptor)
        return all.filter { flight in
            flight.pilot?.persistentModelID == pilot.persistentModelID
                && !(flight.syncMetadata?.isSoftDeleted ?? false)
        }
    }
}

enum ReportServiceError: LocalizedError {
    case pilotRequired
    case cfiRequired
    case useCurrencyService

    var errorDescription: String? {
        switch self {
        case .pilotRequired: "Set up a pilot profile before generating reports."
        case .cfiRequired: "Student progress reports require a CFI profile."
        case .useCurrencyService: "Generate currency summaries from the Currency tab."
        }
    }
}