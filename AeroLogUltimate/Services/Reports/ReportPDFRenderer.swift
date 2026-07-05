import Foundation
import UIKit

/// Renders presentation-ready PDF reports for checkrides, insurance, and audits.
struct ReportPDFRenderer: Sendable {
    private let margin: CGFloat = 48
    private let headerBandHeight: CGFloat = 72
    private let footerHeight: CGFloat = 32
    private let brandColor = UIColor(red: 0.09, green: 0.18, blue: 0.42, alpha: 1)
    private let accentFill = UIColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1)
    private let alternateRow = UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1)

    func render(_ report: GeneratedReport) -> Data {
        let landscape = report.type == .flightLog || (report.type == .custom && (report.flightLog?.isEmpty == false))
        let pageSize = landscape
            ? CGSize(width: 792, height: 612)
            : CGSize(width: 612, height: 792)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { context in
            var state = PDFPageState(
                context: context,
                pageSize: pageSize,
                margin: margin,
                headerBandHeight: headerBandHeight,
                footerHeight: footerHeight,
                report: report,
                brandColor: brandColor,
                pageNumber: 0
            )
            state.beginPage()
            renderBody(report: report, state: &state)
            state.drawFooter()
        }
    }

    // MARK: - Body

    private func renderBody(_ report: GeneratedReport, state: inout PDFPageState) {
        switch report.type {
        case .faa8710:
            if let faa = report.faa8710 { renderFAA8710(faa, report: report, state: &state) }
        case .totalTimeSummary:
            if let totals = report.totalTime { renderTotalTimeSummary(totals, state: &state) }
        case .flightLog:
            if let rows = report.flightLog {
                let columns = report.configuration.resolvedColumns(for: .flightLog)
                renderFlightLogTable(rows, columns: columns, state: &state)
            }
        case .airportStatistics:
            if let airports = report.airports { renderAirportStatistics(airports, state: &state) }
        case .aircraftStatistics:
            if let aircraft = report.aircraft { renderAircraftStatistics(aircraft, state: &state) }
        case .studentProgress:
            if let progress = report.studentProgress { renderStudentProgress(progress, state: &state) }
        case .custom:
            renderCustomReport(report, state: &state)
        case .currencySummary:
            state.drawSectionTitle("Currency Summary")
            state.drawParagraph("Generate currency summaries from the Currency tab in AeroLog Ultimate.")
        }
    }

    private func renderCustomReport(_ report: GeneratedReport, state: inout PDFPageState) {
        if let totals = report.totalTime {
            renderTotalTimeSummary(totals, state: &state)
        }
        if let dashboard = report.dashboard {
            renderTimeCategoryChart(dashboard, state: &state)
        }
        if let rows = report.flightLog, !rows.isEmpty {
            state.ensureSpace(40)
            let columns = report.configuration.resolvedColumns(for: .custom)
            renderFlightLogTable(rows, columns: columns, state: &state, title: "Flight Log Detail")
        }
        if let airports = report.airports, !airports.isEmpty {
            renderAirportStatistics(Array(airports.prefix(20)), state: &state, title: "Airport Usage")
        }
        if let aircraft = report.aircraft, !aircraft.isEmpty {
            renderAircraftStatistics(Array(aircraft.prefix(20)), state: &state, title: "Aircraft Usage")
        }
    }

    // MARK: - Sections

    private func renderTotalTimeSummary(_ totals: TotalTimeSummary, state: inout PDFPageState) {
        state.drawSectionTitle("Flight Time Summary")
        state.drawKeyValueGrid([
            ("Total Flights", "\(totals.totalFlights)"),
            ("Total Time", formatHours(totals.totalTime)),
            ("PIC", formatHours(totals.picTime)),
            ("SIC", formatHours(totals.sicTime)),
            ("Solo", formatHours(totals.soloTime)),
            ("Dual Received", formatHours(totals.dualReceived)),
            ("Dual Given", formatHours(totals.dualGiven)),
            ("Cross Country", formatHours(totals.crossCountryTime)),
            ("Night", formatHours(totals.nightTime)),
            ("Actual Instrument", formatHours(totals.actualInstrumentTime)),
            ("Simulated Instrument", formatHours(totals.simulatedInstrumentTime)),
            ("Ground Instruction", formatHours(totals.groundInstructionTime)),
            ("Simulator / FTD", formatHours(totals.simulatorTime)),
            ("Day Landings", "\(totals.dayLandings)"),
            ("Night Landings", "\(totals.nightLandings)"),
            ("Full Stop Day", "\(totals.fullStopDayLandings)"),
            ("Full Stop Night", "\(totals.fullStopNightLandings)"),
            ("Holds", "\(totals.holds)"),
            ("Approaches", "\(totals.approachCount)")
        ])
    }

    private func renderFAA8710(_ faa: FAA8710Totals, report: GeneratedReport, state: inout PDFPageState) {
        state.drawSectionTitle("FAA Form 8710 — Flight Experience Totals")
        state.drawParagraph(
            "The following totals are derived from finalized logbook entries and are formatted for FAA airman certificate applications, checkrides, and insurance verification."
        )

        if let address = faa.addressLine, !address.isEmpty {
            state.drawKeyValueGrid([("Address", address)])
        }

        state.drawSectionTitle("General Flight Experience")
        state.drawKeyValueGrid([
            ("Total Time", formatHours(faa.totalTime)),
            ("PIC", formatHours(faa.picTime)),
            ("SIC", formatHours(faa.sicTime)),
            ("Dual Received", formatHours(faa.dualReceived)),
            ("Solo", formatHours(faa.soloTime)),
            ("Cross Country", formatHours(faa.crossCountryTime)),
            ("Night", formatHours(faa.nightTime)),
            ("Actual Instrument", formatHours(faa.actualInstrumentTime)),
            ("Simulated Instrument", formatHours(faa.simulatedInstrumentTime)),
            ("Day Landings", "\(faa.dayLandings)"),
            ("Night Landings", "\(faa.nightLandings)")
        ])

        state.drawSectionTitle("Category & Class Breakdown")
        state.drawTable(
            headers: ["Category / Class", "Total Time (hrs)"],
            rows: [
                ["Airplane Single-Engine Land", formatHours(faa.airplaneSingleEngineLand)],
                ["Airplane Multi-Engine Land", formatHours(faa.airplaneMultiEngineLand)],
                ["Rotorcraft Helicopter", formatHours(faa.rotorcraftHelicopter)],
                ["Simulator / Training Device", formatHours(faa.simulatorTime)],
                ["Flight Instructor", formatHours(faa.instructorTime)]
            ],
            columnWeights: [2.5, 1.0],
            accentFill: accentFill,
            alternateRow: alternateRow
        )

        if let rows = report.flightLog, !rows.isEmpty {
            let columns = report.configuration.resolvedColumns(for: .faa8710)
            renderFlightLogTable(rows, columns: columns, state: &state, title: "Supporting Flight Log")
        }
    }

    private func renderTimeCategoryChart(_ dashboard: AnalyticsDashboard, state: inout PDFPageState) {
        state.drawSectionTitle("Time by Category")
        let items: [(String, Double)] = [
            ("PIC", dashboard.picTime),
            ("Solo", dashboard.soloTime),
            ("Dual Rcvd", dashboard.dualReceived),
            ("Dual Given", dashboard.dualGiven),
            ("Cross Country", dashboard.crossCountryTime),
            ("Night", dashboard.nightTime),
            ("Instrument", dashboard.actualInstrumentTime + dashboard.simulatedInstrumentTime)
        ].filter { $0.1 > 0 }

        guard !items.isEmpty else { return }
        let maxValue = items.map(\.1).max() ?? 1
        state.drawHorizontalBarChart(items: items, maxValue: maxValue, brandColor: brandColor)
    }

    private func renderFlightLogTable(
        _ rows: [FlightLogRow],
        columns: [ReportColumn],
        state: inout PDFPageState,
        title: String = "Flight Log"
    ) {
        let activeColumns = columns.isEmpty ? ReportConfiguration.faaLogbook.columns : columns
        state.drawSectionTitle("\(title) (\(rows.count) entries)")
        state.drawTable(
            headers: activeColumns.map(\.displayName),
            rows: rows.map { row in activeColumns.map { $0.value(from: row) } },
            columnWeights: activeColumns.map(\.widthWeight),
            accentFill: accentFill,
            alternateRow: alternateRow,
            fontSize: activeColumns.count > 12 ? 7 : 8
        )

        if !rows.isEmpty {
            state.ensureSpace(28)
            let totals = flightLogTotals(rows, columns: activeColumns)
            if !totals.isEmpty {
                state.drawSectionTitle("Column Totals")
                state.drawKeyValueGrid(totals, columns: min(4, totals.count))
            }
        }
    }

    private func renderAirportStatistics(
        _ airports: [AirportStatistic],
        state: inout PDFPageState,
        title: String = "Airport Statistics"
    ) {
        state.drawSectionTitle(title)
        state.drawTable(
            headers: ["ICAO", "Departures", "Arrivals", "Visits", "Total Time"],
            rows: airports.map {
                [$0.icao, "\($0.departures)", "\($0.arrivals)", "\($0.visitCount)", formatHours($0.totalTime)]
            },
            columnWeights: [1.0, 1.0, 1.0, 1.0, 1.2],
            accentFill: accentFill,
            alternateRow: alternateRow
        )
    }

    private func renderAircraftStatistics(
        _ aircraft: [AircraftStatistic],
        state: inout PDFPageState,
        title: String = "Aircraft Statistics"
    ) {
        state.drawSectionTitle(title)
        state.drawTable(
            headers: ["Registration", "Make / Model", "Flights", "Total Time"],
            rows: aircraft.map {
                [$0.registration, $0.makeModel, "\($0.flightCount)", formatHours($0.totalTime)]
            },
            columnWeights: [1.1, 2.0, 0.8, 1.0],
            accentFill: accentFill,
            alternateRow: alternateRow
        )
    }

    private func renderStudentProgress(_ progress: StudentProgressReport, state: inout PDFPageState) {
        state.drawSectionTitle("Student Progress — \(progress.instructorName)")
        state.drawTable(
            headers: ["Student", "Dual Given", "Ground", "Flights", "Last Lesson"],
            rows: progress.students.map {
                [
                    $0.studentName,
                    formatHours($0.dualGivenTime),
                    formatHours($0.groundInstructionTime),
                    "\($0.flightCount)",
                    $0.lastLessonDate?.formatted(date: .abbreviated, time: .omitted) ?? "—"
                ]
            },
            columnWeights: [1.8, 1.0, 1.0, 0.8, 1.2],
            accentFill: accentFill,
            alternateRow: alternateRow
        )
    }

    // MARK: - Helpers

    private func formatHours(_ hours: Double) -> String {
        TimeFormatting.display(hours)
    }

    private func flightLogTotals(_ rows: [FlightLogRow], columns: [ReportColumn]) -> [(String, String)] {
        var result: [(String, String)] = []
        for column in columns {
            switch column {
            case .totalTime:
                result.append(("Total Time", formatHours(rows.reduce(0) { $0 + $1.totalTime })))
            case .picTime:
                result.append(("PIC", formatHours(rows.reduce(0) { $0 + $1.picTime })))
            case .sicTime:
                result.append(("SIC", formatHours(rows.reduce(0) { $0 + $1.sicTime })))
            case .dualReceived:
                result.append(("Dual Received", formatHours(rows.reduce(0) { $0 + $1.dualReceived })))
            case .dualGiven:
                result.append(("Dual Given", formatHours(rows.reduce(0) { $0 + $1.dualGiven })))
            case .soloTime:
                result.append(("Solo", formatHours(rows.reduce(0) { $0 + $1.soloTime })))
            case .crossCountryTime:
                result.append(("Cross Country", formatHours(rows.reduce(0) { $0 + $1.crossCountryTime })))
            case .nightTime:
                result.append(("Night", formatHours(rows.reduce(0) { $0 + $1.nightTime })))
            case .actualInstrumentTime:
                result.append(("Actual Instrument", formatHours(rows.reduce(0) { $0 + $1.actualInstrumentTime })))
            case .simulatedInstrumentTime:
                result.append(("Simulated Instrument", formatHours(rows.reduce(0) { $0 + $1.simulatedInstrumentTime })))
            case .dayLandings:
                result.append(("Day Landings", "\(rows.reduce(0) { $0 + $1.dayLandings })"))
            case .nightLandings:
                result.append(("Night Landings", "\(rows.reduce(0) { $0 + $1.nightLandings })"))
            default:
                break
            }
        }
        return result
    }
}

// MARK: - Page State

private struct PDFPageState {
    let context: UIGraphicsPDFRendererContext
    let pageSize: CGSize
    let margin: CGFloat
    let headerBandHeight: CGFloat
    let footerHeight: CGFloat
    let report: GeneratedReport
    let brandColor: UIColor
    var pageNumber: Int
    var y: CGFloat = 0
    var contentTop: CGFloat = 0
    var contentBottom: CGFloat = 0

    mutating func beginPage() {
        context.beginPage()
        pageNumber += 1
        contentTop = margin + headerBandHeight + 16
        contentBottom = pageSize.height - margin - footerHeight
        y = contentTop
        drawHeader()
    }

    mutating func ensureSpace(_ height: CGFloat) {
        if y + height > contentBottom {
            drawFooter()
            beginPage()
        }
    }

    mutating func drawHeader() {
        let report = report
        let brandColor = brandColor
        let bandRect = CGRect(x: 0, y: 0, width: pageSize.width, height: headerBandHeight)
        brandColor.setFill()
        UIRectFill(bandRect)

        let pilotName = report.pilotDisplayName
        let certNumber = report.certificateNumber

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]

        report.title.draw(at: CGPoint(x: margin, y: 16), withAttributes: titleAttrs)
        pilotName.draw(at: CGPoint(x: margin, y: 40), withAttributes: subAttrs)

        var metaY: CGFloat = 54
        if let certNumber, !certNumber.isEmpty {
            "Certificate # \(certNumber)".draw(at: CGPoint(x: margin, y: metaY), withAttributes: metaAttrs)
            metaY += 12
        }

        let rightX = pageSize.width - margin
        let generated = "Generated \(report.generatedAt.formatted(date: .abbreviated, time: .shortened))"
        let generatedSize = generated.size(withAttributes: subAttrs)
        generated.draw(
            at: CGPoint(x: rightX - generatedSize.width, y: 16),
            withAttributes: subAttrs
        )

        let filter = report.filter.displaySummary
        let filterSize = filter.size(withAttributes: metaAttrs)
        filter.draw(
            at: CGPoint(x: rightX - filterSize.width, y: 34),
            withAttributes: metaAttrs
        )

        let brand = "AeroLog Ultimate"
        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.95)
        ]
        let brandSize = brand.size(withAttributes: brandAttrs)
        brand.draw(
            at: CGPoint(x: rightX - brandSize.width, y: headerBandHeight - 22),
            withAttributes: brandAttrs
        )

        y = contentTop
    }

    mutating func drawFooter() {
        let brandColor = brandColor
        let lineY = pageSize.height - margin - footerHeight + 4
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: lineY))
        path.addLine(to: CGPoint(x: pageSize.width - margin, y: lineY))
        brandColor.withAlphaComponent(0.25).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        let leftAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.darkGray
        ]
        let rightAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]

        let disclaimer = "Official pilot record — verify against original logbook entries"
        disclaimer.draw(at: CGPoint(x: margin, y: lineY + 8), withAttributes: leftAttrs)

        let pageLabel = "Page \(pageNumber)"
        let pageSize = pageLabel.size(withAttributes: rightAttrs)
        pageLabel.draw(
            at: CGPoint(x: self.pageSize.width - margin - pageSize.width, y: lineY + 8),
            withAttributes: rightAttrs
        )
    }

    mutating func drawSectionTitle(_ title: String) {
        ensureSpace(28)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor(red: 0.09, green: 0.18, blue: 0.42, alpha: 1)
        ]
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
        y += 18

        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
        UIColor(red: 0.09, green: 0.18, blue: 0.42, alpha: 0.2).setStroke()
        path.lineWidth = 1
        path.stroke()
        y += 10
    }

    mutating func drawParagraph(_ text: String) {
        ensureSpace(40)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.darkGray
        ]
        let rect = CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 200)
        let bounding = text.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        text.draw(in: CGRect(x: margin, y: y, width: rect.width, height: bounding.height), withAttributes: attrs)
        y += bounding.height + 12
    }

    mutating func drawKeyValueGrid(_ pairs: [(String, String)], columns: Int = 3) {
        guard !pairs.isEmpty else { return }
        let colCount = max(1, min(columns, pairs.count))
        let colWidth = (pageSize.width - margin * 2) / CGFloat(colCount)
        let rowHeight: CGFloat = 34
        let rows = Int(ceil(Double(pairs.count) / Double(colCount)))
        ensureSpace(CGFloat(rows) * rowHeight + 8)

        for (index, pair) in pairs.enumerated() {
            let col = index % colCount
            let row = index / colCount
            let x = margin + CGFloat(col) * colWidth
            let itemY = y + CGFloat(row) * rowHeight

            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.gray
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            pair.0.draw(at: CGPoint(x: x, y: itemY), withAttributes: labelAttrs)
            pair.1.draw(at: CGPoint(x: x, y: itemY + 12), withAttributes: valueAttrs)
        }
        y += CGFloat(rows) * rowHeight + 8
    }

    mutating func drawHorizontalBarChart(
        items: [(String, Double)],
        maxValue: Double,
        brandColor: UIColor
    ) {
        let rowHeight: CGFloat = 18
        ensureSpace(CGFloat(items.count) * rowHeight + 12)
        let labelWidth: CGFloat = 80
        let barMaxWidth = pageSize.width - margin * 2 - labelWidth - 50

        for (index, item) in items.enumerated() {
            let rowY = y + CGFloat(index) * rowHeight
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.darkGray
            ]
            item.0.draw(at: CGPoint(x: margin, y: rowY + 2), withAttributes: labelAttrs)

            let fraction = maxValue > 0 ? item.1 / maxValue : 0
            let barWidth = max(2, CGFloat(fraction) * barMaxWidth)
            let barRect = CGRect(x: margin + labelWidth, y: rowY + 3, width: barWidth, height: 10)
            brandColor.withAlphaComponent(0.7).setFill()
            UIBezierPath(roundedRect: barRect, cornerRadius: 2).fill()

            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 8, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            TimeFormatting.display(item.1).draw(
                at: CGPoint(x: margin + labelWidth + barWidth + 6, y: rowY + 2),
                withAttributes: valueAttrs
            )
        }
        y += CGFloat(items.count) * rowHeight + 12
    }

    mutating func drawTable(
        headers: [String],
        rows: [[String]],
        columnWeights: [CGFloat],
        accentFill: UIColor,
        alternateRow: UIColor,
        fontSize: CGFloat = 8
    ) {
        guard !headers.isEmpty else { return }

        let tableWidth = pageSize.width - margin * 2
        let totalWeight = columnWeights.reduce(0, +)
        let colWidths = columnWeights.map { tableWidth * ($0 / totalWeight) }
        let headerHeight: CGFloat = 22
        let rowHeight: CGFloat = fontSize > 7 ? 16 : 18

        func drawHeaderRow(at startY: CGFloat) {
            let headerRect = CGRect(x: margin, y: startY, width: tableWidth, height: headerHeight)
            accentFill.setFill()
            UIRectFill(headerRect)

            var x = margin
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor(red: 0.09, green: 0.18, blue: 0.42, alpha: 1)
            ]
            for (index, header) in headers.enumerated() {
                let cellRect = CGRect(x: x + 4, y: startY + 4, width: colWidths[index] - 8, height: headerHeight - 8)
                header.draw(in: cellRect, withAttributes: headerAttrs)
                x += colWidths[index]
            }
        }

        ensureSpace(headerHeight + 4)
        drawHeaderRow(at: y)
        y += headerHeight

        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.black
        ]

        for (rowIndex, row) in rows.enumerated() {
            if y + rowHeight > contentBottom {
                drawFooter()
                beginPage()
                drawHeaderRow(at: y)
                y += headerHeight
            }

            if rowIndex % 2 == 1 {
                let rowRect = CGRect(x: margin, y: y, width: tableWidth, height: rowHeight)
                alternateRow.setFill()
                UIRectFill(rowRect)
            }

            var x = margin
            for (colIndex, value) in row.enumerated() where colIndex < colWidths.count {
                let cellRect = CGRect(x: x + 4, y: y + 2, width: colWidths[colIndex] - 8, height: rowHeight - 4)
                value.draw(in: cellRect, withAttributes: cellAttrs)
                x += colWidths[colIndex]
            }
            y += rowHeight
        }
        y += 10
    }
}

// MARK: - GeneratedReport helpers

extension GeneratedReport {
    var pilotDisplayName: String {
        totalTime?.pilotName
            ?? faa8710?.pilotName
            ?? dashboard?.pilotName
            ?? studentProgress?.instructorName
            ?? "Pilot"
    }

    var certificateNumber: String? {
        faa8710?.certificateNumber
    }
}