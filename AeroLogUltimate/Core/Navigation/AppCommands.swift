import SwiftUI

/// Global menu commands and keyboard shortcuts for iPad with external keyboard.
struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Log Flight") {
                AppShortcutNotifications.post(.newFlight)
            }
            .keyboardShortcut(KeyboardShortcutRegistry.newFlight)
        }

        CommandMenu("Navigate") {
            ForEach(AppTab.allCases) { tab in
                if let shortcut = KeyboardShortcutRegistry.selectTab(tab) {
                    Button(tab.title) {
                        AppShortcutNotifications.post(.selectTab(tab))
                    }
                    .keyboardShortcut(shortcut)
                }
            }
        }

        CommandGroup(after: .sidebar) {
            Button("Toggle Sidebar") {
                AppShortcutNotifications.post(.toggleSidebar)
            }
            .keyboardShortcut(KeyboardShortcutRegistry.toggleSidebar)
        }

        CommandGroup(after: .textEditing) {
            Button("Search Flights") {
                AppShortcutNotifications.post(.focusSearch)
            }
            .keyboardShortcut(KeyboardShortcutRegistry.focusSearch)
        }

        CommandGroup(after: .saveItem) {
            Button("Save Flight") {
                AppShortcutNotifications.post(.save)
            }
            .keyboardShortcut(KeyboardShortcutRegistry.save)
        }
    }
}