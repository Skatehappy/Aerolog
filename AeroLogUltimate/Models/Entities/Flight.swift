import Foundation
import SwiftData

/// Primary logbook entry representing a flight, simulator session, or ground lesson.
@Model
final class Flight {
    // MARK: Core

    var flightDate: Date
    var status: FlightStatus
    var role: FlightRole

    // MARK: Route (single-leg summary; multi-leg detail in `legs`)

    var departureICAO: String
    var arrivalICAO: String
    var route: String?

    // MARK: Time Breakdown (decimal hours unless noted)

    var totalTime: Double
    var picTime: Double
    var sicTime: Double
    var dualReceived: Double
    var dualGiven: Double
    var soloTime: Double
    var crossCountryTime: Double
    var nightTime: Double
    var actualInstrumentTime: Double
    var simulatedInstrumentTime: Double
    var groundInstructionTime: Double
    var simulatorTime: Double

    // MARK: Landings & Holds

    var dayLandings: Int
    var nightLandings: Int
    var fullStopDayLandings: Int
    var fullStopNightLandings: Int
    var holds: Int

    // MARK: Conditions

    var conditionsRaw: [String]

    // MARK: Hobbs / Tach

    var hobbsStart: Double?
    var hobbsEnd: Double?
    var tachStart: Double?
    var tachEnd: Double?

    // MARK: Fuel

    var fuelAdded: Double?
    var fuelBurn: Double?
    var fuelRemaining: Double?
    var fuelUnit: FuelUnit

    // MARK: Training Context

    var lessonTitle: String?
    var lessonNumber: String?
    var maneuversPracticed: String?

    // MARK: Instructor of Record (denormalized for logbook export)

    var instructorName: String?
    var instructorCertificateNumber: String?

    // MARK: Notes & Metadata

    var remarks: String?
    var isPinned: Bool
    var isFavorite: Bool
    var externalID: String?

    // MARK: Audit

    var createdAt: Date
    var updatedAt: Date
    var finalizedAt: Date?
    /// JSON array of `FlightEditRecord` — append-only trail when finalized entries change.
    var editHistoryJSON: String?

    // MARK: Sync

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    // MARK: Relationships

    @Relationship(deleteRule: .nullify)
    var pilot: PilotProfile?

    @Relationship(deleteRule: .nullify)
    var instructor: PilotProfile?

    @Relationship(deleteRule: .nullify)
    var aircraft: Aircraft?

    @Relationship(deleteRule: .nullify)
    var studentRelationship: TrainingRelationship?

    @Relationship(deleteRule: .cascade, inverse: \FlightLeg.flight)
    var legs: [FlightLeg]?

    @Relationship(deleteRule: .cascade, inverse: \InstrumentApproach.flight)
    var approaches: [InstrumentApproach]?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.flight)
    var attachments: [Attachment]?

    @Relationship(deleteRule: .cascade, inverse: \WeightBalanceLog.flight)
    var weightBalanceLog: WeightBalanceLog?

    @Relationship(deleteRule: .cascade, inverse: \FlightExpense.flight)
    var expenses: [FlightExpense]?

    // MARK: Computed

    var conditions: [FlightCondition] {
        conditionsRaw.compactMap { FlightCondition(rawValue: $0) }
    }

    var isDraft: Bool { status == .draft }
    var isFinalized: Bool { status == .finalized }

    /// M1: total instrument approaches flown — the sum of each record's
    /// approachCount, NOT the number of records. One "3× ILS" record = 3.
    /// Single source of truth so reports and the currency engine agree.
    var totalApproachCount: Int {
        (approaches ?? []).reduce(0) { $0 + $1.approachCount }
    }

    var hobbsTime: Double? {
        guard let start = hobbsStart, let end = hobbsEnd, end >= start else { return nil }
        return end - start
    }

    var tachTime: Double? {
        guard let start = tachStart, let end = tachEnd, end >= start else { return nil }
        return end - start
    }

    var computedFuelBurn: Double? {
        if let burn = fuelBurn { return burn }
        guard let added = fuelAdded, let remaining = fuelRemaining, added >= remaining else { return nil }
        return added - remaining
    }

    var totalExpenses: Double {
        (expenses ?? []).reduce(0) { $0 + $1.amount }
    }

    // MARK: Init

    init(
        flightDate: Date = .now,
        status: FlightStatus = .draft,
        role: FlightRole = .pic
    ) {
        self.flightDate = flightDate
        self.status = status
        self.role = role
        self.departureICAO = ""
        self.arrivalICAO = ""
        self.totalTime = 0
        self.picTime = 0
        self.sicTime = 0
        self.dualReceived = 0
        self.dualGiven = 0
        self.soloTime = 0
        self.crossCountryTime = 0
        self.nightTime = 0
        self.actualInstrumentTime = 0
        self.simulatedInstrumentTime = 0
        self.groundInstructionTime = 0
        self.simulatorTime = 0
        self.dayLandings = 0
        self.nightLandings = 0
        self.fullStopDayLandings = 0
        self.fullStopNightLandings = 0
        self.holds = 0
        self.conditionsRaw = []
        self.fuelUnit = .gallons
        self.isPinned = false
        self.isFavorite = false
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    // MARK: Mutations

    func setConditions(_ conditions: [FlightCondition]) {
        conditionsRaw = conditions.map(\.rawValue)
        touch()
    }

    func finalize() {
        status = .finalized
        finalizedAt = .now
        touch()
    }

    func revertToDraft() {
        recordEditHistory(action: "Reverted to draft")
        status = .draft
        finalizedAt = nil
        touch()
    }

    func recordEditHistory(action: String) {
        guard status == .finalized || finalizedAt != nil else { return }
        editHistoryJSON = FlightEditHistory.append(
            action: action,
            previousStatus: status.rawValue,
            to: editHistoryJSON
        )
    }

    var editHistory: [FlightEditRecord] {
        FlightEditHistory.decode(from: editHistoryJSON)
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}