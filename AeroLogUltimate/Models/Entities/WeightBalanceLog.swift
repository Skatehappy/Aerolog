import Foundation
import SwiftData

/// Weight and balance worksheet attached to a flight.
@Model
final class WeightBalanceLog {
    var emptyWeight: Double
    var emptyArm: Double
    var rampWeight: Double?
    var rampCG: Double?
    var takeoffWeight: Double?
    var takeoffCG: Double?
    var landingWeight: Double?
    var landingCG: Double?
    var forwardCGLimit: Double?
    var aftCGLimit: Double?
    /// JSON-encoded `[WeightBalanceStation]` for seats, baggage, fuel stations.
    var stationEntriesJSON: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    @Relationship(deleteRule: .nullify, inverse: \Flight.weightBalanceLog)
    var flight: Flight?

    var stationEntries: [WeightBalanceStation] {
        get {
            guard let json = stationEntriesJSON,
                  let data = json.data(using: .utf8),
                  let entries = try? JSONDecoder().decode([WeightBalanceStation].self, from: data) else {
                return []
            }
            return entries
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                stationEntriesJSON = json
            } else {
                stationEntriesJSON = nil
            }
            touch()
        }
    }

    init(emptyWeight: Double = 0, emptyArm: Double = 0) {
        self.emptyWeight = emptyWeight
        self.emptyArm = emptyArm
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}

/// A single loading station for W&B calculations.
struct WeightBalanceStation: Codable, Identifiable, Sendable, Hashable {
    var id: UUID
    var name: String
    var weight: Double
    var arm: Double

    var moment: Double { weight * arm }

    init(id: UUID = UUID(), name: String, weight: Double = 0, arm: Double = 0) {
        self.id = id
        self.name = name
        self.weight = weight
        self.arm = arm
    }
}