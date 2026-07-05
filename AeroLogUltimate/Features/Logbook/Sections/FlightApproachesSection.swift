import SwiftUI

struct FlightApproachesSection: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable var flight: Flight

    var body: some View {
        Section {
            if (flight.approaches ?? []).isEmpty {
                Text("No approaches logged")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(flight.approaches ?? [], id: \.persistentModelID) { approach in
                    HStack {
                        Picker("Type", selection: Binding(
                            get: { approach.approachType },
                            set: { approach.approachType = $0 }
                        )) {
                            ForEach(ApproachType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()

                        TextField("Airport", text: Binding(
                            get: { approach.airportICAO ?? "" },
                            set: { approach.airportICAO = $0.isEmpty ? nil : $0.uppercased() }
                        ))
                        .frame(maxWidth: 80)
                        .textInputAutocapitalization(.characters)

                        Stepper("\(approach.approachCount)", value: Binding(
                            get: { approach.approachCount },
                            set: { approach.approachCount = $0 }
                        ), in: 1...10)
                        .labelsHidden()
                    }
                }
                .onDelete { indexSet in
                    let approaches = flight.approaches ?? []
                    for index in indexSet {
                        try? environment?.flightService.removeApproach(approaches[index], from: flight)
                    }
                }
            }

            Button {
                try? environment?.flightService.addApproach(to: flight)
            } label: {
                Label("Add Approach", systemImage: "plus.circle")
            }
        } header: {
            FormSectionHeader(title: "Instrument Approaches", systemImage: "arrow.down.to.line")
        }
    }
}