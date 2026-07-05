import SwiftUI

struct FlightRemarksSection: View {
    @Bindable var flight: Flight
    @State private var showPencilNotes = false

    var body: some View {
        Section {
            TextField("Flight remarks, notes, endorsements referenced...", text: Binding(
                get: { flight.remarks ?? "" },
                set: { flight.remarks = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(4...12)

            Button {
                showPencilNotes = true
            } label: {
                Label("Add Pencil Notes", systemImage: "pencil.and.scribble")
            }
        } header: {
            FormSectionHeader(title: "Remarks", systemImage: "text.alignleft")
        }
        .sheet(isPresented: $showPencilNotes) {
            PencilNotesSheet(remarks: Binding(
                get: { flight.remarks },
                set: { flight.remarks = $0 }
            ))
        }
    }
}