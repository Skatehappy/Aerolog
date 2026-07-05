import Foundation
import SwiftData

/// Custom training syllabus created by a CFI.
@Model
final class Syllabus {
    var name: String
    var goal: TrainingGoal
    var version: String
    var notes: String?
    var isFavorite: Bool

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    @Relationship(deleteRule: .nullify)
    var owner: PilotProfile?

    @Relationship(deleteRule: .cascade, inverse: \SyllabusLesson.syllabus)
    var lessons: [SyllabusLesson]?

    @Relationship(deleteRule: .nullify, inverse: \TrainingRelationship.customSyllabus)
    var relationships: [TrainingRelationship]?

    init(
        name: String,
        goal: TrainingGoal = .privatePilot,
        version: String = "1.0"
    ) {
        self.name = name
        self.goal = goal
        self.version = version
        self.isFavorite = false
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    var sortedLessons: [SyllabusLesson] {
        (lessons ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}