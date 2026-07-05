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

        CommandGroup(replacing: .textEditing) {
            Button("Search") {
                AppShortcutNotifications.post(.focusSearch)
            }
            .keyboardShortcut(KeyboardShortcutRegistry.focusSearch)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                AppShortcutNotifications.post(.save)
            }
            .keyboardShortcut(KeyboardShortcutRegistry.save)
        }
    }
}