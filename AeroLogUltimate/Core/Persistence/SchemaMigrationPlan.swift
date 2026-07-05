import Foundation
import SwiftData

/// Versioned migration plan for schema evolution.
///
/// Phase 0 ships v1.0.0. Future phases append `MigrationStage` entries here.
enum AeroLogMigrationPlan {
    static let currentVersion = Schema.Version(1, 2, 0)

    // v1.1.0 adds WeightBalanceLog, FlightExpense, MaintenanceItem and optional fuel fields.
    // v1.2.0 adds Flight.editHistoryJSON for finalized-entry audit trail.
}