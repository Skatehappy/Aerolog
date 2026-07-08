import Foundation

extension Notification.Name {
    static let appShortcutNewFlight = Notification.Name("com.aerologultimate.shortcut.newFlight")
    static let appShortcutFocusSearch = Notification.Name("com.aerologultimate.shortcut.focusSearch")
    static let appShortcutToggleSidebar = Notification.Name("com.aerologultimate.shortcut.toggleSidebar")
    static let appShortcutSave = Notification.Name("com.aerologultimate.shortcut.save")
    static let appShortcutSelectTab = Notification.Name("com.aerologultimate.shortcut.selectTab")
    /// Posted when a lesson/student change is committed so the training dashboard
    /// (a separate column on iPad) refreshes its totals and recent lessons.
    static let trainingDataChanged = Notification.Name("com.aerologultimate.trainingDataChanged")
}

enum AppShortcutNotifications {
    static func post(_ action: AppShortcutAction) {
        let center = NotificationCenter.default
        switch action {
        case .newFlight:
            center.post(name: .appShortcutNewFlight, object: nil)
        case .focusSearch:
            center.post(name: .appShortcutFocusSearch, object: nil)
        case .toggleSidebar:
            center.post(name: .appShortcutToggleSidebar, object: nil)
        case .save:
            center.post(name: .appShortcutSave, object: nil)
        case .selectTab(let tab):
            center.post(name: .appShortcutSelectTab, object: tab)
        }
    }
}