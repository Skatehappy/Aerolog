import SwiftUI

/// Compact row for the flight logbook list.
struct FlightRowView: View {
    let flight: Flight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(flight.flightDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(.headline)
                    StatusBadge(status: flight.status)
                    if flight.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Text(flight.routeSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label(flight.aircraftDisplay, systemImage: "airplane")
                    Label(TimeFormatting.display(flight.totalTime), systemImage: "clock")
                    Text(flight.role.displayName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if flight.dayLandings + flight.nightLandings > 0 {
                    Text("\(flight.dayLandings)d / \(flight.nightLandings)n ldg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if flight.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(.vertical, 4)
    }
}