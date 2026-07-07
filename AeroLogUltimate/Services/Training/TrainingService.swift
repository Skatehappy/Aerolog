import Foundation
import SwiftData

/// CFI training management: students, relationships, lesson logging, and progress.
@MainActor
final class TrainingService {
    let dataStore: DataStore
    private let engine = TrainingProgressEngine()

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    // MARK: - Queries

    func allRelationships() throws -> [TrainingRelationship] {
        let descriptor = FetchDescriptor<TrainingRelationship>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try dataStore.fetch(descriptor)
    }

    func activeRelationships(for instructor: PilotProfile) throws -> [TrainingRelationship] {
        try allRelationships().filter {
            $0.status == .active
                && $0.instructor?.persistentModelID == instructor.persistentModelID
        }
    }

    func relationship(syncID: UUID) throws -> TrainingRelationship? {
        try allRelationships().first { $0.syncMetadata?.syncID == syncID }
    }

    func flights(for relationship: TrainingRelationship) throws -> [Flight] {
        guard let student = relationship.student else { return [] }
        let descriptor = FetchDescriptor<Flight>(
            sortBy: [SortDescriptor(\.flightDate, order: .reverse)]
        )
        let all = try dataStore.fetch(descriptor)
        return all.filter { flight in
            guard !(flight.syncMetadata?.isSoftDeleted ?? false) else { return false }
            if flight.studentRelationship?.persistentModelID == relationship.persistentModelID {
                return true
            }
            if flight.pilot?.persistentModelID == student.persistentModelID {
                if flight.instructor?.persistentModelID == relationship.instructor?.persistentModelID {
                    return true
                }
                if relationship.instructor != nil && flight.dualReceived > 0 {
                    return true
                }
            }
            return false
        }
    }

    // MARK: - Dashboard

    func dashboard(for instructor: PilotProfile) throws -> TrainingDashboardSummary {
        let relationships = try activeRelationships(for: instructor)
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now

        var totalDual: Double = 0
        var totalGround: Double = 0
        var lessonsThisMonth = 0
        var recent: [RecentLessonEntry] = []
        var attention: [StudentAttentionItem] = []

        for relationship in relationships {
            let flights = try flights(for: relationship)
            let finalized = flights.filter { $0.status == .finalized }
            totalDual += finalized.reduce(0) { $0 + $1.dualReceived }
            totalGround += finalized.reduce(0) { $0 + $1.groundInstructionTime }
            lessonsThisMonth += finalized.filter { $0.flightDate >= monthStart }.count

            for flight in finalized.prefix(3) {
                recent.append(RecentLessonEntry(
                    id: flight.syncID,
                    date: flight.flightDate,
                    studentName: relationship.student?.fullName ?? "Unknown",
                    lessonTitle: flight.lessonTitle ?? "Lesson",
                    duration: flight.totalTime > 0 ? flight.totalTime : flight.groundInstructionTime,
                    isGround: flight.totalTime == 0 && flight.groundInstructionTime > 0
                ))
            }

            let readiness = engine.checkrideReadiness(relationship: relationship, flights: flights)
            if readiness.readinessScore >= 0.75 && readiness.readinessScore < 0.9 {
                attention.append(StudentAttentionItem(
                    relationshipID: relationship.syncID,
                    studentName: relationship.student?.fullName ?? "Unknown",
                    reason: "Approaching checkride readiness"
                ))
            } else if readiness.syllabusProgress < 0.25 && finalized.count >= 3 {
                attention.append(StudentAttentionItem(
                    relationshipID: relationship.syncID,
                    studentName: relationship.student?.fullName ?? "Unknown",
                    reason: "Syllabus progress behind schedule"
                ))
            }
        }

        recent.sort { $0.date > $1.date }

        return TrainingDashboardSummary(
            instructorName: instructor.fullName,
            activeStudentCount: relationships.count,
            totalDualGiven: totalDual,
            totalGroundGiven: totalGround,
            lessonsThisMonth: lessonsThisMonth,
            studentsNeedingAttention: Array(attention.prefix(5)),
            recentLessons: Array(recent.prefix(10))
        )
    }

    // MARK: - Student Management

    @discardableResult
    func createStudent(
        firstName: String,
        lastName: String,
        goal: TrainingGoal,
        instructor: PilotProfile,
        builtInSyllabusID: String? = nil,
        customSyllabus: Syllabus? = nil
    ) throws -> TrainingRelationship {
        guard instructor.isCFI else { throw TrainingServiceError.cfiRequired }

        let student = PilotProfile(firstName: firstName, lastName: lastName)
        dataStore.insert(student)

        let relationship = TrainingRelationship(status: .active, goal: goal)
        relationship.instructor = instructor
        relationship.student = student

        if let builtInSyllabusID, let definition = SyllabusCatalog.definition(id: builtInSyllabusID) {
            relationship.syllabusCatalogID = builtInSyllabusID
            relationship.syllabusName = definition.name
            relationship.syllabusVersion = definition.version
            relationship.currentLessonNumber = definition.lessons.first?.lessonNumber
        } else if let customSyllabus {
            relationship.customSyllabus = customSyllabus
            relationship.syllabusName = customSyllabus.name
            relationship.syllabusVersion = customSyllabus.version
            relationship.currentLessonNumber = customSyllabus.sortedLessons.first?.lessonNumber
        }

        dataStore.insert(relationship)
        try dataStore.save()
        return relationship
    }

    func updateRelationship(_ relationship: TrainingRelationship) throws {
        relationship.touch()
        try dataStore.save()
    }

    /// Updates an existing student's identity and training goal. Syllabus changes
    /// are handled separately (via assignSyllabus/assignCustomSyllabus) so a plain
    /// name/goal edit doesn't reset the student's current-lesson pointer.
    func updateStudent(
        _ relationship: TrainingRelationship,
        firstName: String,
        lastName: String,
        goal: TrainingGoal
    ) throws {
        relationship.student?.firstName = firstName.trimmingCharacters(in: .whitespaces)
        relationship.student?.lastName = lastName.trimmingCharacters(in: .whitespaces)
        relationship.student?.touch()
        relationship.goal = goal
        relationship.touch()
        try dataStore.save()
    }

    func assignSyllabus(
        _ relationship: TrainingRelationship,
        builtInID: String
    ) throws {
        guard let definition = SyllabusCatalog.definition(id: builtInID) else {
            throw TrainingServiceError.syllabusNotFound
        }
        relationship.syllabusCatalogID = builtInID
        relationship.customSyllabus = nil
        relationship.syllabusName = definition.name
        relationship.syllabusVersion = definition.version
        relationship.currentLessonNumber = definition.lessons.first?.lessonNumber
        try updateRelationship(relationship)
    }

    func assignCustomSyllabus(
        _ relationship: TrainingRelationship,
        syllabus: Syllabus
    ) throws {
        relationship.syllabusCatalogID = nil
        relationship.customSyllabus = syllabus
        relationship.syllabusName = syllabus.name
        relationship.syllabusVersion = syllabus.version
        relationship.currentLessonNumber = syllabus.sortedLessons.first?.lessonNumber
        try updateRelationship(relationship)
    }

    // MARK: - Lesson Logging

    @discardableResult
    func createFlightLessonDraft(
        for relationship: TrainingRelationship,
        lesson: ResolvedLesson?,
        date: Date = .now
    ) throws -> Flight {
        guard let student = relationship.student else {
            throw TrainingServiceError.studentRequired
        }
        guard let instructor = relationship.instructor else {
            throw TrainingServiceError.instructorRequired
        }

        let flight = Flight(flightDate: date, status: .draft, role: .dualReceived)
        flight.pilot = student
        flight.instructor = instructor
        flight.studentRelationship = relationship
        flight.instructorName = instructor.fullName
        flight.instructorCertificateNumber = instructor.cfiCertificateNumber

        if let lesson {
            flight.lessonTitle = lesson.title
            flight.lessonNumber = lesson.lessonNumber
            flight.maneuversPracticed = lesson.maneuvers.isEmpty ? nil : lesson.maneuvers
            relationship.currentLessonNumber = lesson.lessonNumber
        }

        dataStore.insert(flight)
        relationship.touch()
        try dataStore.save()
        return flight
    }

    @discardableResult
    func createGroundLessonDraft(
        for relationship: TrainingRelationship,
        lesson: ResolvedLesson?,
        duration: Double = 1.0,
        date: Date = .now
    ) throws -> Flight {
        guard let student = relationship.student else {
            throw TrainingServiceError.studentRequired
        }
        guard let instructor = relationship.instructor else {
            throw TrainingServiceError.instructorRequired
        }

        let flight = Flight(flightDate: date, status: .draft, role: .dualReceived)
        flight.pilot = student
        flight.instructor = instructor
        flight.studentRelationship = relationship
        flight.instructorName = instructor.fullName
        flight.instructorCertificateNumber = instructor.cfiCertificateNumber
        flight.groundInstructionTime = duration
        flight.totalTime = 0

        if let lesson {
            flight.lessonTitle = lesson.title
            flight.lessonNumber = lesson.lessonNumber
            flight.maneuversPracticed = lesson.groundTopics.isEmpty ? nil : lesson.groundTopics
            relationship.currentLessonNumber = lesson.lessonNumber
        }

        dataStore.insert(flight)
        relationship.touch()
        try dataStore.save()
        return flight
    }

    // MARK: - Progress

    func studentSummary(for relationship: TrainingRelationship) throws -> StudentTrainingSummary {
        let flights = try flights(for: relationship)
        let endorsementCount = try endorsementCount(for: relationship)
        return engine.studentSummary(
            relationship: relationship,
            flights: flights,
            endorsementCount: endorsementCount
        )
    }

    func lessonProgress(for relationship: TrainingRelationship) throws -> [LessonProgressItem] {
        let flights = try flights(for: relationship)
        return engine.lessonProgress(relationship: relationship, flights: flights)
    }

    func checkrideReadiness(for relationship: TrainingRelationship) throws -> CheckrideReadinessReport {
        let flights = try flights(for: relationship)
        return engine.checkrideReadiness(relationship: relationship, flights: flights)
    }

    func resolvedLessons(for relationship: TrainingRelationship) -> [ResolvedLesson] {
        engine.resolvedLessons(for: relationship)
    }

    // MARK: - Helpers

    private func endorsementCount(for relationship: TrainingRelationship) throws -> Int {
        guard let student = relationship.student else { return 0 }
        let descriptor = FetchDescriptor<Endorsement>()
        let all = try dataStore.fetch(descriptor)
        return all.filter {
            !($0.syncMetadata?.isSoftDeleted ?? false)
                && $0.student?.persistentModelID == student.persistentModelID
        }.count
    }

    private func resolvedPilot(_ pilot: PilotProfile?) throws -> PilotProfile {
        if let pilot { return pilot }
        guard let profile = try dataStore.primaryPilotProfile() else {
            throw TrainingServiceError.pilotRequired
        }
        return profile
    }

    func requireCFI(_ pilot: PilotProfile? = nil) throws -> PilotProfile {
        let profile = try resolvedPilot(pilot)
        guard profile.isCFI else { throw TrainingServiceError.cfiRequired }
        return profile
    }
}

enum TrainingServiceError: LocalizedError {
    case cfiRequired
    case pilotRequired
    case studentRequired
    case instructorRequired
    case syllabusNotFound

    var errorDescription: String? {
        switch self {
        case .cfiRequired: "Training features require a CFI profile. Enable CFI in your pilot profile."
        case .pilotRequired: "Set up a pilot profile before using training features."
        case .studentRequired: "This training relationship has no linked student."
        case .instructorRequired: "This training relationship has no linked instructor."
        case .syllabusNotFound: "The selected syllabus could not be found."
        }
    }
}

extension TrainingRelationship {
    var syncID: UUID {
        syncMetadata?.syncID ?? UUID()
    }
}