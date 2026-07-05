import SwiftUI

/// Display and logging defaults for the app.
struct DisplayPreferencesView: View {
    @Environment(\.appEnvironment) private var environment

    @State private var showDecimalHours = true
    @State private var confirmBeforeDelete = true
    @State private var defaultRole: FlightRole = .pic
    @State private var colorSchemeSelection = "system"

    var body: some View {
        Form {
            Section("Time Display") {
                Toggle("Show Decimal Hours", isOn: $showDecimalHours)
                    .onChange(of: showDecimalHours) { _, value in
                        environment?.settings.showDecimalHours = value
                    }
            }

            Section("Logging Defaults") {
                Picker("Default Flight Role", selection: $defaultRole) {
                    ForEach(FlightRole.allCases, id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .onChange(of: defaultRole) { _, value in
                    environment?.settings.defaultFlightRole = value
                }
            }

            Section("Safety") {
                Toggle("Confirm Before Delete", isOn: $confirmBeforeDelete)
                    .onChange(of: confirmBeforeDelete) { _, value in
                        environment?.settings.confirmBeforeDelete = value
                    }
            }

            Section("Appearance") {
                Picker("Color Scheme", selection: $colorSchemeSelection) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .onChange(of: colorSchemeSelection) { _, value in
                    switch value {
                    case "light": environment?.settings.preferredColorScheme = .light
                    case "dark": environment?.settings.preferredColorScheme = .dark
                    default: environment?.settings.preferredColorScheme = nil
                    }
                }
            }
        }
        .navigationTitle("Display")
        .onAppear { loadPreferences() }
    }

    private func loadPreferences() {
        guard let settings = environment?.settings else { return }
        showDecimalHours = settings.showDecimalHours
        confirmBeforeDelete = settings.confirmBeforeDelete
        defaultRole = settings.defaultFlightRole
        switch settings.preferredColorScheme {
        case .light: colorSchemeSelection = "light"
        case .dark: colorSchemeSelection = "dark"
        default: colorSchemeSelection = "system"
        }
    }
}