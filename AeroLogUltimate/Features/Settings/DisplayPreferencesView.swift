import SwiftUI

/// Display and logging defaults for the app.
struct DisplayPreferencesView: View {
    @Environment(\.appEnvironment) private var environment

    @State private var showDecimalHours = true
    @State private var confirmBeforeDelete = true
    @State private var defaultRole: FlightRole = .pic
    @State private var colorSchemeSelection = "system"
    @State private var useAviationPalette = true
    @State private var preferPencilOnly = false
    @State private var compactSidebar = false

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
                    Text("Aviation Dark").tag("dark")
                }
                .onChange(of: colorSchemeSelection) { _, value in
                    switch value {
                    case "light": environment?.settings.preferredColorScheme = .light
                    case "dark": environment?.settings.preferredColorScheme = .dark
                    default: environment?.settings.preferredColorScheme = nil
                    }
                }

                Toggle("Aviation Dark Palette", isOn: $useAviationPalette)
                .onChange(of: useAviationPalette) { _, value in
                    environment?.settings.useAviationDarkPalette = value
                }

                Text("Uses navy panels and amber accents in dark mode — easier on the eyes during preflight briefings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Apple Pencil") {
                Toggle("Pencil Only Input", isOn: $preferPencilOnly)
                    .onChange(of: preferPencilOnly) { _, value in
                        environment?.settings.preferPencilOnlyInput = value
                    }
                Text("When enabled, PencilKit canvases ignore finger touches — ideal for signing endorsements in turbulence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("iPad Layout") {
                Toggle("Compact Sidebar", isOn: $compactSidebar)
                    .onChange(of: compactSidebar) { _, value in
                        environment?.settings.compactSidebar = value
                    }
            }

            Section("Keyboard Shortcuts") {
                LabeledContent("Log flight", value: "⌘N")
                LabeledContent("Search", value: "⌘F")
                LabeledContent("Save", value: "⌘S")
                LabeledContent("Toggle sidebar", value: "⌃⌘S")
                LabeledContent("Switch tabs", value: "⌘⇧1–7")
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
        useAviationPalette = settings.useAviationDarkPalette
        preferPencilOnly = settings.preferPencilOnlyInput
        compactSidebar = settings.compactSidebar
        switch settings.preferredColorScheme {
        case .light: colorSchemeSelection = "light"
        case .dark: colorSchemeSelection = "dark"
        default: colorSchemeSelection = "system"
        }
    }
}