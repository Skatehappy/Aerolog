import Foundation

/// Metadata contract for entities that may participate in optional encrypted sync.
///
/// Phase 0 stores sync fields locally; the sync engine is implemented in a later phase.
protocol SyncableEntity: AnyObject {
    var syncID: UUID { get set }
    var revision: Int { get set }
    var syncState: SyncState { get set }
    var isSoftDeleted: Bool { get set }
    var lastModifiedAt: Date { get set }
}

/// Standard audit timestamps shared across persisted models.
protocol TimestampedEntity: AnyObject {
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
}

// MARK: - Default Implementations

extension SyncableEntity {
    /// Marks the record as locally modified and awaiting optional sync upload.
    func markModified() {
        revision += 1
        lastModifiedAt = .now
        if syncState == .synced {
            syncState = .pendingUpload
        }
    }

    /// Soft-deletes the record while preserving it for sync propagation.
    func softDelete() {
        isSoftDeleted = true
        markModified()
    }
}