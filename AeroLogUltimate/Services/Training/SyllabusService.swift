import Foundation
import SwiftData

/// CRUD for custom syllabi and lesson management.
@MainActor
struct SyllabusService {
    let dataStore: DataStore

    func allCustomSyllabi() throws -> [Syllabus] {
        let descriptor = FetchDescriptor<Syllabus>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try dataStore.fetch(descriptor)
    }

    func customSyllabi(for owner: PilotProfile) throws -> [Syllabus] {
        try allCustomSyllabi().filter {
            $0.owner?.persistentModelID == owner.persistentModelID
        }
    }

    @discardableResult
    func createCustom(
        name: String,
        goal: TrainingGoal,
        owner: PilotProfile?,
        version: String = "1.0"
    ) throws -> Syllabus {
        let syllabus = Syllabus(name: name, goal: goal, version: version)
        syllabus.owner = owner
        dataStore.insert(syllabus)
        try dataStore.save()
        return syllabus
    }

    @discardableResult
    func addLesson(
        to syllabus: Syllabus,
        lessonNumber: String,
        title: String,
        objectives: String? = nil,
        maneuvers: String? = nil,
        groundTopics: String? = nil,
        estimatedDualHours: Double = 1.0
    ) throws -> SyllabusLesson {
        let order = syllabus.sortedLessons.count
        let lesson = SyllabusLesson(
            lessonNumber: lessonNumber,
            title: title,
            sortOrder: order,
            estimatedDualHours: estimatedDualHours
        )
        lesson.objectives = objectives
        lesson.maneuvers = maneuvers
        lesson.groundTopics = groundTopics
        lesson.syllabus = syllabus
        dataStore.insert(lesson)
        syllabus.touch()
        try dataStore.save()
        return lesson
    }

    func save(_ syllabus: Syllabus) throws {
        syllabus.touch()
        try dataStore.save()
    }

    func delete(_ syllabus: Syllabus) throws {
        dataStore.delete(syllabus)
        try dataStore.save()
    }

    func builtInDefinitions() -> [SyllabusDefinition] {
        SyllabusCatalog.all
    }
}