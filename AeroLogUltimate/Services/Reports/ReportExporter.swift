import Foundation
import UIKit

/// Exports generated reports to CSV, JSON, and PDF.
struct ReportExporter: Sendable {
    private let pdfRenderer = ReportPDFRenderer()

    func export(_ report: GeneratedReport) throws -> Data {
        switch report.format {
        case .csv: return try exportCSV(report)
        case .json: return try exportJSON(report)
        case .pdf: return pdfRenderer.render(report)
        }
    }

    func suggestedFileName(for report: GeneratedReport) -> String {
        let slug = report.title.replacingOccurrences(of: " ", with: "_")
        let date = report.generatedAt.formatted(.iso8601.year().month().day())
        let ext = report.format.rawValue
        return "AeroLog_\(slug)_\(date).\(ext)"
    }

    /// Standalone print-ready PDF for full logbook exports from Settings.
    func exportLogbookPDF(rows: [FlightLogRow], pilotName: String, certificateNumber: String?) -> Data {
        let report = GeneratedReport(
            type: .flightLog,
            title: "Pilot Logbook",
            filter: .allTime,
            format: .pdf,
            configuration: .faaLogbook,
            generatedAt: .now,
            dashboard: nil,
            totalTime: nil,
            faa8710: FAA8710Totals(
                pilotName: pilotName,
                certificateNumber: certificateNumber,
                addressLine: nil,
                generatedAt: .now,
                totalTime: rows.reduce(0) { $0 + $1.totalTime },
                picTime: rows.reduce(0) { $0 + $1.picTime },
                sicTime: rows.reduce(0) { $0 + $1.sicTime },
                dualReceived: rows.reduce(0) { $0 + $1.dualReceived },
                soloTime: rows.reduce(0) { $0 + $1.soloTime },
                crossCountryTime: rows.reduce(0) { $0 + $1.crossCountryTime },
                nightTime: rows.reduce(0) { $0 + $1.nightTime },
                actualInstrumentTime: rows.reduce(0) { $0 + $1.actualInstrumentTime },
                simulatedInstrumentTime: rows.reduce(0) { $0 + $1.simulatedInstrumentTime },
                dayLandings: rows.reduce(0) { $0 + $1.dayLandings },
                nightLandings: rows.reduce(0) { $0 + $1.nightLandings },
                airplaneSingleEngineLand: 0,
                airplaneMultiEngineLand: 0,
                rotorcraftHelicopter: 0,
                simulatorTime: rows.reduce(0) { $0 + $1.simulatorTime },
                instructorTime: rows.reduce(0) { $0 + $1.dualGiven }
            ),
            flightLog: rows,
            airports: nil,
            aircraft: nil,
            studentProgress: nil,
            currencyResults: nil
        )
        return pdfRenderer.render(report)
    }

    // MARK: - CSV

    private func exportCSV(_ report: GeneratedReport) throws -> Data {
        var lines: [String] = []
        lines.append("Report,\(csvEscape(report.title))")
        lines.append("Pilot,\(csvEscape(report.pilotDisplayName))")
        lines.append("Generated,\(report.generatedAt.formatted())")
        lines.append("Filter,\(csvEscape(report.filter.displaySummary))")
        lines.append("")

        switch report.type {
        case .flightLog, .custom:
            if let rows = report.flightLog {
                let columns = report.configuration.resolvedColumns(for: report.type)
                lines.append(columns.map(\.csvHeader).joined(separator: ","))
                for row in rows {
                    lines.append(columns.map { csvEscape($0.value(from: row)) }.joined(separator: ","))
                }
            }
        case .airportStatistics:
            lines.append("ICAO,Departures,Arrivals,Visits,Total Time")
            for stat in report.airports ?? [] {
                lines.append("\(stat.icao),\(stat.departures),\(stat.arrivals),\(stat.visitCount),\(TimeFormatting.display(stat.totalTime))")
            }
        case .aircraftStatistics:
            lines.append("Registration,Make/Model,Flights,Total Time")
            for stat in report.aircraft ?? [] {
                lines.append("\(csvEscape(stat.registration)),\(csvEscape(stat.makeModel)),\(stat.flightCount),\(TimeFormatting.display(stat.totalTime))")
            }
        case .studentProgress:
            lines.append("Student,Dual Given,Ground,Flights,Last Lesson,Lesson Title")
            for entry in report.studentProgress?.students ?? [] {
                lines.append([
                    csvEscape(entry.studentName),
                    TimeFormatting.display(entry.dualGivenTime),
                    TimeFormatting.display(entry.groundInstructionTime),
                    "\(entry.flightCount)",
                    entry.lastLessonDate?.formatted(date: .abbreviated, time: .omitted) ?? "",
                    csvEscape(entry.lastLessonTitle ?? "")
                ].joined(separator: ","))
            }
        case .faa8710:
            if let faa = report.faa8710 {
                lines.append("Category,Hours")
                lines.append("Total,\(TimeFormatting.display(faa.totalTime))")
                lines.append("PIC,\(TimeFormatting.display(faa.picTime))")
                lines.append("SIC,\(TimeFormatting.display(faa.sicTime))")
                lines.append("Dual Received,\(TimeFormatting.display(faa.dualReceived))")
                lines.append("Solo,\(TimeFormatting.display(faa.soloTime))")
                lines.append("Cross Country,\(TimeFormatting.display(faa.crossCountryTime))")
                lines.append("Night,\(TimeFormatting.display(faa.nightTime))")
                lines.append("Actual Instrument,\(TimeFormatting.display(faa.actualInstrumentTime))")
                lines.append("Simulated Instrument,\(TimeFormatting.display(faa.simulatedInstrumentTime))")
                lines.append("Airplane SEL,\(TimeFormatting.display(faa.airplaneSingleEngineLand))")
                lines.append("Airplane MEL,\(TimeFormatting.display(faa.airplaneMultiEngineLand))")
                lines.append("Rotorcraft,\(TimeFormatting.display(faa.rotorcraftHelicopter))")
                lines.append("Simulator,\(TimeFormatting.display(faa.simulatorTime))")
                lines.append("Instructor,\(TimeFormatting.display(faa.instructorTime))")
                lines.append("Day Landings,\(faa.dayLandings)")
                lines.append("Night Landings,\(faa.nightLandings)")
            }
            if let rows = report.flightLog, !rows.isEmpty {
                lines.append("")
                let columns = report.configuration.resolvedColumns(for: .faa8710)
                lines.append(columns.map(\.csvHeader).joined(separator: ","))
                for row in rows {
                    lines.append(columns.map { csvEscape($0.value(from: row)) }.joined(separator: ","))
                }
            }
        default:
            if let totals = report.totalTime {
                lines.append("Category,Hours")
                lines.append("Total Flights,\(totals.totalFlights)")
                lines.append("Total,\(TimeFormatting.display(totals.totalTime))")
                lines.append("PIC,\(TimeFormatting.display(totals.picTime))")
                lines.append("SIC,\(TimeFormatting.display(totals.sicTime))")
                lines.append("Dual Received,\(TimeFormatting.display(totals.dualReceived))")
                lines.append("Dual Given,\(TimeFormatting.display(totals.dualGiven))")
                lines.append("Solo,\(TimeFormatting.display(totals.soloTime))")
                lines.append("Cross Country,\(TimeFormatting.display(totals.crossCountryTime))")
                lines.append("Night,\(TimeFormatting.display(totals.nightTime))")
                lines.append("Actual Instrument,\(TimeFormatting.display(totals.actualInstrumentTime))")
                lines.append("Simulated Instrument,\(TimeFormatting.display(totals.simulatedInstrumentTime))")
                lines.append("Ground Instruction,\(TimeFormatting.display(totals.groundInstructionTime))")
                lines.append("Simulator,\(TimeFormatting.display(totals.simulatorTime))")
                lines.append("Day Landings,\(totals.dayLandings)")
                lines.append("Night Landings,\(totals.nightLandings)")
                lines.append("Approaches,\(totals.approachCount)")
            }
        }

        return Data(lines.joined(separator: "\n").utf8)
    }

    // MARK: - JSON

    private func exportJSON(_ report: GeneratedReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let wrapper = JSONReportWrapper(
            type: report.type.rawValue,
            title: report.title,
            generatedAt: report.generatedAt,
            filterSummary: report.filter.displaySummary,
            configuration: report.configuration,
            dashboard: report.dashboard,
            totalTime: report.totalTime,
            faa8710: report.faa8710,
            flightLog: report.flightLog,
            airports: report.airports,
            aircraft: report.aircraft,
            studentProgress: report.studentProgress
        )
        return try encoder.encode(wrapper)
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

private struct JSONReportWrapper: Codable {
    let type: String
    let title: String
    let generatedAt: Date
    let filterSummary: String
    let configuration: ReportConfiguration
    let dashboard: AnalyticsDashboard?
    let totalTime: TotalTimeSummary?
    let faa8710: FAA8710Totals?
    let flightLog: [FlightLogRow]?
    let airports: [AirportStatistic]?
    let aircraft: [AircraftStatistic]?
    let studentProgress: StudentProgressReport?
}