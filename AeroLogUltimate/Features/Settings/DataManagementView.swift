import SwiftUI

/// Hub for logbook import, export, and full backup operations.
struct DataManagementView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    ImportLogbookView()
                } label: {
                    settingsRow(
                        title: "Import Logbook",
                        subtitle: "CSV, JSON, and AeroLog backup files",
                        systemImage: "square.and.arrow.down"
                    )
                }

                NavigationLink {
                    ExportOptionsView()
                } label: {
                    settingsRow(
                        title: "Export Logbook",
                        subtitle: "PDF, CSV, and structured JSON",
                        systemImage: "square.and.arrow.up"
                    )
                }

                NavigationLink {
                    BackupRestoreView()
                } label: {
                    settingsRow(
                        title: "Backup & Restore",
                        subtitle: "Full local archive with attachments",
                        systemImage: "externaldrive"
                    )
                }
            } header: {
                Text("Data Portability")
            } footer: {
                Text("AeroLog Ultimate keeps your logbook data on-device. Use import and export to move between apps or create archival backups.")
            }
        }
        .navigationTitle("Data Management")
    }

    private func settingsRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}