import SwiftUI

struct FlightTimesSection: View {
    @Bindable var flight: Flight
    var isSimulator: Bool

    var body: some View {
        Section {
            DecimalHourField(label: "Total Time", value: $flight.totalTime)

            if isSimulator {
                DecimalHourField(label: "Simulator Time", value: $flight.simulatorTime)
                    .onChange(of: flight.simulatorTime) { _, val in
                        if val > 0 && flight.totalTime == 0 { flight.totalTime = val }
                    }
            }

            Group {
                DecimalHourField(label: "PIC", value: $flight.picTime)
                DecimalHourField(label: "SIC", value: $flight.sicTime)
                DecimalHourField(label: "Dual Received", value: $flight.dualReceived)
                DecimalHourField(label: "Dual Given", value: $flight.dualGiven)
                DecimalHourField(label: "Solo", value: $flight.soloTime)
            }

            Group {
                DecimalHourField(label: "Cross Country", value: $flight.crossCountryTime)
                DecimalHourField(label: "Night", value: $flight.nightTime)
                DecimalHourField(label: "Actual Instrument", value: $flight.actualInstrumentTime)
                DecimalHourField(label: "Simulated Instrument", value: $flight.simulatedInstrumentTime)
                DecimalHourField(label: "Ground Instruction", value: $flight.groundInstructionTime)
            }

            if !isSimulator {
                DecimalHourField(label: "Simulator Time", value: $flight.simulatorTime)
            }
        } header: {
            FormSectionHeader(
                title: "Time Breakdown",
                subtitle: "Decimal hours (e.g. 1.5 = 1h 30m)",
                systemImage: "clock"
            )
        }
    }
}