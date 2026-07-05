import Foundation
import SwiftData

/// Versioned migration plan for schema evolution.
///
/// Phase 0 ships v1.0.0. Future phases append `MigrationStage` entries here.
enum AeroLogMigrationPlan {
    static let currentVersion = Schema.Version(1, 0, 0)

    /// Extend with migration stages when bumping `AeroLogSchema.versionIdentifier`.
    static var migrationPlan: SchemaMigrationPlan {
        SchemaMigrationPlan(
            schemas: [AeroLogSchema.schema],
            stages: []
        )
    }
}