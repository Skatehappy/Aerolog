import SwiftUI

/// Root settings tab with navigation to data management, sync, and preferences.
struct SettingsDashboardView: View {
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        List {
            Section("Pilot") {
                NavigationLink {
                    PilotProfileSettingsView()
                } label: {
                    Label("Pilot Profile", systemImage: "person.crop.circle")
                }
            }

            Section("Data") {
                NavigationLink {
                    DataManagementView()
                } label: {
                    Label("Import, Export & Backup", systemImage: "arrow.up.arrow.down.circle")
                }
            }

            Section("Sync") {
                NavigationLink {
                    SyncSettingsView()
                } label: {
                    Label("Encrypted Cloud Sync", systemImage: "icloud.and.arrow.up")
                }
            }

            Section("Display") {
                NavigationLink {
                    DisplayPreferencesView()
                } label: {
                    Label("Display Preferences", systemImage: "textformat.size")
                }
            }

            Section("About") {
                LabeledContent("App", value: SettingsStore.appName)
                LabeledContent("Schema", value: AeroLogSchema.versionIdentifier)
                if let lastSync = environment?.settings.syncConfiguration.lastSyncAt {
                    LabeledContent("Last Sync") {
                        Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}