import Foundation

extension ReportDefinition {
    var syncID: UUID {
        syncMetadata?.syncID ?? UUID()
    }

    var filter: ReportFilter {
        get {
            guard let json = filterJSON,
                  let data = json.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(ReportFilter.self, from: data) else {
                return .allTime
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                filterJSON = json
            }
        }
    }

    var configuration: ReportConfiguration {
        get {
            guard let json = columnsJSON,
                  let data = json.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(ReportConfiguration.self, from: data) else {
                return .defaultFor(reportType)
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                columnsJSON = json
            }
        }
    }
}

extension ReportType {
    var displayName: String {
        switch self {
        case .faa8710: "FAA 8710 Totals"
        case .totalTimeSummary: "Total Time Summary"
        case .flightLog: "Flight Log Export"
        case .currencySummary: "Currency Summary"
        case .studentProgress: "Student Progress"
        case .airportStatistics: "Airport Statistics"
        case .aircraftStatistics: "Aircraft Statistics"
        case .custom: "Custom Report"
        }
    }

    var systemImage: String {
        switch self {
        case .faa8710: "doc.text.fill"
        case .totalTimeSummary: "clock.fill"
        case .flightLog: "book.closed.fill"
        case .currencySummary: "checkmark.shield.fill"
        case .studentProgress: "person.2.fill"
        case .airportStatistics: "mappin.and.ellipse"
        case .aircraftStatistics: "airplane.circle.fill"
        case .custom: "doc.badge.gearshape"
        }
    }

    var detailDescription: String {
        switch self {
        case .faa8710:
            "Category-specific flight times formatted for FAA Form 8710 applications."
        case .totalTimeSummary:
            "Complete breakdown of logged flight time, landings, and approaches."
        case .flightLog:
            "Detailed row-by-row export of every flight matching your filters."
        case .currencySummary:
            "Currency status report — generate from the Currency tab."
        case .studentProgress:
            "CFI summary of dual instruction and ground training per student."
        case .airportStatistics:
            "Visit counts and time spent at each airport."
        case .aircraftStatistics:
            "Flight time and usage breakdown by aircraft."
        case .custom:
            "Combined analytics package with totals, log, and statistics."
        }
    }

    var defaultFormat: ReportOutputFormat {
        switch self {
        case .flightLog, .airportStatistics, .aircraftStatistics, .studentProgress: .csv
        case .faa8710, .totalTimeSummary, .currencySummary: .pdf
        case .custom: .pdf
        }
    }

    var supportsSavedDefinition: Bool {
        self != .currencySummary
    }

    var supportsColumnCustomization: Bool {
        switch self {
        case .flightLog, .custom, .faa8710: true
        default: false
        }
    }
}

extension ReportOutputFormat {
    var displayName: String {
        switch self {
        case .pdf: "PDF"
        case .csv: "CSV"
        case .json: "JSON"
        }
    }
}