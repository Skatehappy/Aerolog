import Foundation
import SwiftData

/// Aircraft or simulator/training device used for flight logging.
@Model
final class Aircraft {
    // MARK: Identification

    /// Tail number, N-number, or simulator identifier.
    var registration: String
    var make: String
    var model: String
    var typeDesignator: String?

    // MARK: Classification

    var category: AircraftCategory
    var aircraftClass: AircraftClass
    var simulatorLevel: SimulatorLevel

    // MARK: Capabilities

    var isComplex: Bool
    var isHighPerformance: Bool
    var isTailwheel: Bool
    var isRetractable: Bool
    var isPressurized: Bool
    var requiresTypeRating: Bool

    // MARK: Time Tracking

    var tracksHobbs: Bool
    var tracksTach: Bool

    // MARK: Metadata

    var isActive: Bool
    var isFavorite: Bool
    var yearManufactured: Int?
    var serialNumber: String?
    var performanceNotes: String?
    var cruiseSpeedKIAS: Int?
    var bestGlideSpeedKIAS: Int?
    var fuelCapacity: Double?
    var defaultFuelBurnGPH: Double?
    var notes: String?

    // MARK: Audit

    var createdAt: Date
    var updatedAt: Date

    // MARK: Sync

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    // MARK: Relationships

    @Relationship(deleteRule: .nullify, inverse: \Flight.aircraft)
    var flights: [Flight]?

    @Relationship(deleteRule: .nullify, inverse: \Attachment.aircraft)
    var attachments: [Attachment]?

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceItem.aircraft)
    var maintenanceItems: [MaintenanceItem]?

    // MARK: Computed

    var displayName: String {
        if !registration.isEmpty {
            return registration
        }
        return [make, model].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var isSimulator: Bool {
        simulatorLevel != .none
    }

    // MARK: Init

    init(
        registration: String = "",
        make: String = "",
        model: String = "",
        category: AircraftCategory = .airplane,
        aircraftClass: AircraftClass = .singleEngineLand,
        simulatorLevel: SimulatorLevel = .none
    ) {
        self.registration = registration
        self.make = make
        self.model = model
        self.category = category
        self.aircraftClass = aircraftClass
        self.simulatorLevel = simulatorLevel
        self.isComplex = false
        self.isHighPerformance = false
        self.isTailwheel = false
        self.isRetractable = false
        self.isPressurized = false
        self.requiresTypeRating = false
        self.tracksHobbs = true
        self.tracksTach = false
        self.isActive = true
        self.isFavorite = false
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}