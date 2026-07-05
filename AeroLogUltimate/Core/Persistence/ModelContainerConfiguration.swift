import Foundation
import SwiftData

/// Factory for SwiftData `ModelContainer` with offline-first local storage.
enum ModelContainerConfiguration {
    /// Application Support directory for the primary SQLite store.
    static var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("AeroLogUltimate", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("AeroLogUltimate.store")
    }

    /// In-memory container for previews and unit tests.
    static var inMemory: ModelContainer {
        get throws {
            let configuration = ModelConfiguration(
                schema: AeroLogSchema.schema,
                isStoredInMemoryOnly: true
            )
            return try ModelContainer(for: AeroLogSchema.schema, configurations: [configuration])
        }
    }

    /// Production local container (default).
    static func makeLocalContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: AeroLogSchema.schema,
            url: storeURL,
            allowsSave: true
        )
        return try ModelContainer(for: AeroLogSchema.schema, configurations: [configuration])
    }

    /// Future encrypted sync store (separate container path, disabled in Phase 0).
    static func makeSyncContainer(encryptionKeyID: String) throws -> ModelContainer {
        let syncDirectory = storeURL.deletingLastPathComponent().appendingPathComponent("Sync", isDirectory: true)
        try FileManager.default.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        let syncStoreURL = syncDirectory.appendingPathComponent("\(encryptionKeyID).store")

        let configuration = ModelConfiguration(
            schema: AeroLogSchema.schema,
            url: syncStoreURL,
            allowsSave: true
        )
        return try ModelContainer(for: AeroLogSchema.schema, configurations: [configuration])
    }
}