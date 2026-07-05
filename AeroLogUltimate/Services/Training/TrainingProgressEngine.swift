import Foundation

/// Calculates student progress, syllabus completion, and checkride readiness.
struct TrainingProgressEngine: Sendable {
    func resolvedLessons(for relationship: TrainingRelationship) -> [ResolvedLesson] {
        if let catalogID = relationship.syllabusCatalogID,
           let definition = SyllabusCatalog.definition(id: catalogID) {
            return definition.lessons.map {
                ResolvedLesson(
                    lessonNumber: $0.lessonNumber,
                    title: $0.title,
                    objectives: $0.objectives,
                    maneuvers: $0.maneuvers,
                    groundTopics: $0.groundTopics,
                    estimatedDualHours: $0.estimatedDualHours
                )
            }
        }
        if let custom = relationship.customSyllabus {
            return custom.sortedLessons.map {
                ResolvedLesson(
                    lessonNumber: $0.lessonNumber,
                    title: $0.title,
                    objectives: $0.objectives ?? "",
                    maneuvers: $0.maneuvers ?? "",
                    groundTopics: $0.groundTopics ?? "",
                    estimatedDualHours: $0.estimatedDualHours
                )
            }
        }
        return []
    }

    func lessonProgress(
        relationship: TrainingRelationship,
        flights: [Flight]
    ) -> [LessonProgressItem] {
        let lessons = resolvedLessons(for: relationship)
        return lessons.map { lesson in
            let matching = flights.filter { $0.lessonNumber == lesson.lessonNumber && $0.status == .finalized }
            return LessonProgressItem(
                lessonNumber: lesson.lessonNumber,
                title: lesson.title,
                isCompleted: !matching.isEmpty,
                completedDate: matching.map(\.flightDate).max(),
                flightCount: matching.count
            )
        }
    }

    func syllabusProgress(
        relationship: TrainingRelationship,
        flights: [Flight]
    ) -> (completed: Int, total: Int, fraction: Double) {
        let progress = lessonProgress(relationship: relationship, flights: flights)
        let total = progress.count
        let completed = progress.filter(\.isCompleted).count
        let fraction = total > 0 ? Double(completed) / Double(total) : 0
        return (completed, total, fraction)
    }

    func studentSummary(
        relationship: TrainingRelationship,
        flights: [Flight],
        endorsementCount: Int
    ) -> StudentTrainingSummary {
        let finalized = flights.filter { $0.status == .finalized }
        let syllabus = syllabusProgress(relationship: relationship, flights: finalized)
        let sorted = finalized.sorted { $0.flightDate > $1.flightDate }
        let last = sorted.first

        let flightLessons = finalized.filter { $0.groundInstructionTime == 0 || $0.totalTime > 0 }
        let groundLessons = finalized.filter { $0.groundInstructionTime > 0 && $0.totalTime == 0 }

        return StudentTrainingSummary(
            relationshipID: relationship.syncID,
            studentName: relationship.student?.fullName ?? "Unknown",
            goal: relationship.goal,
            status: relationship.status,
            syllabusName: relationship.syllabusName ?? "No Syllabus",
            startDate: relationship.startDate,
            dualReceived: finalized.reduce(0) { $0 + $1.dualReceived },
            soloTime: finalized.reduce(0) { $0 + $1.soloTime },
            groundInstruction: finalized.reduce(0) { $0 + $1.groundInstructionTime },
            flightLessonCount: flightLessons.count,
            groundLessonCount: groundLessons.count,
            lessonsCompleted: syllabus.completed,
            lessonsTotal: syllabus.total,
            syllabusProgress: syllabus.fraction,
            currentLessonNumber: relationship.currentLessonNumber,
            lastLessonDate: last?.flightDate,
            lastLessonTitle: last?.lessonTitle,
            endorsementCount: endorsementCount
        )
    }

    func checkrideReadiness(
        relationship: TrainingRelationship,
        flights: [Flight]
    ) -> CheckrideReadinessReport {
        let finalized = flights.filter { $0.status == .finalized }
        let syllabus = syllabusProgress(relationship: relationship, flights: finalized)
        let requirements = ratingRequirements(for: relationship.goal, flights: finalized)
        let metCount = requirements.filter(\.isMet).count
        let reqScore = requirements.isEmpty ? 1 : Double(metCount) / Double(requirements.count)
        let readinessScore = (reqScore * 0.6) + (syllabus.fraction * 0.4)
        let isReady = readinessScore >= 0.9 && requirements.allSatisfy(\.isMet)

        var recommendations: [String] = []
        for req in requirements where !req.isMet {
            let gap = req.required - req.actual
            recommendations.append("\(req.label): need \(format(req.unit == "hrs" ? gap : gap)) more \(req.unit)")
        }
        if syllabus.fraction < 0.8 {
            recommendations.append("Complete remaining syllabus lessons (\(syllabus.completed)/\(syllabus.total))")
        }
        if recommendations.isEmpty && !isReady {
            recommendations.append("Review ACS standards and schedule a stage check")
        }

        return CheckrideReadinessReport(
            studentName: relationship.student?.fullName ?? "Unknown",
            goal: relationship.goal,
            requirements: requirements,
            syllabusProgress: syllabus.fraction,
            lessonsCompleted: syllabus.completed,
            lessonsTotal: syllabus.total,
            readinessScore: readinessScore,
            isReady: isReady,
            recommendations: recommendations
        )
    }

    // MARK: - Rating Requirements (Part 61 simplified)

    private func ratingRequirements(for goal: TrainingGoal, flights: [Flight]) -> [RatingRequirement] {
        let total = flights.reduce(0) { $0 + $1.totalTime }
        let dual = flights.reduce(0) { $0 + $1.dualReceived }
        let solo = flights.reduce(0) { $0 + $1.soloTime }
        let xc = flights.reduce(0) { $0 + $1.crossCountryTime }
        let night = flights.reduce(0) { $0 + $1.nightTime }
        let instrument = flights.reduce(0) { $0 + $1.actualInstrumentTime + $1.simulatedInstrumentTime }
        let ground = flights.reduce(0) { $0 + $1.groundInstructionTime }

        switch goal {
        case .privatePilot:
            return [
                req("Total Time", 40, total),
                req("Dual Instruction", 20, dual),
                req("Solo Flight", 10, solo),
                req("Cross Country", 10, xc),
                req("Night", 3, night)
            ]
        case .instrumentRating:
            return [
                req("Total Time", 50, total),
                req("Cross Country", 10, xc),
                req("Instrument Time", 40, instrument),
                req("Dual Instruction", 15, dual)
            ]
        case .commercialPilot:
            return [
                req("Total Time", 250, total),
                req("PIC Time", 100, flights.reduce(0) { $0 + $1.picTime }),
                req("Cross Country", 50, xc),
                req("Night", 10, night),
                req("Dual Instruction", 20, dual)
            ]
        case .cfi:
            return [
                req("Total Time", 250, total),
                req("PIC Time", 100, flights.reduce(0) { $0 + $1.picTime }),
                req("Dual Given", 25, flights.reduce(0) { $0 + $1.dualGiven }),
                req("Ground Instruction", 25, ground)
            ]
        case .cfii:
            return [
                req("Total Time", 250, total),
                req("Instrument Time", 50, instrument),
                req("CFI Certificate", 1, 0, unit: "rating")
            ]
        case .multiEngine:
            return [
                req("Multi-Engine Time", 25, total),
                req("Dual Instruction", 10, dual)
            ]
        case .tailwheel:
            return [
                req("Tailwheel Time", 5, total),
                req("Dual Instruction", 3, dual)
            ]
        case .custom:
            return [
                req("Total Training Time", 10, total + ground),
                req("Dual Instruction", 5, dual)
            ]
        }
    }

    private func req(_ label: String, _ required: Double, _ actual: Double, unit: String = "hrs") -> RatingRequirement {
        RatingRequirement(label: label, required: required, actual: actual, unit: unit)
    }

    private func format(_ value: Double) -> String {
        TimeFormatting.display(value)
    }
}