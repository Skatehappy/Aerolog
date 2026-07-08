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
    @State private var createdFlight: Flight?
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
        .sheet(item: $createdFlight) { flight in
            NavigationStack {
                FlightEditorView(flight: flight, isNew: true)
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
            if mode == .flight {
                // Flight lessons open the flight editor to finish the entry.
                createdFlight = flight
            } else {
                // H6 (owner override): a ground lesson isn't a flight — finalize it
                // directly so it adds to ground-school totals and closes, without
                // opening the flight editor. Ground-only entries are exempt from the
                // aircraft/airport requirements in FlightValidation.
                try environment?.flightService.finalize(flight)
                dismiss()
            }
            // Refresh the training dashboard (a separate column on iPad) so its
            // totals and Recent Lessons pick up the new lesson.
            NotificationCenter.default.post(name: .trainingDataChanged, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}