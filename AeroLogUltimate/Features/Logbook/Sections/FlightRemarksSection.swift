import SwiftUI

struct FlightRemarksSection: View {
    @Bindable var flight: Flight

    var body: some View {
        Section {
            TextField("Flight remarks, notes, endorsements referenced...", text: Binding(
                get: { flight.remarks ?? "" },
                set: { flight.remarks = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(4...12)
        } header: {
            FormSectionHeader(title: "Remarks", systemImage: "text.alignleft")
        }
    }
}