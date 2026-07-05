import SwiftUI

struct FlightRouteSection: View {
    @Bindable var flight: Flight
    @Binding var useMultiLeg: Bool
    var onEnableMultiLeg: () -> Void

    var body: some View {
        Section {
            if !useMultiLeg {
                ICAOTextField(label: "Departure", text: $flight.departureICAO)
                ICAOTextField(label: "Arrival", text: $flight.arrivalICAO)
                HStack {
                    Text("Route")
                    Spacer()
                    TextField("VIA", text: Binding(
                        get: { flight.route ?? "" },
                        set: { flight.route = $0.isEmpty ? nil : $0 }
                    ))
                    .multilineTextAlignment(.trailing)
                }
            }

            Toggle("Multi-Leg Flight", isOn: $useMultiLeg)
                .onChange(of: useMultiLeg) { _, enabled in
                    if enabled && (flight.legs?.count ?? 0) == 0 {
                        onEnableMultiLeg()
                    }
                }
        } header: {
            FormSectionHeader(title: "Route", systemImage: "map")
        }
    }
}