import Foundation

/// Pure calculation engine for FAA and custom currency rules.
///
/// Operates on in-memory flight data — no SwiftData dependencies.
struct CurrencyEngine {
    let referenceDate: Date

    init(referenceDate: Date = .now) {
        self.referenceDate = referenceDate
    }

    // MARK: - Entry Point

    func calculate(
        requirement: CurrencyRequirement,
        pilot: PilotProfile,
        flights: [Flight],
        endorsements: [Endorsement] = [],
        instrumentCurrencyCurrent: Bool = false
    ) -> CurrencyCalculationResult {
        let qualifyingFlights = Self.qualifyingFlights(from: flights, pilot: pilot)

        let result: (CurrencyStatus, String, String?, Date?, Date?, Date?, CurrencyDetailPayload) = switch requirement.currencyType {
        case .passengerCarryingDay:
            calculateDayPassenger(requirement: requirement, flights: qualifyingFlights)
        case .passengerCarryingNight:
            calculateNightPassenger(requirement: requirement, flights: qualifyingFlights)
        case .instrument:
            calculateInstrument(requirement: requirement, flights: qualifyingFlights)
        case .tailwheel:
            calculateTailwheel(requirement: requirement, flights: qualifyingFlights)
        case .flightReview:
            calculateFlightReview(requirement: requirement, pilot: pilot, endorsements: endorsements, flights: qualifyingFlights)
        case .instrumentProficiencyCheck:
            calculateIPC(requirement: requirement, pilot: pilot, endorsements: endorsements, instrumentCurrent: instrumentCurrencyCurrent)
        case .medical:
            calculateMedical(requirement: requirement, pilot: pilot)
        case .cfiCertificate:
            calculateCFI(requirement: requirement, pilot: pilot)
        case .typeRating:
            calculateTypeRating(requirement: requirement, flights: qualifyingFlights)
        case .complex:
            calculateAircraftExperience(requirement: requirement, flights: qualifyingFlights, predicate: { $0.isComplex })
        case .highPerformance:
            calculateAircraftExperience(requirement: requirement, flights: qualifyingFlights, predicate: { $0.isHighPerformance })
        case .custom:
            calculateCustom(requirement: requirement, flights: qualifyingFlights)
        }

        return CurrencyCalculationResult(
            requirementSyncID: requirement.syncMetadata?.syncID ?? UUID(),
            requirementName: requirement.displayName,
            currencyType: requirement.currencyType,
            status: result.0,
            summaryText: result.1,
            warningText: result.2,
            expiresAt: result.3,
            windowStartDate: result.4,
            windowEndDate: result.5,
            detail: result.6,
            calculatedAt: referenceDate
        )
    }

    // MARK: - 61.57(a) Day Passenger

    private func calculateDayPassenger(
        requirement: CurrencyRequirement,
        flights: [Flight]
    ) -> CurrencyTuple {
        let required = requirement.requiredLandings ?? 3
        let windowDays = requirement.lookbackDays
        let windowStart = CurrencyDateUtilities.windowStart(days: windowDays, from: referenceDate)
        let windowEnd = CurrencyDateUtilities.startOfDay(referenceDate)

        let events = landingEvents(
            from: flights.filter { isSoleManipulator($0) && $0.flightDate >= windowStart },
            day: true,
            fullStopOnly: false
        )

        return landingCurrencyResult(
            regulation: "14 CFR 61.57(a)",
            required: required,
            windowDays: windowDays,
            windowStart: windowStart,
            windowEnd: windowEnd,
            events: events,
            requirement: requirement,
            unitLabel: "day landings"
        )
    }

    // MARK: - 61.57(b) Night Passenger

    private func calculateNightPassenger(
        requirement: CurrencyRequirement,
        flights: [Flight]
    ) -> CurrencyTuple {
        let required = requirement.requiredNightLandings ?? requirement.requiredLandings ?? 3
        let windowDays = requirement.lookbackDays
        let windowStart = CurrencyDateUtilities.windowStart(days: windowDays, from: referenceDate)
        let windowEnd = CurrencyDateUtilities.startOfDay(referenceDate)

        let events = landingEvents(
            from: flights.filter {
                isSoleManipulator($0)
                    && $0.flightDate >= windowStart
                    && ($0.nightTime > 0 || $0.conditions.contains(.night))
            },
            day: false,
            fullStopOnly: true
        )

        return landingCurrencyResult(
            regulation: "14 CFR 61.57(b)",
            required: required,
            windowDays: windowDays,
            windowStart: windowStart,
            windowEnd: windowEnd,
            events: events,
            requirement: requirement,
            unitLabel: "night full-stop landings"
        )
    }

    // MARK: - 61.57(c) Instrument

    private func calculateInstrument(
        requirement: CurrencyRequirement,
        flights: [Flight]
    ) -> CurrencyTuple {
        let requiredApproaches = requirement.requiredApproaches ?? 6
        let requiredHolds = 1
        let windowMonths = 6
        let windowStart = CurrencyDateUtilities.windowStart(months: windowMonths, from: referenceDate)
        let windowEnd = CurrencyDateUtilities.startOfDay(referenceDate)

        let instrumentFlights = flights.filter {
            $0.flightDate >= windowStart && isInstrumentQualifyingRole($0) && hasInstrumentActivity($0)
        }

        var approachCount = 0
        var holdCount = 0
        var events: [QualifyingEvent] = []

        for flight in instrumentFlights.sorted(by: { $0.flightDate > $1.flightDate }) {
            let approaches = flight.approaches ?? []
            for approach in approaches {
                approachCount += approach.approachCount
                events.append(QualifyingEvent(
                    date: flight.flightDate,
                    description: "\(approach.approachType.displayName) at \(approach.airportICAO ?? "—")",
                    flightSyncID: flight.syncMetadata?.syncID,
                    contribution: "\(approach.approachCount) approach(es)"
                ))
            }
            if flight.holds > 0 {
                holdCount += flight.holds
                events.append(QualifyingEvent(
                    date: flight.flightDate,
                    description: "Holding procedures",
                    flightSyncID: flight.syncMetadata?.syncID,
                    contribution: "\(flight.holds) hold(s)"
                ))
            }
        }

        let approachesMet = approachCount >= requiredApproaches
        let holdsMet = holdCount >= requiredHolds
        let isCurrent = approachesMet && holdsMet

        let expiresAt: Date? = if isCurrent, let oldestApproachFlight = instrumentFlights.min(by: { $0.flightDate < $1.flightDate }) {
            CurrencyDateUtilities.calendar.date(byAdding: .month, value: windowMonths, to: CurrencyDateUtilities.startOfDay(oldestApproachFlight.flightDate))
        } else {
            nil
        }

        let daysRemaining = expiresAt.map { CurrencyDateUtilities.daysUntil($0, from: referenceDate) }

        let status = resolveStatus(
            isCurrent: isCurrent,
            expiresAt: expiresAt,
            leadDays: requirement.reminderLeadDays,
            hasData: !instrumentFlights.isEmpty || approachCount > 0
        )

        var summary: String
        var warning: String?
        var nextAction: String?

        if isCurrent {
            summary = "\(approachCount) of \(requiredApproaches) approaches, \(holdCount) hold(s) in last 6 months"
            if let days = daysRemaining, days <= requirement.reminderLeadDays {
                warning = "Instrument currency expires in \(days) day(s)"
            }
        } else {
            let needed = max(0, requiredApproaches - approachCount)
            let holdsNeeded = holdsMet ? 0 : requiredHolds - holdCount
            summary = "\(approachCount)/\(requiredApproaches) approaches"
            if holdsNeeded > 0 {
                summary += ", needs holding practice"
            }
            warning = "Not current — \(needed) more approach(es) needed"
            nextAction = holdsNeeded > 0
                ? "Log \(needed) approach(es) and \(holdsNeeded) hold(s), or complete an IPC"
                : "Log \(needed) more instrument approach(es), or complete an IPC"
        }

        let detail = CurrencyDetailPayload(
            regulationReference: "14 CFR 61.57(c)",
            requiredApproaches: requiredApproaches,
            requiredHolds: requiredHolds,
            countedApproaches: approachCount,
            countedHolds: holdCount,
            qualifyingEvents: Array(events.prefix(20)),
            daysRemaining: daysRemaining,
            progressFraction: min(1.0, Double(approachCount) / Double(requiredApproaches)),
            lastQualifyingDate: events.first?.date,
            nextRequiredAction: nextAction
        )

        return (status, summary, warning, expiresAt, windowStart, windowEnd, detail)
    }

    // MARK: - Tailwheel 61.57(a)(1)(ii)

    private func calculateTailwheel(
        requirement: CurrencyRequirement,
        flights: [Flight]
    ) -> CurrencyTuple {
        let required = requirement.requiredLandings ?? 3
        let windowDays = requirement.lookbackDays
        let windowStart = CurrencyDateUtilities.windowStart(days: windowDays, from: referenceDate)
        let windowEnd = CurrencyDateUtilities.startOfDay(referenceDate)

        let tailwheelFlights = flights.filter {
            isSoleManipulator($0)
                && $0.flightDate >= windowStart
                && ($0.aircraft?.isTailwheel == true)
        }

        let events = landingEvents(from: tailwheelFlights, day: true, fullStopOnly: true)

        return landingCurrencyResult(
            regulation: "14 CFR 61.57(a)(1)(ii)",
            required: required,
            windowDays: windowDays,
            windowStart: windowStart,
            windowEnd: windowEnd,
            events: events,
            requirement: requirement,
            unitLabel: "tailwheel full-stop landings"
        )
    }

    // MARK: - 61.56 Flight Review

    private func calculateFlightReview(
        requirement: CurrencyRequirement,
        pilot: PilotProfile,
        endorsements: [Endorsement],
        flights: [Flight]
    ) -> CurrencyTuple {
        let windowMonths = 24
        let windowStart = CurrencyDateUtilities.windowStart(months: windowMonths, from: referenceDate)
        let windowEnd = CurrencyDateUtilities.startOfDay(referenceDate)

        let endorsementDate = endorsements
            .filter { $0.templateID == .flightReview && $0.status == .signed }
            .compactMap { $0.issuedDate ?? $0.signedAt }
            .max()

        let flightReviewFlightDate = flights
            .filter {
                $0.flightDate >= windowStart
                    && ($0.lessonTitle?.lowercased().contains("flight review") == true
                        || $0.lessonTitle?.lowercased().contains("bfr") == true
                        || $0.remarks?.lowercased().contains("flight review") == true)
            }
            .map(\.flightDate)
            .max()

        let lastReview = [pilot.lastFlightReviewDate, endorsementDate, flightReviewFlightDate]
            .compactMap { $0 }
            .max()

        guard let lastReview else {
            let detail = CurrencyDetailPayload(
                regulationReference: "14 CFR 61.56",
                nextRequiredAction: "Complete a Flight Review with a CFI"
            )
            return (.unknown, "No flight review on record", "Set your last flight review date in pilot profile", nil, windowStart, windowEnd, detail)
        }

        let expiresAt = CurrencyDateUtilities.calendar.date(byAdding: .month, value: windowMonths, to: CurrencyDateUtilities.startOfDay(lastReview))
        let isCurrent = lastReview >= windowStart
        let daysRemaining = expiresAt.map { CurrencyDateUtilities.daysUntil($0, from: referenceDate) }
        let status = resolveStatus(isCurrent: isCurrent, expiresAt: expiresAt, leadDays: requirement.reminderLeadDays, hasData: true)

        let summary = isCurrent
            ? "Flight review \(formatted(lastReview)) — valid 24 months"
            : "Flight review expired — last \(formatted(lastReview))"

        let warning: String? = if let days = daysRemaining, days <= requirement.reminderLeadDays, isCurrent {
            "Flight review due in \(days) day(s)"
        } else if !isCurrent {
            "Flight review required before acting as PIC"
        } else {
            nil
        }

        let detail = CurrencyDetailPayload(
            regulationReference: "14 CFR 61.56",
            qualifyingEvents: [QualifyingEvent(date: lastReview, description: "Flight Review", contribution: "Valid 24 calendar months")],
            daysRemaining: daysRemaining,
            progressFraction: isCurrent ? 1.0 : 0.0,
            lastQualifyingDate: lastReview,
            nextRequiredAction: isCurrent ? nil : "Schedule a Flight Review (BFR) with a CFI"
        )

        return (status, summary, warning, expiresAt, windowStart, windowEnd, detail)
    }

    // MARK: - 61.57(d) IPC

    private func calculateIPC(
        requirement: CurrencyRequirement,
        pilot: PilotProfile,
        endorsements: [Endorsement],
        instrumentCurrent: Bool
    ) -> CurrencyTuple {
        if instrumentCurrent {
            let detail = CurrencyDetailPayload(
                regulationReference: "14 CFR 61.57(d)",
                nextRequiredAction: nil
            )
            return (.notApplicable, "Instrument currency current — IPC not required", nil, nil, nil, nil, detail)
        }

        let windowMonths = 6
        let windowStart = CurrencyDateUtilities.windowStart(months: windowMonths, from: referenceDate)

        let endorsementDate = endorsements
            .filter { $0.templateID == .instrumentProficiency && $0.status == .signed }
            .compactMap { $0.issuedDate ?? $0.signedAt }
            .max()

        let lastIPC = [pilot.lastIPCDate, endorsementDate].compactMap { $0 }.max()

        guard let lastIPC else {
            let detail = CurrencyDetailPayload(
                regulationReference: "14 CFR 61.57(d)",
                nextRequiredAction: "Complete an Instrument Proficiency Check"
            )
            return (.expired, "IPC required — not on record", "Not current for IFR operations", nil, windowStart, nil, detail)
        }

        let expiresAt = CurrencyDateUtilities.calendar.date(byAdding: .month, value: windowMonths, to: CurrencyDateUtilities.startOfDay(lastIPC))
        let isCurrent = lastIPC >= windowStart
        let daysRemaining = expiresAt.map { CurrencyDateUtilities.daysUntil($0, from: referenceDate) }
        let status = resolveStatus(isCurrent: isCurrent, expiresAt: expiresAt, leadDays: requirement.reminderLeadDays, hasData: true)

        let summary = isCurrent
            ? "IPC \(formatted(lastIPC)) — valid 6 months"
            : "IPC expired — last \(formatted(lastIPC))"

        let detail = CurrencyDetailPayload(
            regulationReference: "14 CFR 61.57(d)",
            qualifyingEvents: [QualifyingEvent(date: lastIPC, description: "Instrument Proficiency Check", contribution: "Valid 6 calendar months")],
            daysRemaining: daysRemaining,
            lastQualifyingDate: lastIPC,
            nextRequiredAction: isCurrent ? nil : "Complete a new IPC with a CFII or examiner"
        )

        return (status, summary, isCurrent ? nil : "IPC required for IFR passenger carrying", expiresAt, windowStart, nil, detail)
    }

    // MARK: - Medical

    private func calculateMedical(
        requirement: CurrencyRequirement,
        pilot: PilotProfile
    ) -> CurrencyTuple {
        guard let expiration = pilot.medicalExpirationDate else {
            let detail = CurrencyDetailPayload(nextRequiredAction: "Enter medical certificate expiration in pilot profile")
            return (.unknown, "Medical expiration not set", "Add your medical certificate date", nil, nil, nil, detail)
        }

        let expiresAt = CurrencyDateUtilities.startOfDay(expiration)
        let isCurrent = expiresAt >= CurrencyDateUtilities.startOfDay(referenceDate)
        let daysRemaining = CurrencyDateUtilities.daysUntil(expiresAt, from: referenceDate)
        let status = resolveStatus(isCurrent: isCurrent, expiresAt: expiresAt, leadDays: requirement.reminderLeadDays, hasData: true)

        let classLabel = pilot.medicalClass?.rawValue.capitalized ?? "Medical"
        let summary = isCurrent
            ? "\(classLabel) valid until \(formatted(expiration))"
            : "\(classLabel) expired \(formatted(expiration))"

        let warning: String? = if isCurrent && daysRemaining <= requirement.reminderLeadDays {
            "Medical expires in \(daysRemaining) day(s)"
        } else if !isCurrent {
            "Medical certificate required to exercise privileges"
        } else {
            nil
        }

        let detail = CurrencyDetailPayload(
            regulationReference: "14 CFR 61.23",
            daysRemaining: daysRemaining,
            progressFraction: isCurrent ? 1.0 : 0.0,
            lastQualifyingDate: pilot.medicalIssueDate,
            nextRequiredAction: isCurrent ? nil : "Obtain a new medical certificate"
        )

        return (status, summary, warning, expiresAt, nil, nil, detail)
    }

    // MARK: - CFI Certificate

    private func calculateCFI(
        requirement: CurrencyRequirement,
        pilot: PilotProfile
    ) -> CurrencyTuple {
        guard pilot.isCFI else {
            return (.notApplicable, "Not a CFI — tracking disabled", nil, nil, nil, nil, CurrencyDetailPayload())
        }

        guard let expiration = pilot.cfiExpirationDate else {
            let detail = CurrencyDetailPayload(nextRequiredAction: "Enter CFI certificate expiration date")
            return (.unknown, "CFI expiration not set", "Add your CFI renewal date", nil, nil, nil, detail)
        }

        let expiresAt = CurrencyDateUtilities.startOfDay(expiration)
        let isCurrent = expiresAt >= CurrencyDateUtilities.startOfDay(referenceDate)
        let daysRemaining = CurrencyDateUtilities.daysUntil(expiresAt, from: referenceDate)
        let status = resolveStatus(isCurrent: isCurrent, expiresAt: expiresAt, leadDays: requirement.reminderLeadDays, hasData: true)

        let summary = isCurrent
            ? "CFI valid until \(formatted(expiration))"
            : "CFI expired \(formatted(expiration))"

        let warning: String? = if isCurrent && daysRemaining <= requirement.reminderLeadDays {
            "CFI certificate expires in \(daysRemaining) day(s)"
        } else if !isCurrent {
            "CFI certificate renewal required"
        } else {
            nil
        }

        let detail = CurrencyDetailPayload(
            regulationReference: "14 CFR 61.197",
            daysRemaining: daysRemaining,
            nextRequiredAction: isCurrent ? nil : "Renew CFI certificate per 61.197"
        )

        return (status, summary, warning, expiresAt, nil, nil, detail)
    }

    // MARK: - Type Rating

    private func calculateTypeRating(
        requirement: CurrencyRequirement,
        flights: [Flight]
    ) -> CurrencyTuple {
        let designator = requirement.typeRatingDesignator ?? ""
        let windowMonths = 12
        let windowStart = CurrencyDateUtilities.windowStart(months: windowMonths, from: referenceDate)
        let requiredHours = requirement.requiredFlightHours ?? 0

        let matching = flights.filter {
            $0.flightDate >= windowStart
                && isPIC($0)
                && matchesTypeRating($0, designator: designator)
        }

        let hours = matching.reduce(0) { $0 + $1.picTime + ($1.role == .pic ? $1.totalTime : 0) }

        let isCurrent = designator.isEmpty ? !matching.isEmpty : (requiredHours > 0 ? hours >= requiredHours : !matching.isEmpty)
        let lastDate = matching.map(\.flightDate).max()
        let expiresAt = lastDate.flatMap {
            CurrencyDateUtilities.calendar.date(byAdding: .month, value: windowMonths, to: CurrencyDateUtilities.startOfDay($0))
        }

        let status = resolveStatus(isCurrent: isCurrent, expiresAt: expiresAt, leadDays: requirement.reminderLeadDays, hasData: !designator.isEmpty || !matching.isEmpty)

        let label = designator.isEmpty ? "Type rating" : designator
        let summary: String = if isCurrent, let last = lastDate {
            "\(label) — PIC time \(TimeFormatting.display(hours))h, last \(formatted(last))"
        } else if designator.isEmpty {
            "Set type designator on requirement"
        } else {
            "\(label) — no qualifying PIC time in 12 months"
        }

        let detail = CurrencyDetailPayload(
            regulationReference: "14 CFR 61.58",
            requiredFlightHours: requiredHours > 0 ? requiredHours : nil,
            countedFlightHours: hours,
            qualifyingEvents: matching.prefix(10).map {
                QualifyingEvent(
                    date: $0.flightDate,
                    description: $0.routeSummary,
                    flightSyncID: $0.syncMetadata?.syncID,
                    contribution: TimeFormatting.display($0.picTime) + " PIC"
                )
            },
            daysRemaining: expiresAt.map { CurrencyDateUtilities.daysUntil($0, from: referenceDate) },
            lastQualifyingDate: lastDate,
            nextRequiredAction: isCurrent ? nil : "Log PIC time in \(label) aircraft"
        )

        return (status, summary, isCurrent ? nil : "Type rating proficiency recommended", expiresAt, windowStart, nil, detail)
    }

    // MARK: - Complex / High Performance Experience

    private func calculateAircraftExperience(
        requirement: CurrencyRequirement,
        flights: [Flight],
        predicate: (Aircraft) -> Bool
    ) -> CurrencyTuple {
        let windowDays = requirement.lookbackDays
        let windowStart = CurrencyDateUtilities.windowStart(days: windowDays, from: referenceDate)
        let requiredHours = requirement.requiredFlightHours ?? 0.5

        let matching = flights.filter {
            $0.flightDate >= windowStart
                && isPIC($0)
                && ($0.aircraft.map(predicate) == true)
        }

        let hours = matching.reduce(0) { $0 + max($1.picTime, $1.totalTime) }
        let isCurrent = hours >= requiredHours
        let lastDate = matching.map(\.flightDate).max()
        let expiresAt = lastDate.flatMap {
            CurrencyDateUtilities.calendar.date(byAdding: .day, value: windowDays, to: CurrencyDateUtilities.startOfDay($0))
        }

        let status = resolveStatus(isCurrent: isCurrent, expiresAt: expiresAt, leadDays: requirement.reminderLeadDays, hasData: true)
        let summary = isCurrent
            ? "\(TimeFormatting.display(hours))h PIC in last \(windowDays) days"
            : "\(TimeFormatting.display(hours))h of \(TimeFormatting.display(requiredHours))h required"

        let detail = CurrencyDetailPayload(
            regulationReference: requirement.currencyType == .complex ? "14 CFR 61.31(e)" : "14 CFR 61.31(f)",
            requiredFlightHours: requiredHours,
            countedFlightHours: hours,
            daysRemaining: expiresAt.map { CurrencyDateUtilities.daysUntil($0, from: referenceDate) },
            progressFraction: min(1.0, hours / requiredHours),
            lastQualifyingDate: lastDate,
            nextRequiredAction: isCurrent ? nil : "Log PIC time in qualifying aircraft"
        )

        return (status, summary, isCurrent ? nil : "Recent proficiency recommended", expiresAt, windowStart, nil, detail)
    }

    // MARK: - Custom

    private func calculateCustom(
        requirement: CurrencyRequirement,
        flights: [Flight]
    ) -> CurrencyTuple {
        let windowStart = CurrencyDateUtilities.windowStart(days: requirement.lookbackDays, from: referenceDate)
        let windowEnd = CurrencyDateUtilities.startOfDay(referenceDate)
        let filtered = flights.filter { $0.flightDate >= windowStart && isPIC($0) }

        var events: [QualifyingEvent] = []
        var landings = 0
        var nightLandings = 0
        var approaches = 0
        var hours = 0.0

        for flight in filtered {
            landings += flight.dayLandings
            nightLandings += flight.nightLandings
            hours += flight.totalTime
            approaches += (flight.approaches ?? []).reduce(0) { $0 + $1.approachCount }
            events.append(QualifyingEvent(
                date: flight.flightDate,
                description: flight.routeSummary,
                flightSyncID: flight.syncMetadata?.syncID,
                contribution: TimeFormatting.display(flight.totalTime) + "h"
            ))
        }

        var checks: [Bool] = []
        if let req = requirement.requiredLandings { checks.append(landings >= req) }
        if let req = requirement.requiredNightLandings { checks.append(nightLandings >= req) }
        if let req = requirement.requiredApproaches { checks.append(approaches >= req) }
        if let req = requirement.requiredFlightHours { checks.append(hours >= req) }

        let isCurrent = checks.isEmpty ? false : checks.allSatisfy { $0 }
        let status: CurrencyStatus = checks.isEmpty ? .unknown : (isCurrent ? .current : .expired)

        let summary = isCurrent ? "Custom requirement met" : "Custom requirement not met"

        let detail = CurrencyDetailPayload(
            requiredLandings: requirement.requiredLandings,
            requiredNightLandings: requirement.requiredNightLandings,
            requiredApproaches: requirement.requiredApproaches,
            requiredFlightHours: requirement.requiredFlightHours,
            countedLandings: landings,
            countedNightLandings: nightLandings,
            countedApproaches: approaches,
            countedFlightHours: hours,
            qualifyingEvents: Array(events.prefix(15)),
            progressFraction: checks.isEmpty ? 0 : (isCurrent ? 1.0 : 0.5)
        )

        return (status, summary, isCurrent ? nil : "Review custom requirement criteria", nil, windowStart, windowEnd, detail)
    }

    // MARK: - Shared Helpers

    private typealias CurrencyTuple = (CurrencyStatus, String, String?, Date?, Date?, Date?, CurrencyDetailPayload)

    private func landingCurrencyResult(
        regulation: String,
        required: Int,
        windowDays: Int,
        windowStart: Date,
        windowEnd: Date,
        events: [QualifyingEvent],
        requirement: CurrencyRequirement,
        unitLabel: String
    ) -> CurrencyTuple {
        let total = events.reduce(0) { sum, event in
            sum + (Int(event.contribution.split(separator: " ").first ?? "0") ?? 0)
        }

        let isCurrent = total >= required
        let eventDates = events.map(\.date)
        let expiresAt = CurrencyDateUtilities.rollingExpiration(
            eventDates: eventDates,
            requiredCount: min(required, max(1, events.count)),
            windowDays: windowDays
        )

        let daysRemaining = expiresAt.map { CurrencyDateUtilities.daysUntil($0, from: referenceDate) }
        let status = resolveStatus(
            isCurrent: isCurrent,
            expiresAt: expiresAt,
            leadDays: requirement.reminderLeadDays,
            hasData: !events.isEmpty
        )

        let summary = isCurrent
            ? "\(total) \(unitLabel) in last \(windowDays) days"
            : "\(total) of \(required) \(unitLabel) in last \(windowDays) days"

        let warning: String? = if !isCurrent {
            "Need \(required - total) more \(unitLabel)"
        } else if let days = daysRemaining, days <= requirement.reminderLeadDays {
            "Expires in \(days) day(s)"
        } else {
            nil
        }

        let detail = CurrencyDetailPayload(
            regulationReference: regulation,
            requiredLandings: required,
            countedLandings: total,
            qualifyingEvents: Array(events.prefix(15)),
            daysRemaining: daysRemaining,
            progressFraction: min(1.0, Double(total) / Double(required)),
            lastQualifyingDate: events.first?.date,
            nextRequiredAction: isCurrent ? nil : "Log \(required - total) more \(unitLabel)"
        )

        return (status, summary, warning, expiresAt, windowStart, windowEnd, detail)
    }

    private func landingEvents(
        from flights: [Flight],
        day: Bool,
        fullStopOnly: Bool
    ) -> [QualifyingEvent] {
        flights
            .sorted { $0.flightDate > $1.flightDate }
            .compactMap { flight -> QualifyingEvent? in
                let count: Int = if day {
                    fullStopOnly ? (flight.fullStopDayLandings > 0 ? flight.fullStopDayLandings : flight.dayLandings) : flight.dayLandings
                } else {
                    flight.fullStopNightLandings > 0 ? flight.fullStopNightLandings : flight.nightLandings
                }
                guard count > 0 else { return nil }
                return QualifyingEvent(
                    date: flight.flightDate,
                    description: "\(flight.departureICAO) → \(flight.arrivalICAO)",
                    flightSyncID: flight.syncMetadata?.syncID,
                    contribution: "\(count) landing(s)"
                )
            }
    }

    private func resolveStatus(
        isCurrent: Bool,
        expiresAt: Date?,
        leadDays: Int,
        hasData: Bool
    ) -> CurrencyStatus {
        if !hasData && !isCurrent { return .unknown }
        guard isCurrent else { return .expired }
        if let expiresAt {
            let days = CurrencyDateUtilities.daysUntil(expiresAt, from: referenceDate)
            if days <= leadDays { return .expiringSoon }
        }
        return .current
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Flight Filters

    static func qualifyingFlights(from flights: [Flight], pilot: PilotProfile) -> [Flight] {
        flights.filter { flight in
            guard flight.status == .finalized else { return false }
            guard !(flight.syncMetadata?.isSoftDeleted ?? false) else { return false }
            guard flight.pilot?.persistentModelID == pilot.persistentModelID else { return false }
            return true
        }
    }

    private func isSoleManipulator(_ flight: Flight) -> Bool {
        flight.role == .pic || flight.role == .solo
    }

    private func isPIC(_ flight: Flight) -> Bool {
        flight.role == .pic || flight.role == .solo || flight.picTime > 0
    }

    private func isInstrumentQualifyingRole(_ flight: Flight) -> Bool {
        switch flight.role {
        case .pic, .sic, .solo, .dualReceived, .safetyPilot: true
        default: false
        }
    }

    private func hasInstrumentActivity(_ flight: Flight) -> Bool {
        flight.actualInstrumentTime > 0
            || flight.simulatedInstrumentTime > 0
            || flight.conditions.contains(.actualInstrument)
            || flight.conditions.contains(.simulatedInstrument)
            || !(flight.approaches ?? []).isEmpty
    }

    private func matchesTypeRating(_ flight: Flight, designator: String) -> Bool {
        guard let aircraft = flight.aircraft else { return false }
        if designator.isEmpty { return aircraft.requiresTypeRating }
        let reg = aircraft.typeDesignator?.uppercased() ?? ""
        let makeModel = "\(aircraft.make) \(aircraft.model)".uppercased()
        return reg == designator.uppercased() || makeModel.contains(designator.uppercased())
    }
}