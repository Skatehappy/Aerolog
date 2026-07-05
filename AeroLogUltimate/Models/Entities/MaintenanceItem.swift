import Foundation
import SwiftData

/// Scheduled or completed maintenance for an aircraft.
@Model
final class MaintenanceItem {
    var title: String
    var maintenanceType: MaintenanceType
    var dueDate: Date?
    var dueHobbs: Double?
    var completedDate: Date?
    var reminderLeadDays: Int
    var notes: String?
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    @Relationship(deleteRule: .nullify)
    var aircraft: Aircraft?

    var isOverdue: Bool {
        guard !isCompleted else { return false }
        if let dueDate, dueDate < .now { return true }
        return false
    }

    var daysUntilDue: Int? {
        guard !isCompleted, let dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: dueDate).day
    }

    init(
        title: String = "",
        maintenanceType: MaintenanceType = .other,
        reminderLeadDays: Int = 14
    ) {
        self.title = title
        self.maintenanceType = maintenanceType
        self.reminderLeadDays = reminderLeadDays
        self.isCompleted = false
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    func markCompleted(on date: Date = .now) {
        isCompleted = true
        completedDate = date
        touch()
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }
}