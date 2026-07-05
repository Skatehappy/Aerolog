import SwiftUI

/// Create or edit a custom training syllabus.
struct CustomSyllabusEditorView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    var existingSyllabus: Syllabus?

    @State private var name = ""
    @State private var goal: TrainingGoal = .privatePilot
    @State private var version = "1.0"
    @State private var notes = ""
    @State private var lessonNumber = ""
    @State private var lessonTitle = ""
    @State private var lessonObjectives = ""
    @State private var errorMessage: String?

    init(existingSyllabus: Syllabus? = nil) {
        self.existingSyllabus = existingSyllabus
    }

    var body: some View {
        Form {
            Section("Syllabus") {
                TextField("Name", text: $name)
                Picker("Goal", selection: $goal) {
                    ForEach(TrainingGoal.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
                TextField("Version", text: $version)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            if let syllabus = existingSyllabus {
                Section("Lessons (\(syllabus.sortedLessons.count))") {
                    ForEach(syllabus.sortedLessons, id: \.persistentModelID) { lesson in
                        Text("\(lesson.lessonNumber). \(lesson.title)")
                    }
                }
                Section("Add Lesson") {
                    TextField("Lesson Number", text: $lessonNumber)
                    TextField("Title", text: $lessonTitle)
                    TextField("Objectives", text: $lessonObjectives, axis: .vertical)
                        .lineLimit(2...3)
                    Button("Add Lesson") { addLesson(to: syllabus) }
                        .disabled(lessonNumber.isEmpty || lessonTitle.isEmpty)
                }
            }
            Section {
                Button(existingSyllabus == nil ? "Create Syllabus" : "Save Changes") {
                    save()
                }
                .fontWeight(.semibold)
                .disabled(name.isEmpty)
            }
        }
        .navigationTitle(existingSyllabus == nil ? "New Syllabus" : "Edit Syllabus")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            if let s = existingSyllabus {
                name = s.name
                goal = s.goal
                version = s.version
                notes = s.notes ?? ""
            }
        }
    }

    private func save() {
        guard let service = environment?.syllabusService else { return }
        do {
            if let existing = existingSyllabus {
                existing.name = name
                existing.goal = goal
                existing.version = version
                existing.notes = notes.isEmpty ? nil : notes
                try service.save(existing)
            } else {
                let owner = try environment?.pilotProfileService.primaryProfile()
                _ = try service.createCustom(name: name, goal: goal, owner: owner, version: version)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addLesson(to syllabus: Syllabus) {
        guard let service = environment?.syllabusService else { return }
        do {
            _ = try service.addLesson(
                to: syllabus,
                lessonNumber: lessonNumber,
                title: lessonTitle,
                objectives: lessonObjectives.isEmpty ? nil : lessonObjectives
            )
            lessonNumber = ""
            lessonTitle = ""
            lessonObjectives = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Detail view for a persisted custom syllabus.
struct CustomSyllabusDetailView: View {
    let syllabus: Syllabus

    var body: some View {
        List {
            Section {
                LabeledContent("Goal", value: syllabus.goal.displayName)
                LabeledContent("Version", value: syllabus.version)
                LabeledContent("Lessons", value: "\(syllabus.sortedLessons.count)")
            }
            Section("Lessons") {
                ForEach(syllabus.sortedLessons, id: \.persistentModelID) { lesson in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(lesson.lessonNumber). \(lesson.title)")
                            .font(.headline)
                        if let objectives = lesson.objectives, !objectives.isEmpty {
                            Text(objectives)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(syllabus.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CustomSyllabusEditorView(existingSyllabus: syllabus)
                } label: {
                    Text("Edit")
                }
            }
        }
    }
}