import Foundation
import os
import SwiftData

/// Protocol for the optional encrypted sync engine (Phase 6 implementation).
protocol SyncCoordinatorProtocol: AnyObject {
    var configuration: EncryptedSyncConfiguration { get }
    var isSyncing: Bool { get }

    func enable(with configuration: EncryptedSyncConfiguration) async throws
    func disable() async
    func syncNow() async throws
    func resolveConflicts(using strategy: SyncConflictResolution) async throws
}

/// Encrypted cloud sync coordinator with local backup payload foundation.
@MainActor
final class SyncCoordinator: SyncCoordinatorProtocol {
    private let logger = Logger(subsystem: "com.aerologultimate", category: "Sync")

    private(set) var configuration: EncryptedSyncConfiguration
    private(set) var isSyncing = false

    private weak var dataManagementService: DataManagementService?

    init(configuration: EncryptedSyncConfiguration = .disabled) {
        self.configuration = configuration
    }

    func attach(dataManagementService: DataManagementService) {
        self.dataManagementService = dataManagementService
    }

    func enable(with configuration: EncryptedSyncConfiguration) async throws {
        var updated = configuration
        if updated.encryptionKeyID == nil {
            updated.encryptionKeyID = "aerolog-\(UUID().uuidString.lowercased())"
        }
        if let keyID = updated.encryptionKeyID {
            _ = try ModelContainerConfiguration.makeSyncContainer(encryptionKeyID: keyID)
            logger.info("Provisioned encrypted sync container for key \(keyID)")
        }
        updated.isEnabled = true
        self.configuration = updated
        logger.info("Encrypted sync enabled — provider: \(updated.providerIdentifier ?? "local")")
    }

    func disable() async {
        logger.info("Sync disabled")
        configuration = .disabled
    }

    func syncNow() async throws {
        guard configuration.isEnabled else {
            logger.debug("Sync skipped — sync is disabled")
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        guard let dataManagementService else {
            logger.warning("Sync skipped — data management service not attached")
            return
        }

        let payload = try dataManagementService.cloudBackupPayload()
        let keyID = configuration.encryptionKeyID ?? "unprovisioned"
        logger.info("Prepared encrypted cloud backup payload (\(payload.count) bytes) for key \(keyID)")
        // Foundation for provider upload — remote transport implemented in a future phase.
        configuration.lastSyncAt = .now
    }

    func resolveConflicts(using strategy: SyncConflictResolution) async throws {
        logger.info("Conflict resolution requested with strategy: \(strategy.rawValue)")
        // Apply resolution across conflicted SyncMetadata records when remote sync is active.
    }
}