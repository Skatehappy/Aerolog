import Foundation
import SwiftData

/// A single lesson within a custom syllabus.
@Model
final class SyllabusLesson {
    var lessonNumber: String
    var title: String
    var objectives: String?
    var maneuvers: String?
    var groundTopics: String?
    var estimatedDualHours: Double
    var sortOrder: Int

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    @Relationship(deleteRule: .nullify)
    var syllabus: Syllabus?

    init(
        lessonNumber: String,
        title: String,
        sortOrder: Int = 0,
        estimatedDualHours: Double = 1.0
    ) {
        self.lessonNumber = lessonNumber
        self.title = title
        self.sortOrder = sortOrder
        self.estimatedDualHours = estimatedDualHours
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}