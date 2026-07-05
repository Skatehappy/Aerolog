import SwiftUI

struct FlightTrainingSection: View {
    @Bindable var flight: Flight

    var body: some View {
        Section {
            TextField("Lesson Title", text: Binding(
                get: { flight.lessonTitle ?? "" },
                set: { flight.lessonTitle = $0.isEmpty ? nil : $0 }
            ))
            TextField("Lesson Number", text: Binding(
                get: { flight.lessonNumber ?? "" },
                set: { flight.lessonNumber = $0.isEmpty ? nil : $0 }
            ))
            TextField("Maneuvers Practiced", text: Binding(
                get: { flight.maneuversPracticed ?? "" },
                set: { flight.maneuversPracticed = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(2...4)

            TextField("Instructor Name", text: Binding(
                get: { flight.instructorName ?? "" },
                set: { flight.instructorName = $0.isEmpty ? nil : $0 }
            ))
            TextField("Instructor Certificate #", text: Binding(
                get: { flight.instructorCertificateNumber ?? "" },
                set: { flight.instructorCertificateNumber = $0.isEmpty ? nil : $0 }
            ))
            .textInputAutocapitalization(.characters)
        } header: {
            FormSectionHeader(title: "Training", subtitle: "Lesson and instructor details", systemImage: "graduationcap")
        }
    }
}