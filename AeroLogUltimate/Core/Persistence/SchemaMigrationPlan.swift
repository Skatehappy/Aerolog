import Foundation
import SwiftData

/// Versioned migration plan for schema evolution.
///
/// Phase 0 ships v1.0.0. Future phases append `MigrationStage` entries here.
///
/// L1 — HARD GATE: the production container is still built from a plain `Schema`
/// (SwiftData lightweight migration), NOT a wired `SchemaMigrationPlan`. That is
/// only safe while EVERY model change is additive AND every new stored property
/// is optional or has an inline default. A single non-additive change (rename,
/// retype, remove, or a new non-defaulted required property) will fail the store
/// open on update and make existing user data unreachable. Before shipping any
/// such change, adopt `VersionedSchema` + a real `SchemaMigrationPlan` first.
enum AeroLogMigrationPlan {
    static let currentVersion = Schema.Version(1, 4, 0)

    // v1.1.0 adds WeightBalanceLog, FlightExpense, MaintenanceItem and optional fuel fields.
    // v1.2.0 adds Flight.editHistoryJSON for finalized-entry audit trail.
    // v1.3.0 adds Aircraft.isLSA and Aircraft.isMotorglider (Bool, default false —
    //        additive, handled by SwiftData lightweight migration; no custom stage).
    // v1.4.0 adds PilotProfile.medicalMode, basicMedExamDate, flightReviewSource,
    //        ipcSource (all optional) and CurrencyRequirement.manualCurrentDate
    //        (optional self-attestation). All additive/optional → lightweight migration.
}