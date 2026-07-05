import Foundation
import SwiftData

/// Embeddable sync metadata stored on every sync-capable entity.
///
/// Kept as a separate `@Model` to avoid SwiftData macro limitations with protocol composition.
@Model
final class SyncMetadata {
    var syncID: UUID
    var revision: Int
    var syncState: SyncState
    var isSoftDeleted: Bool
    var lastModifiedAt: Date
    var remoteUpdatedAt: Date?
    var encryptionKeyID: String?

    init(
        syncID: UUID = UUID(),
        revision: Int = 1,
        syncState: SyncState = .localOnly,
        isSoftDeleted: Bool = false,
        lastModifiedAt: Date = .now,
        remoteUpdatedAt: Date? = nil,
        encryptionKeyID: String? = nil
    ) {
        self.syncID = syncID
        self.revision = revision
        self.syncState = syncState
        self.isSoftDeleted = isSoftDeleted
        self.lastModifiedAt = lastModifiedAt
        self.remoteUpdatedAt = remoteUpdatedAt
        self.encryptionKeyID = encryptionKeyID
    }

    func markModified() {
        revision += 1
        lastModifiedAt = .now
        if syncState == .synced {
            syncState = .pendingUpload
        }
    }

    func softDelete() {
        isSoftDeleted = true
        markModified()
    }
}