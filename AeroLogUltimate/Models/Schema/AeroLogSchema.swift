import Foundation
import SwiftData

/// Central schema registry for AeroLog Ultimate.
///
/// All `@Model` types must be registered here for SwiftData container creation and migrations.
enum AeroLogSchema {
    /// Current schema version. Increment when making breaking model changes.
    static let versionIdentifier = "1.2.0"

    /// All persisted model types in dependency-safe order.
    static let modelTypes: [any PersistentModel.Type] = [
        SyncMetadata.self,
        PilotProfile.self,
        Aircraft.self,
        Flight.self,
        FlightLeg.self,
        InstrumentApproach.self,
        WeightBalanceLog.self,
        FlightExpense.self,
        MaintenanceItem.self,
        Endorsement.self,
        EndorsementTemplate.self,
        CurrencyRequirement.self,
        CurrencySnapshot.self,
        TrainingRelationship.self,
        Syllabus.self,
        SyllabusLesson.self,
        ReportDefinition.self,
        Attachment.self
    ]

    /// SwiftData schema instance for container configuration.
    static var schema: Schema {
        Schema(modelTypes)
    }

    /// Semantic version for migration planning (`AeroLogMigrationPlan`).
    static var schemaVersion: Schema.Version {
        Schema.Version(1, 2, 0)
    }
}