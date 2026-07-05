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

// MARK: - Certificates & Medical

enum CertificateType: String, Codable, CaseIterable, Sendable {
    case student
    case recreational
    case private
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