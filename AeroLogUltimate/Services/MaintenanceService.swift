import Foundation
import SwiftData

@MainActor
struct MaintenanceService {
    let dataStore: DataStore

    func items(for aircraft: Aircraft, includeCompleted: Bool = false) -> [MaintenanceItem] {
        let items = (aircraft.maintenanceItems ?? []).filter { item in
            !(item.syncMetadata?.isSoftDeleted ?? false)
                && (includeCompleted || !item.isCompleted)
        }
        return items.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?): return l < r
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs.title < rhs.title
            }
        }
    }

    func upcomingItems(leadDays: Int = 30) throws -> [MaintenanceItem] {
        let aircraft = try dataStore.fetch(FetchDescriptor<Aircraft>())
        let horizon = Calendar.current.date(byAdding: .day, value: leadDays, to: .now) ?? .now
        return aircraft.flatMap { items(for: $0) }
            .filter { item in
                guard let due = item.dueDate else { return false }
                return due <= horizon
            }
    }

    func overdueItems() throws -> [MaintenanceItem] {
        let aircraft = try dataStore.fetch(FetchDescriptor<Aircraft>())
        return aircraft.flatMap { items(for: $0) }.filter(\.isOverdue)
    }

    @discardableResult
    func addItem(
        to aircraft: Aircraft,
        title: String,
        type: MaintenanceType,
        dueDate: Date? = nil,
        dueHobbs: Double? = nil,
        reminderLeadDays: Int = 14,
        notes: String? = nil
    ) throws -> MaintenanceItem {
        let item = MaintenanceItem(title: title, maintenanceType: type, reminderLeadDays: reminderLeadDays)
        item.dueDate = dueDate
        item.dueHobbs = dueHobbs
        item.notes = notes
        item.aircraft = aircraft
        dataStore.insert(item)
        aircraft.touch()
        try dataStore.save()
        return item
    }

    func markCompleted(_ item: MaintenanceItem, on date: Date = .now) throws {
        item.markCompleted(on: date)
        try dataStore.save()
    }

    func delete(_ item: MaintenanceItem) throws {
        if let metadata = item.syncMetadata {
            metadata.softDelete()
        } else {
            dataStore.delete(item)
        }
        try dataStore.save()
    }
}