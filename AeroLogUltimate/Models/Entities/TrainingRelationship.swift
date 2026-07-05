import Foundation
import SwiftData

/// Links a CFI to a student for training management and lesson tracking.
@Model
final class TrainingRelationship {
    var status: TrainingRelationshipStatus
    var goal: TrainingGoal
    var customGoalDescription: String?

    var startDate: Date
    var endDate: Date?
    var expectedCompletionDate: Date?

    var syllabusName: String?
    var syllabusVersion: String?
    var currentLessonNumber: String?

    var notes: String?

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    @Relationship(deleteRule: .nullify)
    var instructor: PilotProfile?

    @Relationship(deleteRule: .nullify)
    var student: PilotProfile?

    @Relationship(deleteRule: .nullify, inverse: \Flight.studentRelationship)
    var flights: [Flight]?

    init(
        status: TrainingRelationshipStatus = .active,
        goal: TrainingGoal = .privatePilot,
        startDate: Date = .now
    ) {
        self.status = status
        self.goal = goal
        self.startDate = startDate
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    var isActive: Bool { status == .active }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}