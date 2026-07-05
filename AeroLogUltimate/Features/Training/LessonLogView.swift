import SwiftUI

/// Quick lesson logging for flight or ground instruction.
struct LessonLogView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    enum Mode { case flight, ground }

    let relationship: TrainingRelationship
    let mode: Mode

    @State private var selectedLessonNumber: String?
    @State private var lessons: [ResolvedLesson] = []
    @State private var groundDuration: Double = 1.0
    @State private var createdFlightID: UUID?
    @State private var showFlightEditor = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Student") {
                Text(relationship.student?.fullName ?? "Unknown")
                Text(relationship.goal.displayName)
                    .foregroundStyle(.secondary)
            }
            Section("Lesson") {
                Picker("Select Lesson", selection: $selectedLessonNumber) {
                    Text("General / No Lesson").tag(nil as String?)
                    ForEach(lessons, id: \.lessonNumber) { lesson in
                        Text("\(lesson.lessonNumber). \(lesson.title)").tag(lesson.lessonNumber as String?)
                    }
                }
                if let lesson = selectedLesson {
                    Text(lesson.objectives)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if mode == .ground {
                Section("Ground Time") {
                    DecimalHourField(label: "Duration", value: $groundDuration)
                }
            }
            Section {
                Button(mode == .flight ? "Create Flight Lesson" : "Log Ground Instruction") {
                    createLesson()
                }
                .fontWeight(.semibold)
            }
        }
        .navigationTitle(mode == .flight ? "Flight Lesson" : "Ground Instruction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showFlightEditor) {
            if let flight = try? environment?.flightService.flight(syncID: createdFlightID ?? UUID()) {
                NavigationStack {
                    FlightEditorView(flight: flight)
                }
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
            lessons = environment?.trainingService.resolvedLessons(for: relationship) ?? []
            selectedLessonNumber = relationship.currentLessonNumber ?? lessons.first?.lessonNumber
        }
    }

    private var selectedLesson: ResolvedLesson? {
        guard let num = selectedLessonNumber else { return nil }
        return lessons.first { $0.lessonNumber == num }
    }

    private func createLesson() {
        guard let service = environment?.trainingService else { return }
        do {
            let flight: Flight
            if mode == .flight {
                flight = try service.createFlightLessonDraft(
                    for: relationship,
                    lesson: selectedLesson
                )
            } else {
                flight = try service.createGroundLessonDraft(
                    for: relationship,
                    lesson: selectedLesson,
                    duration: groundDuration
                )
            }
            createdFlightID = flight.syncID
            if mode == .flight {
                showFlightEditor = true
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}