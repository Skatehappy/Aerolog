import SwiftUI

/// Global menu commands and keyboard shortcuts for iPad with external keyboard.
struct AppCommands: Commands {
    let shortcutCenter: AppShortcutCenter

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Log Flight") {
                shortcutCenter.trigger(.newFlight)
            }
            .keyboardShortcut(KeyboardShortcutRegistry.newFlight)
        }

        CommandMenu("Navigate") {
            ForEach(AppTab.allCases) { tab in
                if let shortcut = KeyboardShortcutRegistry.selectTab(tab) {
                    Button(tab.title) {
                        shortcutCenter.trigger(.selectTab(tab))
                    }
                    .keyboardShortcut(shortcut)
                }
            }
        }

        CommandGroup(after: .sidebar) {
            Button("Toggle Sidebar") {
                shortcutCenter.trigger(.toggleSidebar)
            }
            .keyboardShortcut(KeyboardShortcutRegistry.toggleSidebar)
        }

        CommandGroup(replacing: .textEditing) {
            Button("Search") {
                shortcutCenter.trigger(.focusSearch)
            }
            .keyboardShortcut(KeyboardShortcutRegistry.focusSearch)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                shortcutCenter.trigger(.save)
            }
            .keyboardShortcut(KeyboardShortcutRegistry.save)
        }
    }
}