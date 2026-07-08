import Foundation

// MARK: - Flight

/// Lifecycle state of a logbook entry.
enum FlightStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case finalized
}

/// The pilot's capacity on a given flight.
enum FlightRole: String, Codable, CaseIterable, Sendable {
    case pic
    case sic
    case dualReceived
    case dualGiven
    case solo
    case safetyPilot
    case examiner
    case student
}

/// Environmental / operational conditions logged with a flight.
enum FlightCondition: String, Codable, CaseIterable, Sendable {
    case day
    case night
    case actualInstrument
    case simulatedInstrument
    case crossCountry
    case mountain
    case formation
}

// MARK: - Aircraft

/// FAA aircraft category (14 CFR 61.5).
enum AircraftCategory: String, Codable, CaseIterable, Sendable {
    case airplane
    case rotorcraft
    case glider
    case lighterThanAir
    case poweredLift
    case poweredParachute
    case weightShiftControl
}

/// FAA aircraft class within a category.
enum AircraftClass: String, Codable, CaseIterable, Sendable {
    case singleEngineLand
    case singleEngineSea
    case multiEngineLand
    case multiEngineSea
    case helicopter
    case gyroplane
    case airship
    case balloon
    case weightShiftControl
    case poweredParachute
}

extension AircraftClass {
    /// Short FAA-style label used in scoped-currency names and dashboard groups.
    var abbreviation: String {
        switch self {
        case .singleEngineLand: "ASEL"
        case .singleEngineSea: "ASES"
        case .multiEngineLand: "AMEL"
        case .multiEngineSea: "AMES"
        case .helicopter: "Helicopter"
        case .gyroplane: "Gyroplane"
        case .airship: "Airship"
        case .balloon: "Balloon"
        case .weightShiftControl: "Weight-Shift"
        case .poweredParachute: "Powered Parachute"
        }
    }

    var displayName: String { abbreviation }

    /// The pilot rating that authorizes acting as PIC in this class, or nil for
    /// the base ASEL rating (held by every certificated airplane pilot) and
    /// classes without a distinct stored rating. Used by the anomaly sweep.
    var matchingRating: PilotRating? {
        switch self {
        case .singleEngineLand: nil
        case .multiEngineLand: .multiEngineLand
        case .multiEngineSea: .multiEngineSea
        case .singleEngineSea: .singleEngineSea
        case .helicopter: .rotorcraftHelicopter
        case .airship: .lighterThanAirAirship
        case .balloon: .lighterThanAirBalloon
        case .gyroplane, .weightShiftControl, .poweredParachute: nil
        }
    }
}

extension AircraftCategory {
    var displayName: String {
        switch self {
        case .airplane: "Airplane"
        case .rotorcraft: "Rotorcraft"
        case .glider: "Glider"
        case .lighterThanAir: "Lighter-Than-Air"
        case .poweredLift: "Powered-Lift"
        case .poweredParachute: "Powered Parachute"
        case .weightShiftControl: "Weight-Shift Control"
        }
    }
}

/// Simulator / training device classification.
enum SimulatorLevel: String, Codable, CaseIterable, Sendable {
    case none
    case batd   // Basic Aviation Training Device
    case aatd   // Advanced Aviation Training Device
    case ftd    // Flight Training Device
    case ffs    // Full Flight Simulator
}

// MARK: - Instrument Approaches

/// Standard instrument approach types for currency tracking.
enum ApproachType: String, Codable, CaseIterable, Sendable {
    case ils
    case loc
    case lda
    case rnav
    case gps
    case vor
    case ndb
    case visual
    case contact
    case other
}

// MARK: - Medical mode & recency sources (F1/F2)

enum MedicalMode: String, Codable, CaseIterable, Sendable {
    case classMedical
    case basicMed

    var displayName: String {
        switch self {
        case .classMedical: "Class Medical"
        case .basicMed: "BasicMed"
        }
    }
}

enum FlightReviewSource: String, Codable, CaseIterable, Sendable {
    case flightReview
    case checkride
    case wingsPhase

    var displayName: String {
        switch self {
        case .flightReview: "Flight Review"
        case .checkride: "Checkride"
        case .wingsPhase: "WINGS Phase"
        }
    }
}

enum IPCSource: String, Codable, CaseIterable, Sendable {
    case ipc
    case instrumentCheckride

    var displayName: String {
        switch self {
        case .ipc: "IPC"
        case .instrumentCheckride: "Instrument Checkride"
        }
    }
}

// MARK: - Certificates & Medical

enum CertificateType: String, Codable, CaseIterable, Sendable {
    case student
    case recreational
    case privatePilot = "private"
    case commercial
    case atp
    case cfi
    case cfii
    case mei
}

enum MedicalClass: String, Codable, CaseIterable, Sendable {
    case first
    case second
    case third
    case basicMed
}

/// Pilot certificate ratings (subset; extensible via custom entries).
enum PilotRating: String, Codable, CaseIterable, Sendable {
    case instrumentAirplane
    case instrumentHelicopter
    case multiEngineLand
    case multiEngineSea
    case singleEngineSea
    case rotorcraftHelicopter
    case glider
    case lighterThanAirAirship
    case lighterThanAirBalloon
    case typeRating
    case flightInstructor
    case flightInstructorInstrument
    case multiEngineInstructor
}

extension PilotRating {
    var displayName: String {
        switch self {
        case .instrumentAirplane: "Instrument — Airplane"
        case .instrumentHelicopter: "Instrument — Helicopter"
        case .multiEngineLand: "Airplane Multi-Engine Land (AMEL)"
        case .multiEngineSea: "Airplane Multi-Engine Sea (AMES)"
        case .singleEngineSea: "Airplane Single-Engine Sea (ASES)"
        case .rotorcraftHelicopter: "Rotorcraft — Helicopter"
        case .glider: "Glider"
        case .lighterThanAirAirship: "Lighter-Than-Air — Airship"
        case .lighterThanAirBalloon: "Lighter-Than-Air — Balloon"
        case .typeRating: "Type Rating"
        case .flightInstructor: "Flight Instructor (CFI)"
        case .flightInstructorInstrument: "Flight Instructor — Instrument (CFII)"
        case .multiEngineInstructor: "Multi-Engine Instructor (MEI)"
        }
    }

    enum Group: String, CaseIterable { case classRating = "Class Ratings", instrument = "Instrument Ratings", instructor = "Instructor Ratings", other = "Other" }

    var group: Group {
        switch self {
        case .multiEngineLand, .multiEngineSea, .singleEngineSea, .rotorcraftHelicopter,
             .glider, .lighterThanAirAirship, .lighterThanAirBalloon: .classRating
        case .instrumentAirplane, .instrumentHelicopter: .instrument
        case .flightInstructor, .flightInstructorInstrument, .multiEngineInstructor: .instructor
        case .typeRating: .other
        }
    }
}

// MARK: - Endorsements

enum EndorsementStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case pendingSignature
    case signed
    case expired
    case revoked
}

/// Built-in endorsement template identifiers (Phase 3 expands usage).
enum EndorsementTemplateID: String, Codable, CaseIterable, Sendable {
    case preSoloAeronauticalKnowledge
    case preSoloFlightTraining
    case soloFlight
    case soloCrossCountry
    case crossCountry
    case nightSolo
    case complexAircraft
    case highPerformance
    case tailwheel
    case highAltitude
    case flightReview
    case instrumentProficiency
    case custom
}

// MARK: - Currency

/// FAA and custom currency requirement types.
enum CurrencyType: String, Codable, CaseIterable, Sendable {
    case passengerCarryingDay          // 61.57(a)
    case passengerCarryingNight        // 61.57(b)
    case instrument                    // 61.57(c)
    case tailwheel                     // 61.57(a)(1)(ii)
    case flightReview                  // 61.56
    case instrumentProficiencyCheck    // 61.57(d)
    case medical
    case cfiCertificate
    case typeRating
    case complex                       // Recent experience (61.31(e) proficiency)
    case highPerformance               // Recent experience (61.31(f) proficiency)
    case custom
}

enum CurrencyStatus: String, Codable, CaseIterable, Sendable {
    case current
    case expiringSoon
    case expired
    case notApplicable
    case unknown
}

// MARK: - Training

enum TrainingRelationshipStatus: String, Codable, CaseIterable, Sendable {
    case active
    case paused
    case completed
    case terminated
}

enum TrainingGoal: String, Codable, CaseIterable, Sendable {
    case privatePilot
    case instrumentRating
    case commercialPilot
    case cfi
    case cfii
    case multiEngine
    case tailwheel
    case custom
}

// MARK: - Attachments

enum AttachmentKind: String, Codable, CaseIterable, Sendable {
    case photo
    case video
    case document
    case signature
    case other
}

enum AttachmentLinkType: String, Codable, CaseIterable, Sendable {
    case flight
    case endorsement
    case aircraft
    case pilotProfile
    case report
}

// MARK: - Reports

enum ReportType: String, Codable, CaseIterable, Sendable {
    case faa8710
    case totalTimeSummary
    case flightLog
    case currencySummary
    case studentProgress
    case airportStatistics
    case aircraftStatistics
    case custom
}

enum ReportOutputFormat: String, Codable, CaseIterable, Sendable {
    case pdf
    case csv
    case json
}

// MARK: - Fuel & Expenses

enum FuelUnit: String, Codable, CaseIterable, Sendable {
    case gallons
    case liters
}

enum ExpenseCategory: String, Codable, CaseIterable, Sendable {
    case fuel
    case ramp
    case rental
    case instruction
    case maintenance
    case other
}

// MARK: - Maintenance

enum MaintenanceType: String, Codable, CaseIterable, Sendable {
    case annual
    case hundredHour
    case oilChange
    case transponder
    case altimeter
    case adCompliance
    case other
}

// MARK: - Sync

enum SyncState: String, Codable, CaseIterable, Sendable {
    case localOnly
    case pendingUpload
    case synced
    case pendingDownload
    case conflict
}

enum SyncConflictResolution: String, Codable, CaseIterable, Sendable {
    case keepLocal
    case keepRemote
    case merge
    case manual
}