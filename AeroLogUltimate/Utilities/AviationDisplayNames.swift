import Foundation

// MARK: - Flight

extension FlightStatus {
    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .finalized: "Finalized"
        }
    }
}

extension FlightRole {
    var displayName: String {
        switch self {
        case .pic: "PIC"
        case .sic: "SIC"
        case .dualReceived: "Dual Received"
        case .dualGiven: "Dual Given (CFI)"
        case .solo: "Solo"
        case .safetyPilot: "Safety Pilot"
        case .examiner: "Examiner"
        case .student: "Student"
        }
    }
}

extension FlightCondition {
    var displayName: String {
        switch self {
        case .day: "Day"
        case .night: "Night"
        case .actualInstrument: "Actual Instrument"
        case .simulatedInstrument: "Simulated Instrument"
        case .crossCountry: "Cross Country"
        case .mountain: "Mountain"
        case .formation: "Formation"
        }
    }

    var systemImage: String {
        switch self {
        case .day: "sun.max"
        case .night: "moon.stars"
        case .actualInstrument: "cloud.fog"
        case .simulatedInstrument: "goggles"
        case .crossCountry: "map"
        case .mountain: "mountain.2"
        case .formation: "airplane.circle"
        }
    }
}

// MARK: - Training

extension TrainingGoal {
    var displayName: String {
        switch self {
        case .privatePilot: "Private Pilot"
        case .instrumentRating: "Instrument Rating"
        case .commercialPilot: "Commercial Pilot"
        case .cfi: "CFI"
        case .cfii: "CFII"
        case .multiEngine: "Multi-Engine"
        case .tailwheel: "Tailwheel"
        case .custom: "Custom Goal"
        }
    }
}

extension TrainingRelationshipStatus {
    var displayName: String {
        switch self {
        case .active: "Active"
        case .paused: "Paused"
        case .completed: "Completed"
        case .terminated: "Terminated"
        }
    }
}

// MARK: - Aircraft

extension AircraftCategory {
    var displayName: String {
        switch self {
        case .airplane: "Airplane"
        case .rotorcraft: "Rotorcraft"
        case .glider: "Glider"
        case .lighterThanAir: "Lighter Than Air"
        case .poweredLift: "Powered Lift"
        case .poweredParachute: "Powered Parachute"
        case .weightShiftControl: "Weight Shift Control"
        }
    }
}

extension AircraftClass {
    var displayName: String {
        switch self {
        case .singleEngineLand: "Single Engine Land"
        case .singleEngineSea: "Single Engine Sea"
        case .multiEngineLand: "Multi Engine Land"
        case .multiEngineSea: "Multi Engine Sea"
        case .helicopter: "Helicopter"
        case .gyroplane: "Gyroplane"
        case .airship: "Airship"
        case .balloon: "Balloon"
        case .weightShiftControl: "Weight Shift Control"
        case .poweredParachute: "Powered Parachute"
        }
    }
}

extension SimulatorLevel {
    var displayName: String {
        switch self {
        case .none: "Aircraft (Not Simulator)"
        case .batd: "BATD"
        case .aatd: "AATD"
        case .ftd: "FTD"
        case .ffs: "Full Flight Simulator"
        }
    }

    var shortName: String {
        switch self {
        case .none: "Aircraft"
        case .batd: "BATD"
        case .aatd: "AATD"
        case .ftd: "FTD"
        case .ffs: "FFS"
        }
    }
}

// MARK: - Approaches

extension ApproachType {
    var displayName: String {
        switch self {
        case .ils: "ILS"
        case .loc: "LOC"
        case .lda: "LDA"
        case .rnav: "RNAV"
        case .gps: "GPS"
        case .vor: "VOR"
        case .ndb: "NDB"
        case .visual: "Visual"
        case .contact: "Contact"
        case .other: "Other"
        }
    }
}

extension EndorsementTemplateID {
    var displayName: String {
        EndorsementTemplateCatalog.definition(for: self)?.title ?? rawValue
    }
}

extension EndorsementStatus {
    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .pendingSignature: "Awaiting Signature"
        case .signed: "Signed"
        case .expired: "Expired"
        case .revoked: "Revoked"
        }
    }
}

extension CurrencyType {
    var displayName: String {
        switch self {
        case .passengerCarryingDay: "Passenger (Day)"
        case .passengerCarryingNight: "Passenger (Night)"
        case .instrument: "Instrument"
        case .tailwheel: "Tailwheel"
        case .flightReview: "Flight Review"
        case .instrumentProficiencyCheck: "IPC"
        case .medical: "Medical"
        case .cfiCertificate: "CFI Certificate"
        case .typeRating: "Type Rating"
        case .complex: "Complex Aircraft"
        case .highPerformance: "High Performance"
        case .custom: "Custom"
        }
    }

    var regulationReference: String? {
        switch self {
        case .passengerCarryingDay: "61.57(a)"
        case .passengerCarryingNight: "61.57(b)"
        case .instrument: "61.57(c)"
        case .tailwheel: "61.57(a)(1)(ii)"
        case .flightReview: "61.56"
        case .instrumentProficiencyCheck: "61.57(d)"
        case .medical: "61.23"
        case .cfiCertificate: "61.197"
        case .typeRating: "61.58"
        case .complex: "61.31(e)"
        case .highPerformance: "61.31(f)"
        case .custom: nil
        }
    }
}

extension CurrencyStatus {
    var displayName: String {
        switch self {
        case .current: "Current"
        case .expiringSoon: "Expiring Soon"
        case .expired: "Expired"
        case .notApplicable: "N/A"
        case .unknown: "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .current: "checkmark.circle.fill"
        case .expiringSoon: "exclamationmark.triangle.fill"
        case .expired: "xmark.circle.fill"
        case .notApplicable: "minus.circle"
        case .unknown: "questionmark.circle"
        }
    }
}

extension AttachmentKind {
    var displayName: String {
        switch self {
        case .photo: "Photo"
        case .video: "Video"
        case .document: "Document"
        case .signature: "Signature"
        case .other: "Other"
        }
    }
}