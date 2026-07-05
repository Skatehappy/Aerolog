import Foundation

// MARK: - Dashboard

struct AnalyticsDashboard: Sendable, Codable {
    let calculatedAt: Date
    let filter: ReportFilter
    let pilotName: String
    let totalFlights: Int
    let totalTime: Double
    let picTime: Double
    let dualReceived: Double
    let dualGiven: Double
    let soloTime: Double
    let crossCountryTime: Double
    let nightTime: Double
    let actualInstrumentTime: Double
    let simulatedInstrumentTime: Double
    let dayLandings: Int
    let nightLandings: Int
    let monthlyBuckets: [MonthlyTimeBucket]
    let topAirports: [AirportStatistic]
    let topAircraft: [AircraftStatistic]
}

struct MonthlyTimeBucket: Identifiable, Sendable, Codable {
    var id: String { "\(year)-\(month)" }
    let year: Int
    let month: Int
    let flightCount: Int
    let totalTime: Double

    var label: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return id }
        return formatter.string(from: date)
    }
}

// MARK: - Totals

struct TotalTimeSummary: Sendable, Codable {
    let pilotName: String
    let generatedAt: Date
    let filterSummary: String
    let totalFlights: Int
    let totalTime: Double
    let picTime: Double
    let sicTime: Double
    let dualReceived: Double
    let dualGiven: Double
    let soloTime: Double
    let crossCountryTime: Double
    let nightTime: Double
    let actualInstrumentTime: Double
    let simulatedInstrumentTime: Double
    let groundInstructionTime: Double
    let simulatorTime: Double
    let dayLandings: Int
    let nightLandings: Int
    let fullStopDayLandings: Int
    let fullStopNightLandings: Int
    let holds: Int
    let approachCount: Int
}

// MARK: - FAA 8710

struct FAA8710Totals: Sendable, Codable {
    let pilotName: String
    let certificateNumber: String?
    let addressLine: String?
    let generatedAt: Date
    let totalTime: Double
    let picTime: Double
    let sicTime: Double
    let dualReceived: Double
    let soloTime: Double
    let crossCountryTime: Double
    let nightTime: Double
    let actualInstrumentTime: Double
    let simulatedInstrumentTime: Double
    let dayLandings: Int
    let nightLandings: Int
    let airplaneSingleEngineLand: Double
    let airplaneMultiEngineLand: Double
    let rotorcraftHelicopter: Double
    let simulatorTime: Double
    let instructorTime: Double
}

// MARK: - Flight Log

struct FlightLogRow: Identifiable, Sendable, Codable {
    let id: UUID
    let date: Date
    let aircraft: String
    let route: String
    let totalTime: Double
    let picTime: Double
    let dualReceived: Double
    let soloTime: Double
    let nightTime: Double
    let crossCountryTime: Double
    let dayLandings: Int
    let nightLandings: Int
    let remarks: String?
}

// MARK: - Statistics

struct AirportStatistic: Identifiable, Sendable, Codable {
    var id: String { icao }
    let icao: String
    let departures: Int
    let arrivals: Int
    let totalTime: Double

    var visitCount: Int { departures + arrivals }
}

struct AircraftStatistic: Identifiable, Sendable, Codable {
    var id: UUID
    let registration: String
    let makeModel: String
    let flightCount: Int
    let totalTime: Double
}

// MARK: - Student Progress

struct StudentProgressReport: Sendable, Codable {
    let instructorName: String
    let generatedAt: Date
    let students: [StudentProgressEntry]
}

struct StudentProgressEntry: Identifiable, Sendable, Codable {
    var id: String { studentName }
    let studentName: String
    let dualGivenTime: Double
    let groundInstructionTime: Double
    let flightCount: Int
    let lastLessonDate: Date?
    let lastLessonTitle: String?
}

// MARK: - Generated Report Wrapper

struct GeneratedReport: Sendable {
    let type: ReportType
    let title: String
    let filter: ReportFilter
    let format: ReportOutputFormat
    let generatedAt: Date
    let dashboard: AnalyticsDashboard?
    let totalTime: TotalTimeSummary?
    let faa8710: FAA8710Totals?
    let flightLog: [FlightLogRow]?
    let airports: [AirportStatistic]?
    let aircraft: [AircraftStatistic]?
    let studentProgress: StudentProgressReport?
    let currencyResults: [CurrencyCalculationResult]?
}