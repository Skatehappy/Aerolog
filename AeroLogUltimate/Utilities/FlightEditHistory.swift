import Foundation

/// Append-only audit entry for changes to finalized logbook records.
struct FlightEditRecord: Codable, Sendable, Identifiable {
    var id: UUID
    var timestamp: Date
    var action: String
    var previousStatus: String?

    init(id: UUID = UUID(), timestamp: Date = .now, action: String, previousStatus: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.previousStatus = previousStatus
    }
}

enum FlightEditHistory {
    static func decode(from json: String?) -> [FlightEditRecord] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([FlightEditRecord].self, from: data)) ?? []
    }

    static func encode(_ records: [FlightEditRecord]) -> String? {
        guard let data = try? JSONEncoder().encode(records) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func append(action: String, previousStatus: String?, to json: String?) -> String? {
        var records = decode(from: json)
        records.append(FlightEditRecord(action: action, previousStatus: previousStatus))
        return encode(records)
    }
}