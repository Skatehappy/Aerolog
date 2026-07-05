import SwiftUI

struct FlightFuelSection: View {
    @Bindable var flight: Flight
    let aircraft: Aircraft?

    private var unitLabel: String {
        flight.fuelUnit == .gallons ? "gal" : "L"
    }

    var body: some View {
        Section {
            Picker("Fuel Unit", selection: $flight.fuelUnit) {
                Text("Gallons").tag(FuelUnit.gallons)
                Text("Liters").tag(FuelUnit.liters)
            }

            fuelField("Fuel Added", value: $flight.fuelAdded)
            fuelField("Fuel Remaining", value: $flight.fuelRemaining)
            fuelField("Fuel Burn (manual)", value: $flight.fuelBurn)

            if let burn = flight.computedFuelBurn {
                HStack {
                    Text("Computed Burn")
                    Spacer()
                    Text(String(format: "%.1f %@", burn, unitLabel))
                        .foregroundStyle(.secondary)
                }
            }

            if let defaultBurn = aircraft?.defaultFuelBurnGPH, flight.totalTime > 0 {
                let estimated = defaultBurn * flight.totalTime
                HStack {
                    Text("Est. from aircraft profile")
                    Spacer()
                    Text(String(format: "%.1f %@/hr", defaultBurn, unitLabel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("~\(String(format: "%.1f", estimated)) \(unitLabel) for this flight")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } header: {
            FormSectionHeader(title: "Fuel", systemImage: "fuelpump")
        }
    }

    @ViewBuilder
    private func fuelField(_ title: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0.0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            Text(unitLabel)
                .foregroundStyle(.secondary)
        }
    }
}