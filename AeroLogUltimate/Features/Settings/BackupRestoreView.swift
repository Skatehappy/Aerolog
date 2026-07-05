import SwiftUI
import UniformTypeIdentifiers

/// Create and restore full local backups including attachment files.
struct BackupRestoreView: View {
    @Environment(\.appEnvironment) private var environment

    @State private var includeAttachments = true
    @State private var restoreStrategy: BackupRestoreStrategy = .merge
    @State private var isWorking = false
    @State private var lastBackup: BackupCreationResult?
    @State private var lastRestore: BackupRestoreResult?
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showRestorePicker = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Create Backup") {
                Toggle("Include Attachments", isOn: $includeAttachments)
                Button {
                    createBackup()
                } label: {
                    Label(isWorking ? "Creating..." : "Create Local Backup", systemImage: "externaldrive.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isWorking)
            }

            if let backup = lastBackup {
                Section("Last Backup") {
                    LabeledContent("Flights", value: "\(backup.package.manifest.entityCounts.flights)")
                    LabeledContent("Attachments", value: "\(backup.attachmentCount)")
                    LabeledContent("Size") {
                        Text(ByteCountFormatter.string(fromByteCount: backup.totalBytes, countStyle: .file))
                    }
                    Button("Share Backup") {
                        shareURL = backup.archiveURL
                        showShare = true
                    }
                }
            }

            Section("Restore Backup") {
                Picker("Restore strategy", selection: $restoreStrategy) {
                    Text("Merge").tag(BackupRestoreStrategy.merge)
                    Text("Replace all data").tag(BackupRestoreStrategy.replaceAll)
                }
                Button {
                    showRestorePicker = true
                } label: {
                    Label("Choose Backup to Restore", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isWorking)
            }

            if let restore = lastRestore {
                Section("Last Restore") {
                    LabeledContent("Flights restored", value: "\(restore.restoredFlights)")
                    LabeledContent("Aircraft restored", value: "\(restore.restoredAircraft)")
                    LabeledContent("Attachments", value: "\(restore.restoredAttachments)")
                }
            }
        }
        .navigationTitle("Backup & Restore")
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .fileImporter(
            isPresented: $showRestorePicker,
            allowedContentTypes: [.json, .folder],
            allowsMultipleSelection: false
        ) { result in
            handleRestore(result)
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func createBackup() {
        guard let service = environment?.dataManagementService else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            lastBackup = try service.createBackup(includeAttachments: includeAttachments)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleRestore(_ result: Result<[URL], Error>) {
        guard let service = environment?.dataManagementService else { return }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            isWorking = true
            defer { isWorking = false }
            do {
                lastRestore = try service.restoreBackup(from: url, strategy: restoreStrategy)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}