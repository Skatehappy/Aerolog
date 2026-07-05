import Foundation
import UIKit

/// Exports generated reports to CSV, JSON, and PDF.
struct ReportExporter: Sendable {
    func export(_ report: GeneratedReport) throws -> Data {
        switch report.format {
        case .csv: return try exportCSV(report)
        case .json: return try exportJSON(report)
        case .pdf: return try exportPDF(report)
        }
    }

    func suggestedFileName(for report: GeneratedReport) -> String {
        let slug = report.title.replacingOccurrences(of: " ", with: "_")
        let date = report.generatedAt.formatted(.iso8601.year().month().day())
        let ext = report.format.rawValue
        return "AeroLog_\(slug)_\(date).\(ext)"
    }

    // MARK: - CSV

    private func exportCSV(_ report: GeneratedReport) throws -> Data {
        var lines: [String] = []
        lines.append("Report,\(csvEscape(report.title))")
        lines.append("Generated,\(report.generatedAt.formatted())")
        lines.append("Filter,\(csvEscape(report.filter.displaySummary))")
        lines.append("")

        switch report.type {
        case .flightLog:
            lines.append("Date,Aircraft,Route,Total,PIC,Dual,Solo,Night,XC,Day Ldg,Night Ldg,Remarks")
            for row in report.flightLog ?? [] {
                lines.append([
                    row.date.formatted(date: .abbreviated, time: .omitted),
                    csvEscape(row.aircraft),
                    csvEscape(row.route),
                    TimeFormatting.display(row.totalTime),
                    TimeFormatting.display(row.picTime),
                    TimeFormatting.display(row.dualReceived),
                    TimeFormatting.display(row.soloTime),
                    TimeFormatting.display(row.nightTime),
                    TimeFormatting.display(row.crossCountryTime),
                    "\(row.dayLandings)",
                    "\(row.nightLandings)",
                    csvEscape(row.remarks ?? "")
                ].joined(separator: ","))
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
        default:
            if let totals = report.totalTime {
                lines.append("Category,Hours")
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

    // MARK: - PDF

    private func exportPDF(_ report: GeneratedReport) throws -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let lines = pdfLines(for: report)

        return renderer.pdfData { context in
            context.beginPage()
            let margin: CGFloat = 48
            var y = margin
            let lineHeight: CGFloat = 18
            let maxY = pageRect.height - margin

            for line in lines {
                if y + lineHeight > maxY {
                    context.beginPage()
                    y = margin
                }
                let attrs: [NSAttributedString.Key: Any] = line.isHeading
                    ? [.font: UIFont.boldSystemFont(ofSize: line.fontSize)]
                    : [.font: UIFont.systemFont(ofSize: line.fontSize)]
                line.text.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
                y += lineHeight + (line.isHeading ? 6 : 2)
            }
        }
    }

    private func pdfLines(for report: GeneratedReport) -> [PDFLine] {
        var lines: [PDFLine] = [
            PDFLine(text: report.title, isHeading: true, fontSize: 20),
            PDFLine(text: "Generated \(report.generatedAt.formatted(date: .abbreviated, time: .shortened))"),
            PDFLine(text: report.filter.displaySummary),
            PDFLine(text: "")
        ]

        if let totals = report.totalTime ?? report.faa8710.map { faa in
            TotalTimeSummary(
                pilotName: faa.pilotName, generatedAt: faa.generatedAt, filterSummary: report.filter.displaySummary,
                totalFlights: 0, totalTime: faa.totalTime, picTime: faa.picTime, sicTime: faa.sicTime,
                dualReceived: faa.dualReceived, dualGiven: 0, soloTime: faa.soloTime,
                crossCountryTime: faa.crossCountryTime, nightTime: faa.nightTime,
                actualInstrumentTime: faa.actualInstrumentTime, simulatedInstrumentTime: faa.simulatedInstrumentTime,
                groundInstructionTime: 0, simulatorTime: faa.simulatorTime,
                dayLandings: faa.dayLandings, nightLandings: faa.nightLandings,
                fullStopDayLandings: 0, fullStopNightLandings: 0, holds: 0, approachCount: 0
            )
        } {
            lines.append(PDFLine(text: "Time Summary", isHeading: true, fontSize: 16))
            lines.append(PDFLine(text: "Total: \(TimeFormatting.display(totals.totalTime)) hrs"))
            lines.append(PDFLine(text: "PIC: \(TimeFormatting.display(totals.picTime)) · Solo: \(TimeFormatting.display(totals.soloTime))"))
            lines.append(PDFLine(text: "Dual Received: \(TimeFormatting.display(totals.dualReceived)) · Night: \(TimeFormatting.display(totals.nightTime))"))
            lines.append(PDFLine(text: "Cross Country: \(TimeFormatting.display(totals.crossCountryTime)) · Instrument: \(TimeFormatting.display(totals.actualInstrumentTime))"))
            lines.append(PDFLine(text: "Landings: \(totals.dayLandings) day / \(totals.nightLandings) night"))
            lines.append(PDFLine(text: ""))
        }

        if let faa = report.faa8710 {
            lines.append(PDFLine(text: "FAA 8710 Category Breakdown", isHeading: true, fontSize: 16))
            lines.append(PDFLine(text: "Airplane SEL: \(TimeFormatting.display(faa.airplaneSingleEngineLand))"))
            lines.append(PDFLine(text: "Airplane MEL: \(TimeFormatting.display(faa.airplaneMultiEngineLand))"))
            lines.append(PDFLine(text: "Rotorcraft: \(TimeFormatting.display(faa.rotorcraftHelicopter))"))
            lines.append(PDFLine(text: "Instructor: \(TimeFormatting.display(faa.instructorTime))"))
            lines.append(PDFLine(text: ""))
        }

        if let rows = report.flightLog?.prefix(25) {
            lines.append(PDFLine(text: "Flight Log", isHeading: true, fontSize: 16))
            for row in rows {
                lines.append(PDFLine(text: "\(row.date.formatted(date: .abbreviated, time: .omitted))  \(row.route)  \(TimeFormatting.display(row.totalTime)) hrs"))
            }
        }

        if let airports = report.airports?.prefix(15) {
            lines.append(PDFLine(text: "Airport Statistics", isHeading: true, fontSize: 16))
            for stat in airports {
                lines.append(PDFLine(text: "\(stat.icao): \(stat.visitCount) visits, \(TimeFormatting.display(stat.totalTime)) hrs"))
            }
        }

        if let aircraft = report.aircraft?.prefix(15) {
            lines.append(PDFLine(text: "Aircraft Statistics", isHeading: true, fontSize: 16))
            for stat in aircraft {
                lines.append(PDFLine(text: "\(stat.registration): \(stat.flightCount) flights, \(TimeFormatting.display(stat.totalTime)) hrs"))
            }
        }

        return lines
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

private struct PDFLine {
    let text: String
    var isHeading: Bool = false
    var fontSize: CGFloat = 12
}

private struct JSONReportWrapper: Codable {
    let type: String
    let title: String
    let generatedAt: Date
    let filterSummary: String
    let dashboard: AnalyticsDashboard?
    let totalTime: TotalTimeSummary?
    let faa8710: FAA8710Totals?
    let flightLog: [FlightLogRow]?
    let airports: [AirportStatistic]?
    let aircraft: [AircraftStatistic]?
    let studentProgress: StudentProgressReport?
}