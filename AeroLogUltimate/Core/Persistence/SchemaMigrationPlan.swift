import Foundation
import SwiftData

/// Versioned migration plan for schema evolution.
///
/// Phase 0 ships v1.0.0. Future phases append `MigrationStage` entries here.
enum AeroLogMigrationPlan {
    static let currentVersion = Schema.Version(1, 0, 0)

    // When bumping `AeroLogSchema.versionIdentifier`, add a VersionedSchema type
    // and conform this enum to `SchemaMigrationPlan` with migration stages.
}