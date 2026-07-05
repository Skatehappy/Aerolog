import SwiftUI

struct FlightLegsSection: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable var flight: Flight

    var body: some View {
        Section {
            ForEach(flight.sortedLegs, id: \.persistentModelID) { leg in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leg \(leg.legOrder + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("From").font(.caption).foregroundStyle(.secondary)
                            TextField("DEP", text: Binding(
                                get: { leg.departureICAO },
                                set: { leg.departureICAO = $0.uppercased() }
                            ))
                            .textInputAutocapitalization(.characters)
                        }
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text("To").font(.caption).foregroundStyle(.secondary)
                            TextField("ARR", text: Binding(
                                get: { leg.arrivalICAO },
                                set: { leg.arrivalICAO = $0.uppercased() }
                            ))
                            .textInputAutocapitalization(.characters)
                        }
                    }

                    DecimalHourField(label: "Leg Time", value: Binding(
                        get: { leg.legTime },
                        set: { leg.legTime = $0 }
                    ))

                    TextField("Route segment (optional)", text: Binding(
                        get: { leg.routeSegment ?? "" },
                        set: { leg.routeSegment = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.caption)
                }
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                let legs = flight.sortedLegs
                for index in indexSet {
                    try? environment?.flightService.removeLeg(legs[index], from: flight)
                }
            }

            Button {
                try? environment?.flightService.addLeg(to: flight)
            } label: {
                Label("Add Leg", systemImage: "plus.circle")
            }

            if !flight.sortedLegs.isEmpty {
                Button("Sync Total from Legs") {
                    let total = flight.sortedLegs.reduce(0) { $0 + $1.legTime }
                    flight.totalTime = total
                    flight.syncRouteFromLegs()
                }
                .font(.caption)
            }
        } header: {
            FormSectionHeader(title: "Flight Legs", subtitle: "Multi-leg route segments", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
        }
    }
}