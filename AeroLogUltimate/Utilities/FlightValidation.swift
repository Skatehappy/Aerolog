import Foundation

/// Validation results for flight save and finalize operations.
struct FlightValidationResult {
    var isValid: Bool
    var errors: [String]
    var warnings: [String]

    static let valid = FlightValidationResult(isValid: true, errors: [], warnings: [])

    static func invalid(_ errors: [String], warnings: [String] = []) -> FlightValidationResult {
        FlightValidationResult(isValid: false, errors: errors, warnings: warnings)
    }
}

enum FlightValidation {
    /// Validates a flight before saving (lenient — drafts allowed).
    static func validateForSave(_ flight: Flight) -> FlightValidationResult {
        var warnings: [String] = []

        if flight.aircraft == nil {
            warnings.append("No aircraft selected")
        }
        if flight.departureICAO.isEmpty && flight.arrivalICAO.isEmpty && !isSimulatorSession(flight) {
            warnings.append("No route entered")
        }

        return FlightValidationResult(isValid: true, errors: [], warnings: warnings)
    }

    /// Validates a flight before finalizing (strict).
    static func validateForFinalize(_ flight: Flight) -> FlightValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        let hasTime = flight.totalTime > 0
            || flight.simulatorTime > 0
            || flight.groundInstructionTime > 0

        if !hasTime {
            errors.append("Enter total, simulator, or ground instruction time")
        }

        if flight.aircraft == nil {
            errors.append("Select an aircraft or training device")
        }

        if !isSimulatorSession(flight) && !isGroundOnly(flight) {
            if flight.departureICAO.isEmpty {
                errors.append("Departure airport is required")
            }
            if flight.arrivalICAO.isEmpty {
                errors.append("Arrival airport is required")
            }
        }

        if flight.role == .dualReceived {
            if flight.dualReceived == 0 && flight.totalTime > 0 {
                warnings.append("Dual received time is zero — consider updating time breakdown")
            }
            if flight.instructorName?.isEmpty != false {
                warnings.append("No instructor name recorded")
            }
        }

        if flight.role == .dualGiven {
            if flight.dualGiven == 0 && flight.totalTime > 0 {
                warnings.append("Dual given time is zero — consider updating time breakdown")
            }
        }

        let legs = flight.legs ?? []
        if legs.count > 1 {
            let legTotal = legs.reduce(0) { $0 + $1.legTime }
            if abs(legTotal - flight.totalTime) > 0.1 {
                warnings.append("Leg times (\(TimeFormatting.display(legTotal))) don't match total time")
            }
        }

        if errors.isEmpty {
            return FlightValidationResult(isValid: true, errors: [], warnings: warnings)
        }
        return .invalid(errors, warnings: warnings)
    }

    private static func isSimulatorSession(_ flight: Flight) -> Bool {
        flight.aircraft?.isSimulator == true || flight.simulatorTime > 0
    }

    private static func isGroundOnly(_ flight: Flight) -> Bool {
        flight.groundInstructionTime > 0 && flight.totalTime == 0 && flight.simulatorTime == 0
    }
}