import Foundation

/// Static lesson definition within a built-in syllabus.
struct SyllabusLessonDefinition: Identifiable, Sendable {
    var id: String { lessonNumber }
    let lessonNumber: String
    let title: String
    let objectives: String
    let maneuvers: String
    let groundTopics: String
    let estimatedDualHours: Double
}

/// Static built-in syllabus definition.
struct SyllabusDefinition: Identifiable, Sendable {
    let id: String
    let name: String
    let goal: TrainingGoal
    let version: String
    let lessons: [SyllabusLessonDefinition]
}

/// Pre-loaded FAA Part 61 style training syllabi.
enum SyllabusCatalog {
    static let all: [SyllabusDefinition] = [privatePilot, instrumentRating, commercialPilot]

    static func definition(id: String) -> SyllabusDefinition? {
        all.first { $0.id == id }
    }

    static func definitions(for goal: TrainingGoal) -> [SyllabusDefinition] {
        all.filter { $0.goal == goal }
    }

    // MARK: - Private Pilot

    static let privatePilot = SyllabusDefinition(
        id: "ppl-part61",
        name: "Private Pilot — Part 61",
        goal: .privatePilot,
        version: "1.0",
        lessons: [
            lesson("1", "Introduction & Preflight", "Aircraft systems, preflight inspection, cockpit management", "Preflight, engine start, taxi", "Regulations, privileges, limitations", 1.5),
            lesson("2", "Straight & Level Flight", "Basic attitude control and trim", "Straight-and-level, pitch/power changes", "Four forces of flight", 1.0),
            lesson("3", "Climbs, Descents & Turns", "Coordinated flight fundamentals", "Climbs, descents, shallow/medium turns", "Aerodynamics, stall awareness intro", 1.5),
            lesson("4", "Slow Flight & Stalls", "Recognize and recover from stalls", "Slow flight, power-off/on stalls", "Stall aerodynamics, spin awareness", 1.5),
            lesson("5", "Ground Reference Maneuvers", "Wind correction and division of attention", "Rectangular, S-turns, turns around a point", "Wind drift, ground track", 1.5),
            lesson("6", "Traffic Pattern & Landings", "Normal takeoffs and landings", "Pattern entry, normal TO/LDG", "Airport operations, communications", 2.0),
            lesson("7", "Go-Around & Emergency Procedures", "Rejected landing and emergency flows", "Go-around, simulated engine failure", "Emergency checklists, ADM", 1.5),
            lesson("8", "Steep Turns", "45° steep turn proficiency", "Steep turns", "Load factor, coordination", 1.0),
            lesson("9", "Solo Preparation", "Pre-solo knowledge and maneuvers review", "Maneuver review, pattern practice", "Pre-solo knowledge test prep", 1.5),
            lesson("10", "First Solo", "Supervised solo pattern work", "Supervised solo", "Solo responsibilities", 1.0),
            lesson("11", "Solo Practice", "Build solo proficiency", "Solo pattern and maneuvers", "Risk management solo", 2.0),
            lesson("12", "Cross-Country Planning", "VFR cross-country planning", "Dual XC planning flight", "Weather, nav log, FAR 91.103", 2.0),
            lesson("13", "Solo Cross-Country", "Solo cross-country experience", "Solo XC", "XC decision making", 3.0),
            lesson("14", "Night Operations", "Night flying fundamentals", "Night takeoff, landing, pattern", "Night physiology, lighting", 2.0),
            lesson("15", "Checkride Preparation", "ACS maneuver review and oral prep", "Oral review, maneuver polish", "ACS standards, checkride tips", 2.0)
        ]
    )

    // MARK: - Instrument Rating

    static let instrumentRating = SyllabusDefinition(
        id: "ir-part61",
        name: "Instrument Rating — Part 61",
        goal: .instrumentRating,
        version: "1.0",
        lessons: [
            lesson("1", "IFR Fundamentals", "IFR rules, charts, and cockpit setup", "Basic attitude instrument flying", "IFR regulations, clearances", 2.0),
            lesson("2", "Attitude Instrument Flying", "Control by reference to instruments", "Straight-and-level, climbs, descents, turns", "Instrument scan, partial panel", 2.0),
            lesson("3", "Holding Procedures", "Holding entry and timing", "Holding patterns", "Holding regulations, entries", 1.5),
            lesson("4", "VOR Navigation", "VOR tracking and intercepts", "VOR approaches, tracking", "VOR theory, CDI interpretation", 2.0),
            lesson("5", "GPS/RNAV Procedures", "GPS and RNAV approach procedures", "RNAV approaches", "GPS WAAS, RAIM", 2.0),
            lesson("6", "ILS Approaches", "Precision approach procedures", "ILS approaches", "ILS components, minimums", 2.0),
            lesson("7", "Non-Precision Approaches", "Non-precision approach procedures", "LOC, VOR, LNAV approaches", "MDA, VDP, missed approach", 2.0),
            lesson("8", "Circling & Missed Approaches", "Circling and missed approach procedures", "Circling, missed approaches", "Circling minimums, lost comm", 2.0),
            lesson("9", "Partial Panel & Unusual Attitudes", "Partial panel and unusual attitude recovery", "Partial panel, unusual attitudes", "Failure modes, recovery", 1.5),
            lesson("10", "IFR Cross-Country", "IFR cross-country procedures", "IFR XC flight", "Flight planning, alternates", 3.0),
            lesson("11", "Checkride Preparation", "ACS IFR maneuver and oral review", "Maneuver polish", "Oral exam topics", 2.0)
        ]
    )

    // MARK: - Commercial Pilot

    static let commercialPilot = SyllabusDefinition(
        id: "cpl-part61",
        name: "Commercial Pilot — Part 61",
        goal: .commercialPilot,
        version: "1.0",
        lessons: [
            lesson("1", "Commercial Standards Overview", "Commercial ACS standards and privileges", "Maneuver assessment baseline", "Commercial privileges, responsibilities", 1.5),
            lesson("2", "Chandelles & Lazy Eights", "Complex maneuver proficiency", "Chandelles, lazy eights", "Energy management", 2.0),
            lesson("3", "Steep Spirals & Eights on Pylons", "Advanced ground reference", "Steep spirals, eights on pylons", "Pylon geometry, wind correction", 2.0),
            lesson("4", "Emergency Operations", "Advanced emergency procedures", "Engine failure, emergency landings", "Risk management, ADM", 2.0),
            lesson("5", "High-Performance Operations", "High-performance aircraft operations", "HP aircraft checkout maneuvers", "Systems, performance", 2.0),
            lesson("6", "Complex Aircraft", "Complex aircraft operations", "Complex aircraft maneuvers", "Retractable gear, flaps, prop", 2.0),
            lesson("7", "Commercial XC Planning", "Long cross-country planning", "Dual commercial XC", "Weather, fuel, alternates", 3.0),
            lesson("8", "Night Commercial Operations", "Night commercial operations", "Night XC and maneuvers", "Night risk management", 2.0),
            lesson("9", "Checkride Preparation", "Commercial ACS review", "Maneuver polish", "Oral exam preparation", 2.0)
        ]
    )

    private static func lesson(
        _ number: String,
        _ title: String,
        _ objectives: String,
        _ maneuvers: String,
        _ ground: String,
        _ hours: Double
    ) -> SyllabusLessonDefinition {
        SyllabusLessonDefinition(
            lessonNumber: number,
            title: title,
            objectives: objectives,
            maneuvers: maneuvers,
            groundTopics: ground,
            estimatedDualHours: hours
        )
    }
}