import SwiftUI

/// Aircraft detail hub with performance, maintenance, and edit actions.
struct AircraftHubView: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable var aircraft: Aircraft

    @State private var showEditor = false

    var body: some View {
        List {
            Section {
                LabeledContent("Registration", value: aircraft.displayName)
                LabeledContent("Make / Model", value: aircraft.subtitle)
            }

            Section("Operations") {
                NavigationLink {
                    AircraftPerformanceView(aircraft: aircraft)
                } label: {
                    Label("Performance Notes", systemImage: "gauge.with.dots.needle.67percent")
                }

                if !aircraft.isSimulator {
                    NavigationLink {
                        MaintenanceListView(aircraft: aircraft)
                    } label: {
                        Label("Maintenance", systemImage: "wrench.and.screwdriver")
                    }
                }
            }

            Section {
                Button("Edit Aircraft") { showEditor = true }
            }
        }
        .navigationTitle(aircraft.displayName)
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                AircraftEditorView(aircraft: aircraft, isNew: false)
            }
        }
    }
}