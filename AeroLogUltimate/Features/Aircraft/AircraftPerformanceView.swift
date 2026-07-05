import SwiftUI

/// Read-only aircraft performance profile for briefing and flight planning.
struct AircraftPerformanceView: View {
    let aircraft: Aircraft

    var body: some View {
        List {
            if hasStructuredData || aircraft.performanceNotes != nil {
                Section("Performance Profile") {
                    if let speed = aircraft.cruiseSpeedKIAS {
                        LabeledContent("Cruise Speed", value: "\(speed) KIAS")
                    }
                    if let glide = aircraft.bestGlideSpeedKIAS {
                        LabeledContent("Best Glide", value: "\(glide) KIAS")
                    }
                    if let capacity = aircraft.fuelCapacity {
                        LabeledContent("Fuel Capacity", value: String(format: "%.1f gal", capacity))
                    }
                    if let burn = aircraft.defaultFuelBurnGPH {
                        LabeledContent("Fuel Burn", value: String(format: "%.1f GPH", burn))
                    }
                    if let notes = aircraft.performanceNotes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notes)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Performance Data",
                    systemImage: "gauge.with.dots.needle.67percent",
                    description: Text("Add cruise speed, fuel burn, and notes in the aircraft editor.")
                )
            }
        }
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasStructuredData: Bool {
        aircraft.cruiseSpeedKIAS != nil
            || aircraft.bestGlideSpeedKIAS != nil
            || aircraft.fuelCapacity != nil
            || aircraft.defaultFuelBurnGPH != nil
    }
}