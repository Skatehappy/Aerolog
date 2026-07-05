import Foundation

/// Rule-based natural language parser for logbook search queries.
enum NaturalLanguageSearchEngine {
    static func parse(_ query: String, referenceDate: Date = .now) -> FlightSearchCriteria {
        var criteria = FlightSearchCriteria()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return criteria }

        var remaining = normalized

        if remaining.contains("pinned") || remaining.contains("pin ") {
            criteria.pinnedOnly = true
            remaining = remaining
                .replacingOccurrences(of: "pinned", with: " ")
                .replacingOccurrences(of: "pin ", with: " ")
        }

        if remaining.contains("favorite") || remaining.contains("starred") {
            criteria.favoritesOnly = true
            remaining = remaining
                .replacingOccurrences(of: "favorites", with: " ")
                .replacingOccurrences(of: "favorite", with: " ")
                .replacingOccurrences(of: "starred", with: " ")
        }

        if remaining.contains("draft") {
            criteria.status = .draft
            remaining = remaining.replacingOccurrences(of: "drafts", with: " ").replacingOccurrences(of: "draft", with: " ")
        } else if remaining.contains("finalized") {
            criteria.status = .finalized
            remaining = remaining.replacingOccurrences(of: "finalized", with: " ")
        }

        if remaining.contains("cross country") || remaining.contains("xc") {
            criteria.requiresCrossCountry = true
            remaining = remaining
                .replacingOccurrences(of: "cross country", with: " ")
                .replacingOccurrences(of: "cross-country", with: " ")
                .replacingOccurrences(of: " xc ", with: " ")
        }

        if remaining.contains("night") {
            criteria.requiresNightCondition = true
            criteria.minimumNightTime = 0.1
            remaining = remaining.replacingOccurrences(of: "night", with: " ")
        }

        if let range = parseDateRange(from: remaining, referenceDate: referenceDate) {
            criteria.dateRange = range
            remaining = stripDatePhrases(from: remaining)
        }

        if let hours = parseMinimumHours(from: remaining) {
            criteria.minimumTotalTime = hours
            remaining = stripHourPhrases(from: remaining)
        }

        for role in FlightRole.allCases {
            let label = role.displayName.lowercased()
            if remaining.contains(label) || remaining.contains(role.rawValue.lowercased()) {
                criteria.role = role
                remaining = remaining.replacingOccurrences(of: label, with: " ")
                break
            }
        }

        let icaoPattern = #"\b[kK][a-zA-Z0-9]{3}\b"#
        if let regex = try? NSRegularExpression(pattern: icaoPattern) {
            let nsRange = NSRange(remaining.startIndex..<remaining.endIndex, in: remaining)
            let matches = regex.matches(in: remaining, range: nsRange)
            let codes = matches.compactMap { match -> String? in
                guard let range = Range(match.range, in: remaining) else { return nil }
                return String(remaining[range]).uppercased()
            }
            if let first = codes.first {
                if remaining.contains("to \(first.lowercased())") || remaining.contains("into \(first.lowercased())") {
                    criteria.arrivalICAO = first
                } else if remaining.contains("from \(first.lowercased())") {
                    criteria.departureICAO = first
                } else {
                    criteria.arrivalICAO = first
                }
            }
            for code in codes {
                remaining = remaining.replacingOccurrences(of: code.lowercased(), with: " ")
            }
        }

        let tailPattern = #"\bn[0-9a-z]{1,5}\b"#
        if let regex = try? NSRegularExpression(pattern: tailPattern) {
            let nsRange = NSRange(remaining.startIndex..<remaining.endIndex, in: remaining)
            if let match = regex.firstMatch(in: remaining, range: nsRange),
               let range = Range(match.range, in: remaining) {
                criteria.aircraftRegistration = String(remaining[range]).uppercased()
                remaining = remaining.replacingOccurrences(of: String(remaining[range]), with: " ")
            }
        }

        let tokens = remaining
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 2 }
        criteria.textTokens = tokens

        return criteria
    }

    static func matches(_ flight: Flight, criteria: FlightSearchCriteria) -> Bool {
        if criteria.pinnedOnly && !flight.isPinned { return false }
        if criteria.favoritesOnly && !flight.isFavorite { return false }
        if let status = criteria.status, flight.status != status { return false }
        if let role = criteria.role, flight.role != role { return false }
        if let dep = criteria.departureICAO,
           !flight.departureICAO.uppercased().contains(dep) { return false }
        if let arr = criteria.arrivalICAO,
           !flight.arrivalICAO.uppercased().contains(arr) { return false }
        if let reg = criteria.aircraftRegistration {
            let aircraftReg = flight.aircraft?.registration.uppercased() ?? ""
            if !aircraftReg.contains(reg) { return false }
        }
        if let min = criteria.minimumTotalTime, flight.totalTime < min { return false }
        if let max = criteria.maximumTotalTime, flight.totalTime > max { return false }
        if let minNight = criteria.minimumNightTime, flight.nightTime < minNight { return false }
        if criteria.requiresNightCondition, !flight.conditions.contains(.night), flight.nightTime <= 0 { return false }
        if criteria.requiresCrossCountry, !flight.conditions.contains(.crossCountry), flight.crossCountryTime <= 0 {
            return false
        }
        if let range = criteria.dateRange, !range.contains(flight.flightDate) { return false }

        guard !criteria.textTokens.isEmpty else { return true }

        let haystack = [
            flight.departureICAO,
            flight.arrivalICAO,
            flight.route ?? "",
            flight.aircraft?.registration ?? "",
            flight.aircraft?.make ?? "",
            flight.aircraft?.model ?? "",
            flight.remarks ?? "",
            flight.instructorName ?? ""
        ].joined(separator: " ").lowercased()

        return criteria.textTokens.allSatisfy { haystack.contains($0) }
    }

    // MARK: - Parsing Helpers

    private static func parseDateRange(from text: String, referenceDate: Date) -> ClosedRange<Date>? {
        let calendar = Calendar.current
        if text.contains("last month") {
            guard let start = calendar.date(byAdding: .month, value: -1, to: referenceDate),
                  let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: start)),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
                return nil
            }
            return monthStart...monthEnd
        }
        if text.contains("last week") {
            guard let start = calendar.date(byAdding: .day, value: -7, to: referenceDate) else { return nil }
            return start...referenceDate
        }
        if text.contains("this year") || text.contains("ytd") {
            let year = calendar.component(.year, from: referenceDate)
            guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
            return start...referenceDate
        }
        if text.contains("this month") {
            guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) else {
                return nil
            }
            return start...referenceDate
        }
        return nil
    }

    private static func stripDatePhrases(from text: String) -> String {
        text
            .replacingOccurrences(of: "last month", with: " ")
            .replacingOccurrences(of: "last week", with: " ")
            .replacingOccurrences(of: "this year", with: " ")
            .replacingOccurrences(of: "this month", with: " ")
            .replacingOccurrences(of: "ytd", with: " ")
    }

    private static func parseMinimumHours(from text: String) -> Double? {
        let patterns = [
            #"over\s+(\d+(?:\.\d+)?)\s*hours?"#,
            #"more than\s+(\d+(?:\.\d+)?)\s*hours?"#,
            #"at least\s+(\d+(?:\.\d+)?)\s*hours?"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text),
                  let value = Double(text[range]) else { continue }
            return value
        }
        return nil
    }

    private static func stripHourPhrases(from text: String) -> String {
        let patterns = [
            #"over\s+\d+(?:\.\d+)?\s*hours?"#,
            #"more than\s+\d+(?:\.\d+)?\s*hours?"#,
            #"at least\s+\d+(?:\.\d+)?\s*hours?"#
        ]
        var result = text
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        return result
    }
}