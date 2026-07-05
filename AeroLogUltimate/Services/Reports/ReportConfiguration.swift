import Foundation

/// Selectable columns for flight log and custom report exports.
enum ReportColumn: String, Codable, CaseIterable, Sendable, Identifiable {
    case date
    case aircraft
    case route
    case role
    case totalTime
    case picTime
    case sicTime
    case dualReceived
    case dualGiven
    case soloTime
    case crossCountryTime
    case nightTime
    case actualInstrumentTime
    case simulatedInstrumentTime
    case groundInstructionTime
    case simulatorTime
    case dayLandings
    case nightLandings
    case fullStopDayLandings
    case fullStopNightLandings
    case holds
    case approachCount
    case instructorName
    case remarks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .date: "Date"
        case .aircraft: "Aircraft"
        case .route: "Route"
        case .role: "Role"
        case .totalTime: "Total"
        case .picTime: "PIC"
        case .sicTime: "SIC"
        case .dualReceived: "Dual Rcvd"
        case .dualGiven: "Dual Given"
        case .soloTime: "Solo"
        case .crossCountryTime: "XC"
        case .nightTime: "Night"
        case .actualInstrumentTime: "Act. Inst"
        case .simulatedInstrumentTime: "Sim. Inst"
        case .groundInstructionTime: "Ground"
        case .simulatorTime: "Simulator"
        case .dayLandings: "Day Ldg"
        case .nightLandings: "Night Ldg"
        case .fullStopDayLandings: "FS Day"
        case .fullStopNightLandings: "FS Night"
        case .holds: "Holds"
        case .approachCount: "Apprs"
        case .instructorName: "Instructor"
        case .remarks: "Remarks"
        }
    }

    var csvHeader: String {
        switch self {
        case .date: "Date"
        case .aircraft: "Aircraft"
        case .route: "Route"
        case .role: "Role"
        case .totalTime: "Total Time"
        case .picTime: "PIC"
        case .sicTime: "SIC"
        case .dualReceived: "Dual Received"
        case .dualGiven: "Dual Given"
        case .soloTime: "Solo"
        case .crossCountryTime: "Cross Country"
        case .nightTime: "Night"
        case .actualInstrumentTime: "Actual Instrument"
        case .simulatedInstrumentTime: "Simulated Instrument"
        case .groundInstructionTime: "Ground Instruction"
        case .simulatorTime: "Simulator"
        case .dayLandings: "Day Landings"
        case .nightLandings: "Night Landings"
        case .fullStopDayLandings: "Full Stop Day"
        case .fullStopNightLandings: "Full Stop Night"
        case .holds: "Holds"
        case .approachCount: "Approaches"
        case .instructorName: "Instructor"
        case .remarks: "Remarks"
        }
    }

    /// Relative width weight for PDF table layout.
    var widthWeight: CGFloat {
        switch self {
        case .date: 1.1
        case .aircraft: 1.2
        case .route: 1.6
        case .role: 0.9
        case .remarks: 2.0
        case .instructorName: 1.3
        case .dayLandings, .nightLandings, .fullStopDayLandings, .fullStopNightLandings, .holds, .approachCount:
            0.7
        default: 0.8
        }
    }

    func value(from row: FlightLogRow) -> String {
        switch self {
        case .date:
            return row.date.formatted(date: .abbreviated, time: .omitted)
        case .aircraft: return row.aircraft
        case .route: return row.route
        case .role: return row.role?.displayName ?? ""
        case .totalTime: return TimeFormatting.display(row.totalTime)
        case .picTime: return TimeFormatting.display(row.picTime)
        case .sicTime: return TimeFormatting.display(row.sicTime)
        case .dualReceived: return TimeFormatting.display(row.dualReceived)
        case .dualGiven: return TimeFormatting.display(row.dualGiven)
        case .soloTime: return TimeFormatting.display(row.soloTime)
        case .crossCountryTime: return TimeFormatting.display(row.crossCountryTime)
        case .nightTime: return TimeFormatting.display(row.nightTime)
        case .actualInstrumentTime: return TimeFormatting.display(row.actualInstrumentTime)
        case .simulatedInstrumentTime: return TimeFormatting.display(row.simulatedInstrumentTime)
        case .groundInstructionTime: return TimeFormatting.display(row.groundInstructionTime)
        case .simulatorTime: return TimeFormatting.display(row.simulatorTime)
        case .dayLandings: return "\(row.dayLandings)"
        case .nightLandings: return "\(row.nightLandings)"
        case .fullStopDayLandings: return "\(row.fullStopDayLandings)"
        case .fullStopNightLandings: return "\(row.fullStopNightLandings)"
        case .holds: return "\(row.holds)"
        case .approachCount: return "\(row.approachCount)"
        case .instructorName: return row.instructorName ?? ""
        case .remarks: return row.remarks ?? ""
        }
    }
}

/// Column and layout preferences for customizable reports.
struct ReportConfiguration: Codable, Sendable, Equatable {
    var columns: [ReportColumn]

    static let faaLogbook: ReportConfiguration = ReportConfiguration(columns: [
        .date, .aircraft, .route, .totalTime, .picTime, .sicTime,
        .dualReceived, .soloTime, .nightTime, .crossCountryTime,
        .actualInstrumentTime, .simulatedInstrumentTime,
        .dayLandings, .nightLandings, .remarks
    ])

    static let fullLogbook: ReportConfiguration = ReportConfiguration(columns: ReportColumn.allCases)

    static func defaultFor(_ type: ReportType) -> ReportConfiguration {
        switch type {
        case .flightLog, .custom:
            return .faaLogbook
        default:
            return ReportConfiguration(columns: [])
        }
    }

    func resolvedColumns(for type: ReportType) -> [ReportColumn] {
        if columns.isEmpty {
            return Self.defaultFor(type).columns
        }
        return columns
    }
}