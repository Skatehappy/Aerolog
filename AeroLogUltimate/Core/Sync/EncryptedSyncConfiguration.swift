import Foundation

/// Configuration for optional encrypted cloud sync (implemented in Phase 6).
struct EncryptedSyncConfiguration: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var providerIdentifier: String?
    var encryptionKeyID: String?
    var lastSyncAt: Date?
    var autoSyncOnWiFiOnly: Bool
    var conflictResolution: SyncConflictResolution

    static let disabled = EncryptedSyncConfiguration(
        isEnabled: false,
        providerIdentifier: nil,
        encryptionKeyID: nil,
        lastSyncAt: nil,
        autoSyncOnWiFiOnly: true,
        conflictResolution: .manual
    )
}