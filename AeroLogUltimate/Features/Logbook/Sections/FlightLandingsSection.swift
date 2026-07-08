import SwiftUI

struct FlightLandingsSection: View {
    @Bindable var flight: Flight

    var body: some View {
        Section {
            StepperField(label: "Day Landings", value: $flight.dayLandings)
            StepperField(label: "Night Landings", value: $flight.nightLandings)
            StepperField(label: "Full Stop (Day)", value: $flight.fullStopDayLandings)
            StepperField(label: "Full Stop (Night)", value: $flight.fullStopNightLandings)
            // F3: clarify what qualifies as a night full-stop for 61.57(b).
            Text("61.57(b) credit requires landings between 1 hour after sunset and 1 hour before sunrise.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            StepperField(label: "Holds", value: $flight.holds, range: 0...20)
        } header: {
            FormSectionHeader(title: "Landings & Holds", systemImage: "airplane.arrival")
        }
    }
}