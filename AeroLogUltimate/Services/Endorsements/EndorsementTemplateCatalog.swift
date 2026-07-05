import Foundation

/// Pre-loaded FAA endorsement template definition (AC 61-65H style).
struct EndorsementTemplateDefinition: Identifiable, Sendable {
    let id: EndorsementTemplateID
    let title: String
    let regulationReference: String
    let bodyText: String
    let placeholders: [String]

    var displayName: String { title }

    func renderedText(values: [String: String]) -> String {
        var text = bodyText
        for (key, value) in values {
            text = text.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return text
    }
}

/// Built-in endorsement template library.
enum EndorsementTemplateCatalog {
    static let all: [EndorsementTemplateDefinition] = [
        EndorsementTemplateDefinition(
            id: .preSoloAeronauticalKnowledge,
            title: "Pre-Solo Aeronautical Knowledge",
            regulationReference: "61.87(b)",
            bodyText: """
            I certify that {{student_name}} has received the required pre-solo flight training on the applicable maneuvers and procedures and has demonstrated satisfactory aeronautical knowledge on a knowledge test covering the applicable sections of 14 CFR part 61 and the aircraft to be flown.
            """,
            placeholders: ["student_name"]
        ),
        EndorsementTemplateDefinition(
            id: .preSoloFlightTraining,
            title: "Pre-Solo Flight Training",
            regulationReference: "61.87(c)",
            bodyText: """
            I certify that {{student_name}} has received the required pre-solo flight training for a {{aircraft_make_model}} aircraft and has demonstrated satisfactory proficiency and safety on the maneuvers and procedures required by 61.87(c).
            """,
            placeholders: ["student_name", "aircraft_make_model"]
        ),
        EndorsementTemplateDefinition(
            id: .soloFlight,
            title: "Solo Flight",
            regulationReference: "61.87(n)",
            bodyText: """
            I certify that {{student_name}} has received the required training to qualify for solo flying. I have determined that {{student_name}} meets the applicable requirements of 61.87(n) and is proficient to make solo flights in a {{aircraft_make_model}} aircraft.
            """,
            placeholders: ["student_name", "aircraft_make_model"]
        ),
        EndorsementTemplateDefinition(
            id: .soloCrossCountry,
            title: "Solo Cross-Country",
            regulationReference: "61.93(c)(1)-(2)",
            bodyText: """
            I certify that {{student_name}} has received the required solo cross-country training. I find that {{student_name}} has met the applicable requirements of 61.93 and is proficient to make solo cross-country flights in a {{aircraft_make_model}} aircraft.
            """,
            placeholders: ["student_name", "aircraft_make_model"]
        ),
        EndorsementTemplateDefinition(
            id: .crossCountry,
            title: "Cross-Country Training",
            regulationReference: "61.93",
            bodyText: """
            I certify that {{student_name}} has received the required cross-country flight training in a {{aircraft_make_model}} aircraft. I have reviewed the cross-country planning and find the preparation satisfactory.
            """,
            placeholders: ["student_name", "aircraft_make_model"]
        ),
        EndorsementTemplateDefinition(
            id: .nightSolo,
            title: "Night Solo",
            regulationReference: "61.87(o)",
            bodyText: """
            I certify that {{student_name}} has received the required training to qualify for solo night flying. I have determined that {{student_name}} meets the applicable requirements of 61.87(o) and is proficient to make solo night flights in a {{aircraft_make_model}} aircraft.
            """,
            placeholders: ["student_name", "aircraft_make_model"]
        ),
        EndorsementTemplateDefinition(
            id: .complexAircraft,
            title: "Complex Aircraft",
            regulationReference: "61.31(e)",
            bodyText: """
            I certify that {{student_name}} has received the required training in a complex airplane. I have determined that {{student_name}} is proficient in the operation and systems of a complex airplane.
            """,
            placeholders: ["student_name"]
        ),
        EndorsementTemplateDefinition(
            id: .highPerformance,
            title: "High Performance Aircraft",
            regulationReference: "61.31(f)",
            bodyText: """
            I certify that {{student_name}} has received the required training in a high-performance airplane. I have determined that {{student_name}} is proficient in the operation and systems of a high-performance airplane.
            """,
            placeholders: ["student_name"]
        ),
        EndorsementTemplateDefinition(
            id: .tailwheel,
            title: "Tailwheel Aircraft",
            regulationReference: "61.31(i)",
            bodyText: """
            I certify that {{student_name}} has received the required training in a tailwheel airplane. I have determined that {{student_name}} is proficient in the operation of a tailwheel airplane.
            """,
            placeholders: ["student_name"]
        ),
        EndorsementTemplateDefinition(
            id: .highAltitude,
            title: "High Altitude / Pressurized",
            regulationReference: "61.31(g)",
            bodyText: """
            I certify that {{student_name}} has received the required training for high-altitude operations. I have determined that {{student_name}} is proficient in high-altitude operations.
            """,
            placeholders: ["student_name"]
        ),
        EndorsementTemplateDefinition(
            id: .flightReview,
            title: "Flight Review",
            regulationReference: "61.56(a)",
            bodyText: """
            I certify that {{student_name}} has satisfactorily completed a flight review of 61.56(a) on {{review_date}} and was given training in the areas required by 61.56(c).
            """,
            placeholders: ["student_name", "review_date"]
        ),
        EndorsementTemplateDefinition(
            id: .instrumentProficiency,
            title: "Instrument Proficiency Check",
            regulationReference: "61.57(d)",
            bodyText: """
            I certify that {{student_name}} has satisfactorily completed an instrument proficiency check in accordance with 61.57(d) on {{ipc_date}}.
            """,
            placeholders: ["student_name", "ipc_date"]
        )
    ]

    static func definition(for id: EndorsementTemplateID) -> EndorsementTemplateDefinition? {
        all.first { $0.id == id }
    }

    /// Default placeholder values from pilot/aircraft context.
    static func defaultValues(
        student: PilotProfile?,
        instructor: PilotProfile?,
        aircraft: Aircraft? = nil
    ) -> [String: String] {
        var values: [String: String] = [:]
        if let student { values["student_name"] = student.fullName }
        if let instructor { values["instructor_name"] = instructor.fullName }
        if let aircraft {
            values["aircraft_make_model"] = "\(aircraft.make) \(aircraft.model)"
            values["aircraft_registration"] = aircraft.registration
        }
        values["review_date"] = Date.now.formatted(date: .abbreviated, time: .omitted)
        values["ipc_date"] = Date.now.formatted(date: .abbreviated, time: .omitted)
        values["airport"] = ""
        return values
    }
}