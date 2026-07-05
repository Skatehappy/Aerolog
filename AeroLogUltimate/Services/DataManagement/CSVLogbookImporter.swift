import Foundation

/// Parses CSV exports from AeroLog, LogTen, ForeFlight, MyFlightbook, and generic spreadsheets.
struct CSVLogbookImporter: Sendable {
    func parse(_ data: Data) throws -> [CSVFlightImportRow] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw DataManagementError.unsupportedFormat
        }

        let rows = parseCSVRows(text)
        guard rows.count >= 2 else { throw DataManagementError.emptyImport }

        let headers = rows[0].map(normalizeHeader)
        let columnMap = buildColumnMap(headers: headers)

        var results: [CSVFlightImportRow] = []
        for row in rows.dropFirst() {
            guard !row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) else { continue }
            if let parsed = parseRow(row, columnMap: columnMap, headers: headers) {
                results.append(parsed)
            }
        }

        guard !results.isEmpty else { throw DataManagementError.emptyImport }
        return results
    }

    func detectSource(headers: [String]) -> String {
        let normalized = Set(headers.map(normalizeHeader))
        if normalized.contains("aircraftid") || normalized.contains("from") && normalized.contains("to") {
            return "LogTen-compatible"
        }
        if normalized.contains("departure") && normalized.contains("arrival") && normalized.contains("totaltime") {
            return "ForeFlight-compatible"
        }
        if normalized.contains("flightdate") {
            return "MyFlightbook-compatible"
        }
        return "Generic CSV"
    }

    // MARK: - Parsing

    private func parseRow(
        _ values: [String],
        columnMap: [CSVColumn: Int],
        headers: [String]
    ) -> CSVFlightImportRow? {
        func value(_ column: CSVColumn) -> String? {
            guard let index = columnMap[column], index < values.count else { return nil }
            let trimmed = values[index].trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        var row = CSVFlightImportRow()
        row.flightDate = parseDate(value(.date))
        row.aircraftRegistration = value(.aircraft)
        row.departureICAO = value(.departure)?.uppercased()
        row.arrivalICAO = value(.arrival)?.uppercased()
        row.route = value(.route)
        row.role = value(.role).flatMap { FlightRole(rawValue: $0.lowercased()) ?? parseRoleLabel($0) }
        row.totalTime = value(.totalTime).flatMap(TimeFormatting.parse)
        row.picTime = value(.picTime).flatMap(TimeFormatting.parse)
        row.sicTime = value(.sicTime).flatMap(TimeFormatting.parse)
        row.dualReceived = value(.dualReceived).flatMap(TimeFormatting.parse)
        row.dualGiven = value(.dualGiven).flatMap(TimeFormatting.parse)
        row.soloTime = value(.soloTime).flatMap(TimeFormatting.parse)
        row.crossCountryTime = value(.crossCountryTime).flatMap(TimeFormatting.parse)
        row.nightTime = value(.nightTime).flatMap(TimeFormatting.parse)
        row.actualInstrumentTime = value(.actualInstrumentTime).flatMap(TimeFormatting.parse)
        row.simulatedInstrumentTime = value(.simulatedInstrumentTime).flatMap(TimeFormatting.parse)
        row.groundInstructionTime = value(.groundInstructionTime).flatMap(TimeFormatting.parse)
        row.simulatorTime = value(.simulatorTime).flatMap(TimeFormatting.parse)
        row.dayLandings = value(.dayLandings).flatMap(Int.init)
        row.nightLandings = value(.nightLandings).flatMap(Int.init)
        row.instructorName = value(.instructorName)
        row.remarks = value(.remarks)
        row.externalID = value(.externalID)

        let hasTime = (row.totalTime ?? 0) > 0
            || (row.picTime ?? 0) > 0
            || (row.dualReceived ?? 0) > 0
        let hasRoute = row.departureICAO != nil || row.arrivalICAO != nil
        guard row.flightDate != nil || hasTime || hasRoute else { return nil }

        if row.flightDate == nil {
            row.flightDate = .now
        }
        if row.totalTime == nil {
            row.totalTime = row.picTime ?? row.dualReceived ?? row.soloTime ?? 0
            row.totalTimeWasInferred = true
        }

        _ = headers
        return row
    }

    private func buildColumnMap(headers: [String]) -> [CSVColumn: Int] {
        var map: [CSVColumn: Int] = [:]
        for (index, header) in headers.enumerated() {
            if let column = CSVColumn.match(header) {
                map[column] = index
            }
        }
        return map
    }

    private func normalizeHeader(_ header: String) -> String {
        header
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "/", with: "")
    }

    private func parseRoleLabel(_ label: String) -> FlightRole? {
        let normalized = label.lowercased()
        if normalized.contains("pic") || normalized.contains("pilot in command") { return .pic }
        if normalized.contains("sic") { return .sic }
        if normalized.contains("dual received") || normalized == "student" { return .dualReceived }
        if normalized.contains("dual given") || normalized.contains("cfi") { return .dualGiven }
        if normalized.contains("solo") { return .solo }
        return nil
    }

    private func parseDate(_ text: String?) -> Date? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "dd-MMM-yyyy",
            "yyyy/MM/dd",
            "MM-dd-yyyy"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    private func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]

            if char == "\"" {
                let next = text.index(after: index)
                if insideQuotes, next < text.endIndex, text[next] == "\"" {
                    currentField.append("\"")
                    index = next
                } else {
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if (char == "\n" || char == "\r") && !insideQuotes {
                if char == "\r", text.index(after: index) < text.endIndex, text[text.index(after: index)] == "\n" {
                    index = text.index(after: index)
                }
                currentRow.append(currentField)
                if !currentRow.allSatisfy({ $0.isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow = []
                currentField = ""
            } else {
                currentField.append(char)
            }

            index = text.index(after: index)
        }

        currentRow.append(currentField)
        if !currentRow.allSatisfy({ $0.isEmpty }) {
            rows.append(currentRow)
        }
        return rows
    }
}

// MARK: - Column Mapping

private enum CSVColumn: CaseIterable {
    case date
    case aircraft
    case departure
    case arrival
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
    case instructorName
    case remarks
    case externalID

    static func match(_ normalizedHeader: String) -> CSVColumn? {
        aliases.first { $0.value.contains(normalizedHeader) }?.key
    }

    private static let aliases: [CSVColumn: Set<String>] = [
        .date: ["date", "flightdate", "flightdateutc"],
        .aircraft: ["aircraft", "aircraftid", "aircraftident", "tailnumber", "ident", "aircrafttype"],
        .departure: ["from", "departure", "dep", "depicao", "departureicao"],
        .arrival: ["to", "arrival", "arr", "arricao", "arrivalicao", "destination"],
        .route: ["route", "routestring"],
        .role: ["role", "flightrole", "pilotrole", "duty"],
        .totalTime: ["totaltime", "totalduration", "duration", "total", "flighttime"],
        .picTime: ["pic", "pictime", "pilotintime", "picus"],
        .sicTime: ["sic", "sictime"],
        .dualReceived: ["dualreceived", "dual", "instructionreceived", "studenttime"],
        .dualGiven: ["dualgiven", "instructiongiven", "cfi", "asflightinstructor"],
        .soloTime: ["solo", "solotime"],
        .crossCountryTime: ["crosscountry", "crosscountrytime", "xc"],
        .nightTime: ["night", "nighttime"],
        .actualInstrumentTime: ["actualinstrument", "actualinstrumenttime", "imc"],
        .simulatedInstrumentTime: ["simulatedinstrument", "simulatedinstrumenttime", "hood"],
        .groundInstructionTime: ["ground", "groundinstruction", "groundinstructiontime"],
        .simulatorTime: ["simulator", "simulatortime", "ftd"],
        .dayLandings: ["daylandings", "landingsday", "day"],
        .nightLandings: ["nightlandings", "landingsnight", "nightldg"],
        .instructorName: ["instructor", "instructorname", "cfi"],
        .remarks: ["remarks", "comments", "notes", "remark"],
        .externalID: ["externalid", "flightid", "id", "uuid"]
    ]
}