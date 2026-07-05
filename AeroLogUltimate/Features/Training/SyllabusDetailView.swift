import SwiftUI

/// Read-only view of a built-in syllabus definition.
struct SyllabusDetailView: View {
    let definition: SyllabusDefinition

    var body: some View {
        List {
            Section {
                LabeledContent("Goal", value: definition.goal.displayName)
                LabeledContent("Version", value: definition.version)
                LabeledContent("Lessons", value: "\(definition.lessons.count)")
            }
            Section("Lessons") {
                ForEach(definition.lessons) { lesson in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(lesson.lessonNumber). \(lesson.title)")
                            .font(.headline)
                        if !lesson.objectives.isEmpty {
                            Text(lesson.objectives)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            if !lesson.maneuvers.isEmpty {
                                Label(lesson.maneuvers, systemImage: "airplane")
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            Label(TimeFormatting.display(lesson.estimatedDualHours) + " hrs est.", systemImage: "clock")
                                .font(.caption2)
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(definition.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}