import SwiftUI

struct FlightHobbsSection: View {
    @Bindable var flight: Flight
    let aircraft: Aircraft

    var body: some View {
        Section {
            if aircraft.tracksHobbs {
                HStack {
                    Text("Hobbs Start")
                    Spacer()
                    TextField("0.0", value: $flight.hobbsStart, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
                HStack {
                    Text("Hobbs End")
                    Spacer()
                    TextField("0.0", value: $flight.hobbsEnd, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
                if let hobbs = flight.hobbsTime {
                    HStack {
                        Text("Hobbs Time")
                        Spacer()
                        Text(TimeFormatting.display(hobbs))
                            .foregroundStyle(.secondary)
                    }
                    Button("Apply Hobbs to Total") {
                        flight.totalTime = hobbs
                    }
                    .font(.caption)
                }
            }

            if aircraft.tracksTach {
                HStack {
                    Text("Tach Start")
                    Spacer()
                    TextField("0.0", value: $flight.tachStart, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
                HStack {
                    Text("Tach End")
                    Spacer()
                    TextField("0.0", value: $flight.tachEnd, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
                if let tach = flight.tachTime {
                    HStack {
                        Text("Tach Time")
                        Spacer()
                        Text(TimeFormatting.display(tach))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            FormSectionHeader(title: "Hobbs / Tach", systemImage: "gauge")
        }
    }
}