import SwiftUI

/// Configure optional encrypted cloud sync foundation.
struct SyncSettingsView: View {
    @Environment(\.appEnvironment) private var environment

    @State private var isEnabled = false
    @State private var wifiOnly = true
    @State private var conflictResolution: SyncConflictResolution = .manual
    @State private var isSyncing = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("Enable Encrypted Sync", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, enabled in
                        Task { await updateSyncEnabled(enabled) }
                    }
            } footer: {
                Text("Encrypted sync keeps a portable backup payload ready for cloud providers. Remote upload is not yet active — this prepares your encryption keys and sync container.")
            }

            if isEnabled {
                Section("Sync Options") {
                    Toggle("Wi-Fi Only", isOn: $wifiOnly)
                        .onChange(of: wifiOnly) { _, _ in saveConfiguration() }

                    Picker("Conflict Resolution", selection: $conflictResolution) {
                        ForEach(SyncConflictResolution.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .onChange(of: conflictResolution) { _, _ in saveConfiguration() }
                }

                Section {
                    Button {
                        syncNow()
                    } label: {
                        Label(isSyncing ? "Syncing..." : "Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isSyncing)
                }

                if let lastSync = environment?.settings.syncConfiguration.lastSyncAt {
                    Section("Status") {
                        LabeledContent("Last sync") {
                            Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let keyID = environment?.settings.syncConfiguration.encryptionKeyID {
                            LabeledContent("Encryption key") {
                                Text(String(keyID.prefix(12)) + "…")
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Cloud Sync")
        .onAppear { loadConfiguration() }
        .alert("Sync Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadConfiguration() {
        guard let config = environment?.settings.syncConfiguration else { return }
        isEnabled = config.isEnabled
        wifiOnly = config.autoSyncOnWiFiOnly
        conflictResolution = config.conflictResolution
    }

    private func saveConfiguration() {
        guard var config = environment?.settings.syncConfiguration else { return }
        config.autoSyncOnWiFiOnly = wifiOnly
        config.conflictResolution = conflictResolution
        environment?.settings.syncConfiguration = config
        environment?.syncCoordinator.applyConfiguration(config)
    }

    private func updateSyncEnabled(_ enabled: Bool) async {
        guard let environment else { return }
        do {
            if enabled {
                var config = environment.settings.syncConfiguration
                config.isEnabled = true
                config.autoSyncOnWiFiOnly = wifiOnly
                config.conflictResolution = conflictResolution
                try await environment.syncCoordinator.enable(with: config)
                environment.settings.syncConfiguration = environment.syncCoordinator.configuration
                statusMessage = "Encrypted sync enabled. Backup payload is ready for cloud upload."
            } else {
                await environment.syncCoordinator.disable()
                environment.settings.syncConfiguration = .disabled
                statusMessage = "Sync disabled. Your logbook remains fully available offline."
            }
        } catch {
            isEnabled = false
            errorMessage = error.localizedDescription
        }
    }

    private func syncNow() {
        guard let coordinator = environment?.syncCoordinator else { return }
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                try await coordinator.syncNow()
                environment?.settings.syncConfiguration = coordinator.configuration
                statusMessage = "Backup payload prepared successfully."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension SyncConflictResolution {
    var displayName: String {
        switch self {
        case .keepLocal: "Keep Local"
        case .keepRemote: "Keep Remote"
        case .merge: "Merge"
        case .manual: "Ask Me"
        }
    }
}