import Foundation
import UserNotifications

/// Schedules local notifications for upcoming aircraft maintenance.
enum MaintenanceReminderScheduler {
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        return await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    @MainActor
    static func rescheduleAll(using service: MaintenanceService) async {
        guard await requestAuthorizationIfNeeded() else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers())

        guard let items = try? service.upcomingItems(leadDays: 90) else { return }

        for item in items {
            guard let dueDate = item.dueDate,
                  let notifyDate = Calendar.current.date(byAdding: .day, value: -item.reminderLeadDays, to: dueDate),
                  notifyDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Maintenance Due"
            content.body = "\(item.title) for \(item.aircraft?.displayName ?? "aircraft") is due soon."
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: notifyDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationID(for: item),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private static func notificationID(for item: MaintenanceItem) -> String {
        let syncID = item.syncMetadata?.syncID.uuidString ?? UUID().uuidString
        return "maintenance.\(syncID)"
    }

    private static func pendingIdentifiers() -> [String] {
        ["maintenance."]
    }
}