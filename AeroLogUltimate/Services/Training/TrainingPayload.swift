import Foundation

// MARK: - Dashboard

struct TrainingDashboardSummary: Sendable {
    let instructorName: String
    let activeStudentCount: Int
    let totalDualGiven: Double
    let totalGroundGiven: Double
    let lessonsThisMonth: Int
    let studentsNeedingAttention: [StudentAttentionItem]
    let recentLessons: [RecentLessonEntry]
}

struct StudentAttentionItem: Identifiable, Sendable {
    var id: UUID { relationshipID }
    let relationshipID: UUID
    let studentName: String
    let reason: String
}

struct RecentLessonEntry: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let studentName: String
    let lessonTitle: String
    let duration: Double
    let isGround: Bool
}

// MARK: - Student Summary

struct StudentTrainingSummary: Sendable {
    let relationshipID: UUID
    let studentName: String
    let goal: TrainingGoal
    let status: TrainingRelationshipStatus
    let syllabusName: String
    let startDate: Date
    let dualReceived: Double
    let soloTime: Double
    let groundInstruction: Double
    let flightLessonCount: Int
    let groundLessonCount: Int
    let lessonsCompleted: Int
    let lessonsTotal: Int
    let syllabusProgress: Double
    let currentLessonNumber: String?
    let lastLessonDate: Date?
    let lastLessonTitle: String?
    let endorsementCount: Int
}

// MARK: - Lesson Progress

struct LessonProgressItem: Identifiable, Sendable {
    var id: String { lessonNumber }
    let lessonNumber: String
    let title: String
    let isCompleted: Bool
    let completedDate: Date?
    let flightCount: Int
}

// MARK: - Checkride Readiness

struct RatingRequirement: Identifiable, Sendable {
    var id: String { label }
    let label: String
    let required: Double
    let actual: Double
    let unit: String

    var isMet: Bool { actual >= required }
    var progress: Double {
        guard required > 0 else { return 1 }
        return min(1, actual / required)
    }
}

struct CheckrideReadinessReport: Sendable {
    let studentName: String
    let goal: TrainingGoal
    let requirements: [RatingRequirement]
    let syllabusProgress: Double
    let lessonsCompleted: Int
    let lessonsTotal: Int
    let readinessScore: Double
    let isReady: Bool
    let recommendations: [String]
}

// MARK: - Lesson definitions (unified built-in + custom)

struct ResolvedLesson: Identifiable, Sendable {
    var id: String { lessonNumber }
    let lessonNumber: String
    let title: String
    let objectives: String
    let maneuvers: String
    let groundTopics: String
    let estimatedDualHours: Double
}