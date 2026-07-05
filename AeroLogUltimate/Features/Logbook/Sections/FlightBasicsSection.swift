import SwiftUI

struct FlightBasicsSection: View {
    @Bindable var flight: Flight
    @Binding var showAircraftPicker: Bool

    var body: some View {
        Section {
            DatePicker("Date", selection: $flight.flightDate, displayedComponents: .date)

            Picker("Role", selection: $flight.role) {
                ForEach(FlightRole.allCases, id: \.self) { role in
                    Text(role.displayName).tag(role)
                }
            }

            Button {
                showAircraftPicker = true
            } label: {
                HStack {
                    Text("Aircraft")
                        .foregroundStyle(.primary)
                    Spacer()
                    if let aircraft = flight.aircraft {
                        VStack(alignment: .trailing) {
                            Text(aircraft.displayName)
                            if aircraft.isSimulator {
                                Text(aircraft.simulatorLevel.shortName)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    } else {
                        Text("Select")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Toggle("Pin Flight", isOn: $flight.isPinned)
            Toggle("Favorite", isOn: $flight.isFavorite)
        } header: {
            FormSectionHeader(title: "Flight Basics", systemImage: "airplane.departure")
        }
    }
}